//
//  MemoriesView.swift
//  MeMo
//
//  Updated for screen BGM switching.
//

import SwiftUI
import SwiftData
import UIKit
import Combine
import CoreLocation

@MainActor
final class PlaceNameResolver: ObservableObject {
    @Published private(set) var placeNameByKey: [String: String] = [:]

    private let geocoder = CLGeocoder()
    private var inFlight: Set<String> = []
    private var lastRequestAt: [String: Date] = [:]

    func placeName(for key: String) -> String? {
        placeNameByKey[key]
    }

    func resolveIfNeeded(key: String, latitude: Double?, longitude: Double?) {
        guard let latitude, let longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }
        guard placeNameByKey[key] == nil else { return }
        guard !inFlight.contains(key) else { return }

        if let lastRequestAt = lastRequestAt[key], Date().timeIntervalSince(lastRequestAt) < 10 {
            return
        }

        self.lastRequestAt[key] = Date()
        inFlight.insert(key)

        let location = CLLocation(latitude: latitude, longitude: longitude)
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ja_JP")) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.inFlight.remove(key)
                guard error == nil, let placemark = placemarks?.first else { return }

                let resolved = Self.composePlaceName(from: placemark)
                guard let resolved else { return }
                self.placeNameByKey[key] = resolved
            }
        }
    }

    private static func composePlaceName(from placemark: CLPlacemark) -> String? {
        if let pointOfInterest = placemark.areasOfInterest?.first?.trimmingCharacters(in: .whitespacesAndNewlines), !pointOfInterest.isEmpty {
            return pointOfInterest
        }

        let prefecture = placemark.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = (placemark.locality ?? placemark.subAdministrativeArea ?? placemark.subLocality)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = [prefecture, city].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        if !parts.isEmpty {
            return parts.joined()
        }

        if let fallback = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines), !fallback.isEmpty {
            return fallback
        }

        return nil
    }
}

struct MemoriesView: View {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case day = "day"
        case month = "month"

        var id: String { rawValue }

        var cellHeight: CGFloat {
            switch self {
            case .day:
                return 0
            case .month:
                return 104
            }
        }

        var gridSpacing: CGFloat {
            switch self {
            case .day:
                return 0
            case .month:
                return 8
            }
        }

        var cellCornerRadius: CGFloat {
            switch self {
            case .day:
                return 0
            case .month:
                return 12
            }
        }
    }

    @EnvironmentObject private var bgmManager: BGMManager
    @Query(sort: \TodayPhotoEntry.date, order: .reverse) private var entries: [TodayPhotoEntry]

    @StateObject private var viewModel = MemoriesViewModel()
    @StateObject private var placeResolver = PlaceNameResolver()

    @State private var mode: DisplayMode = .day
    @State private var focusDate: Date = Date()
    @State private var sheetItem: DayPhotosSheetItem?
    @State private var toastMessage: String?
    @State private var showToast: Bool = false
    @State private var now: Date = Date()

    private let calendar = Calendar.current

    var body: some View {
        let latestEntryMap = makeEntryMapLatestPerDay(entries)
        let monthColumns = Array(repeating: GridItem(.flexible(), spacing: mode.gridSpacing), count: 7)
        let todayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: now) }
        let isShowingEmpty = mode == .day ? todayEntries.isEmpty : entries.isEmpty

        ZStack {
            Color.clear.ignoresSafeArea()

            VStack(spacing: 12) {
                modeHeader

                if mode != .day {
                    weekdayHeader
                }

                if isShowingEmpty {
                    emptyView
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        switch mode {
                        case .day:
                            dayCardList(entries: todayEntries)
                        case .month:
                            monthGrid(entryMap: latestEntryMap, columns: monthColumns)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            if showToast, let toastMessage {
                Text(toastMessage)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 10)
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(999)
                    .allowsHitTesting(false)
            }
        }
        .background {
            ZStack {
                Image("omoide_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.25)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle("思い出")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheetItem) { item in
            DayPhotosView(
                dayKey: item.dayKey,
                initialFileName: item.initialFileName,
                titleText: item.titleText,
                viewModel: viewModel,
                onToast: toast
            )
        }
        .onReceive(viewModel.$toastMessage.compactMap { $0 }) { message in
            toast(message)
            viewModel.consumeToast()
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .day {
                viewModel.clearInMemoryCache(keepSelectedDay: true)
            }
        }
        .task {
            scheduleNextMidnightRefresh()
        }
        .onAppear {
            bgmManager.switchBackground(to: .main)
        }
        .onDisappear {
            bgmManager.restoreDefaultBackground()
        }
        .onChange(of: now) { _, _ in
            if mode == .day {
                viewModel.clearInMemoryCache(keepSelectedDay: true)
            }
        }
    }

    private var modeHeader: some View {
        VStack(spacing: 10) {
            HStack {
                if mode != .day {
                    Button {
                        bgmManager.playSE(.push)
                        shiftRange(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                } else {
                    Image(systemName: "chevron.left").opacity(0)
                }

                Spacer()

                Text(titleText)
                    .font(.headline)

                Spacer()

                if mode != .day {
                    Button {
                        bgmManager.playSE(.push)
                        shiftRange(1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                } else {
                    Image(systemName: "chevron.right").opacity(0)
                }
            }
            .font(.title3)
            .padding(.horizontal, 2)

            Picker("表示", selection: $mode) {
                ForEach(DisplayMode.allCases) { displayMode in
                    Text(displayMode.rawValue).tag(displayMode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in
                bgmManager.playSE(.push)
            }
        }
        .padding(.top, 8)
    }

    private var weekdayHeader: some View {
        let symbols = weekdaySymbolsStartingFromFirstWeekday()
        return HStack(spacing: mode.gridSpacing) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                let weekday = weekdayNumberForColumnIndex(index)
                let color: Color = weekday == 7 ? .blue : (weekday == 1 ? .red : .black)

                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 2)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("まだ思い出がありません")
                .font(.title3)
                .bold()

            Text("ホームのカメラから撮影できます")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 80)
    }

    private func dayCardList(entries: [TodayPhotoEntry]) -> some View {
        LazyVStack(spacing: 22) {
            ForEach(entries) { entry in
                DayMemoryCard(
                    entry: entry,
                    image: viewModel.image(forFileName: entry.fileName),
                    placeName: resolvedPlaceName(for: entry),
                    timeText: viewModel.timeText(for: entry.date)
                ) {
                    bgmManager.playSE(.push)
                    sheetItem = DayPhotosSheetItem(
                        dayKey: entry.dayKey,
                        initialFileName: entry.fileName,
                        titleText: sheetTitleText(placeName: resolvedPlaceName(for: entry))
                    )
                }
                .onAppear {
                    if viewModel.image(forFileName: entry.fileName) == nil {
                        viewModel.loadImageIfNeeded(fileName: entry.fileName)
                    }

                    if entry.placeName == nil {
                        placeResolver.resolveIfNeeded(
                            key: placeKey(for: entry),
                            latitude: entry.latitude,
                            longitude: entry.longitude
                        )
                    }
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    private func monthGrid(entryMap: [String: TodayPhotoEntry], columns: [GridItem]) -> some View {
        let slots = monthSlots(for: focusDate)
        return LazyVGrid(columns: columns, spacing: mode.gridSpacing) {
            ForEach(0..<slots.count, id: \.self) { index in
                if let day = slots[index] {
                    dayCell(for: day, entryMap: entryMap)
                } else {
                    RoundedRectangle(cornerRadius: mode.cellCornerRadius)
                        .fill(Color.white)
                        .frame(height: mode.cellHeight)
                }
            }
        }
        .padding(.top, 4)
    }

    private func dayCell(for date: Date, entryMap: [String: TodayPhotoEntry]) -> some View {
        let key = AppState.makeDayKey(date)
        let entry = entryMap[key]
        let isToday = calendar.isDateInToday(date)
        let cachedThumbnail = viewModel.thumbnailImage(for: key)
        let weekday = calendar.component(.weekday, from: date)
        let weekendColor: Color = weekday == 7 ? .blue : (weekday == 1 ? .red : .black)

        let placeName: String? = {
            guard let entry else { return nil }
            return resolvedPlaceName(for: entry)
        }()

        return VStack(spacing: 2) {
            Text(dayNumber(for: date))
                .font(.caption2)
                .foregroundStyle(weekendColor)

            Group {
                if let cachedThumbnail {
                    Image(uiImage: cachedThumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white)
                } else if let entry {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .overlay {
                            ProgressView().tint(.gray)
                        }
                        .onAppear {
                            if viewModel.thumbnailImage(for: key) == nil {
                                viewModel.loadThumbnailIfNeeded(dayKey: key, fileName: entry.fileName)
                            }

                            if entry.placeName == nil {
                                placeResolver.resolveIfNeeded(
                                    key: placeKey(for: entry),
                                    latitude: entry.latitude,
                                    longitude: entry.longitude
                                )
                            }
                        }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .overlay {
                            Image(systemName: "camera")
                                .font(.caption)
                                .foregroundStyle(.black.opacity(0.6))
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: mode.cellHeight - 22)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: mode.cellCornerRadius)
                .fill(Color.white)
        )
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: mode.cellCornerRadius)
                    .stroke(Color(red: 0.6, green: 0.0, blue: 0.0), lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard entry != nil else { return }
            bgmManager.playSE(.push)
            sheetItem = DayPhotosSheetItem(
                dayKey: key,
                initialFileName: nil,
                titleText: sheetTitleText(placeName: placeName)
            )
        }
    }

    private var titleText: String {
        switch mode {
        case .month:
            return monthTitle(for: focusDate)
        case .day:
            return "\(todayHeaderDateText(now)) の できごと"
        }
    }

    private func shiftRange(_ amount: Int) {
        switch mode {
        case .day:
            break
        case .month:
            focusDate = calendar.date(byAdding: .month, value: amount, to: focusDate) ?? focusDate
        }
    }

    private func monthSlots(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let monthStart = monthInterval.start
        let weekday = calendar.component(.weekday, from: monthStart)
        let firstWeekday = calendar.firstWeekday
        let leading = (weekday - firstWeekday + 7) % 7
        let days = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        var slots: [Date?] = Array(repeating: nil, count: leading)
        slots.append(contentsOf: (0..<days).compactMap { calendar.date(byAdding: .day, value: $0, to: monthStart) })

        let remainder = slots.count % 7
        if remainder != 0 {
            slots.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return slots
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private func dayNumber(for date: Date) -> String {
        String(calendar.component(.day, from: date))
    }

    private func weekdaySymbolsStartingFromFirstWeekday() -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = max(0, calendar.firstWeekday - 1)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private func weekdayNumberForColumnIndex(_ index: Int) -> Int {
        let firstWeekday = calendar.firstWeekday
        return ((firstWeekday - 1 + index) % 7) + 1
    }

    private func makeEntryMapLatestPerDay(_ entries: [TodayPhotoEntry]) -> [String: TodayPhotoEntry] {
        entries.reduce(into: [:]) { partialResult, entry in
            if let current = partialResult[entry.dayKey] {
                if entry.date > current.date {
                    partialResult[entry.dayKey] = entry
                }
            } else {
                partialResult[entry.dayKey] = entry
            }
        }
    }

    private func todayHeaderDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }

    private func placeKey(for entry: TodayPhotoEntry) -> String {
        entry.fileName
    }

    private func resolvedPlaceName(for entry: TodayPhotoEntry) -> String? {
        entry.placeName ?? placeResolver.placeName(for: placeKey(for: entry))
    }

    private func sheetTitleText(placeName: String?) -> String {
        let trimmed = placeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return "\(trimmed) の おもいで"
        }
        return "おもいで"
    }

    private func scheduleNextMidnightRefresh() {
        let startOfToday = calendar.startOfDay(for: Date())
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return }
        let interval = max(0.5, nextMidnight.timeIntervalSinceNow)

        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            now = Date()
            scheduleNextMidnightRefresh()
        }
    }

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.18)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.18)) {
                showToast = false
            }
        }
    }
}

private struct DayMemoryCard: View {
    let entry: TodayPhotoEntry
    let image: UIImage?
    let placeName: String?
    let timeText: String
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MemoryPhotoCardView(image: image)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(TodayPhotoEntry.memoryTitleLine(placeName))
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("撮影 \(timeText)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(.horizontal, 6)
        }
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

private struct DayPhotosSheetItem: Identifiable {
    let dayKey: String
    let initialFileName: String?
    let titleText: String

    var id: String {
        dayKey + "|" + (initialFileName ?? "latest")
    }
}
