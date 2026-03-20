//
//  MemoriesView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData
import UIKit
import Combine
import CoreLocation

// MARK: - ✅ 緯度経度 → 地名変換（CLGeocoder）
@MainActor
final class PlaceNameResolver: ObservableObject {
    @Published private(set) var placeNameByKey: [String: String] = [:]

    private let geocoder = CLGeocoder()
    private var inFlight: Set<String> = []
    private var lastRequestAt: [String: Date] = [:]

    func placeName(for key: String) -> String? {
        placeNameByKey[key]
    }

    /// 同じキーへの連打を避けつつ、必要なときだけ逆ジオコーディング
    func resolveIfNeeded(key: String, latitude: Double?, longitude: Double?) {
        guard let latitude, let longitude else { return }
        let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        guard CLLocationCoordinate2DIsValid(coord) else { return }

        guard placeNameByKey[key] == nil else { return }
        guard !inFlight.contains(key) else { return }

        // 直近で失敗している場合の再試行を少し遅らせる（スクロールで何度も呼ばれがち）
        if let last = lastRequestAt[key], Date().timeIntervalSince(last) < 10 {
            return
        }
        lastRequestAt[key] = Date()
        inFlight.insert(key)

        let location = CLLocation(latitude: latitude, longitude: longitude)

        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ja_JP")) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.inFlight.remove(key)

                if error != nil {
                    // 失敗時は保存しない（表示は「おもいで」にフォールバック）
                    return
                }
                guard let p = placemarks?.first else { return }

                // ✅ 施設名優先 → なければ「都道府県 + 市区町村」などを組み立てる
                let composed = Self.composePlaceName(from: p)

                guard let composed,
                      !composed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { return }

                self.placeNameByKey[key] = composed
            }
        }
    }

    /// 仕様：施設などの名称がある場合はそれを優先。ない場合は「都道府県＋市区町村」など。
    private static func composePlaceName(from p: CLPlacemark) -> String? {
        // 1) 施設名っぽいもの（iOSでは areasOfInterest が取れることがある）
        if let aois = p.areasOfInterest?.first,
           !aois.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return aois
        }

        // 2) p.name が “施設名” として入るケースもある（ただし住所文字列のこともある）
        //    → ここでは「都道府県」「市区町村」系が取れない時の補助として扱う
        let admin = p.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
        let locality = (p.locality ?? p.subAdministrativeArea ?? p.subLocality)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 3) 「都道府県 + 市区町村」(例: 千葉県船橋市)
        let parts: [String] = [admin, locality]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        if !parts.isEmpty {
            return parts.joined()
        }

        // 4) 最後の保険
        if let name = p.name,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
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
            case .month: return 104
            case .day: return 0
            }
        }

        var gridSpacing: CGFloat {
            switch self {
            case .month: return 8
            case .day: return 0
            }
        }

        var cellCornerRadius: CGFloat {
            switch self {
            case .month: return 12
            case .day: return 0
            }
        }
    }

    @EnvironmentObject private var bgmManager: BGMManager

    @Query(sort: \TodayPhotoEntry.date, order: .reverse) private var entries: [TodayPhotoEntry]
    @StateObject private var viewModel = MemoriesViewModel()
    @StateObject private var placeResolver = PlaceNameResolver()

    // ✅ day を一番左＆デフォルト
    @State private var mode: DisplayMode = .day
    @State private var focusDate: Date = Date()

    // ✅ シート（同日写真ビュー）
    @State private var sheetItem: DayPhotosSheetItem?

    // トースト
    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    // ✅ 00:00 を跨いだ更新用（dayの当日フィルタを確実に更新）
    @State private var now: Date = Date()

    private let cal = Calendar.current

    var body: some View {
        let entryMap = makeEntryMapLatestPerDay(entries)
        let columns = Array(repeating: GridItem(.flexible(), spacing: mode.gridSpacing), count: 7)

        // ✅ day は「当日のみ」
        let todayEntries = entries.filter { cal.isDate($0.date, inSameDayAs: now) }
        let isShowingEmpty = (mode == .day) ? todayEntries.isEmpty : entries.isEmpty

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
                            // ✅ 仕様変更：写真アプリ風（横3枚・折り返し）
                            dayGrid(entries: todayEntries)

                        case .month:
                            monthGrid(entryMap: entryMap, columns: columns)
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
        .background(
            ZStack {
                Image("Omoide_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.25)
                    .ignoresSafeArea()
            }
        )
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

        .onReceive(viewModel.$toastMessage.compactMap { $0 }) { msg in
            toast(msg)
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
        .onChange(of: now) { _, _ in
            if mode == .day {
                viewModel.clearInMemoryCache(keepSelectedDay: true)
            }
        }
    }

    // MARK: - Header

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
                ForEach(DisplayMode.allCases) { m in
                    Text(m.rawValue).tag(m)
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
            ForEach(Array(symbols.enumerated()), id: \.offset) { idx, s in
                let weekday = weekdayNumberForColumnIndex(idx) // 1=Sun ... 7=Sat
                let color: Color = {
                    if weekday == 7 { return .blue } // sat
                    if weekday == 1 { return .red }  // sun
                    return .black
                }()

                Text(s)
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
            Text("まだ思い出がありません").font(.title3).bold()
            Text("ホームのカメラから撮影できます")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 80)
    }

    // MARK: - Grids

    private func monthGrid(entryMap: [String: TodayPhotoEntry], columns: [GridItem]) -> some View {
        let slots = monthSlots(for: focusDate)
        return LazyVGrid(columns: columns, spacing: mode.gridSpacing) {
            ForEach(0..<slots.count, id: \.self) { index in
                if let day = slots[index] {
                    dayCell(for: day, entryMap: entryMap)
                } else {
                    // ✅ 空スロットも「白ベタ」で見やすく（opacityなし）
                    RoundedRectangle(cornerRadius: mode.cellCornerRadius)
                        .fill(Color.white)
                        .frame(height: mode.cellHeight)
                }
            }
        }
        .padding(.top, 4)
    }

    // ✅ 仕様変更：day は「3列グリッド」
    private func dayGrid(entries: [TodayPhotoEntry]) -> some View {
        let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(entries) { e in
                dayGridCell(entry: e)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func dayGridCell(entry e: TodayPhotoEntry) -> some View {
        let key = placeKey(for: e)
        let place = e.placeName ?? placeResolver.placeName(for: key)

        // ✅ 正方形サムネ（写真アプリ風）
        ZStack {
            if let img = viewModel.image(forFileName: e.fileName) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        ProgressView().tint(.white.opacity(0.9))
                    }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            bgmManager.playSE(.push)
            // ✅ タップした写真を起点に、同日の写真を左右スワイプで見れる（詳細は DayPhotosView 側で対応）
            sheetItem = DayPhotosSheetItem(
                dayKey: e.dayKey,
                initialFileName: e.fileName,
                titleText: sheetTitleText(placeName: place)
            )
        }
        .onAppear {
            if viewModel.image(forFileName: e.fileName) == nil {
                viewModel.loadImageIfNeeded(fileName: e.fileName)
            }

            if e.placeName == nil {
                placeResolver.resolveIfNeeded(
                    key: key,
                    latitude: e.latitude,
                    longitude: e.longitude
                )
            }
        }
    }

    // MARK: - Cells（month）

    private func dayCell(for date: Date, entryMap: [String: TodayPhotoEntry]) -> some View {
        let key = AppState.makeDayKey(date)
        let entry = entryMap[key]
        let isToday = cal.isDateInToday(date)

        let cached = viewModel.thumbnailImage(for: key)

        // ✅ monthの土日カラー（opacityなし / 平日は黒）
        let weekday = cal.component(.weekday, from: date) // 1=Sun ... 7=Sat
        let weekendColor: Color = {
            if weekday == 7 { return .blue }
            if weekday == 1 { return .red }
            return .black
        }()

        let monthPlace: String? = {
            guard let entry else { return nil }
            let pKey = placeKey(for: entry)
            return entry.placeName ?? placeResolver.placeName(for: pKey)
        }()

        return VStack(spacing: 2) {
            Text(dayNumber(for: date))
                .font(.caption2)
                .foregroundStyle(weekendColor)

            Group {
                if let img = cached {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white) // ✅ 透明感をやめる
                } else if let entry {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white) // ✅ 透明感をやめる
                        .overlay { ProgressView().tint(.gray) }
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
                        .fill(Color.white) // ✅ 透明感をやめる
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

        // ✅ カードの背景を白ベタに（opacityなし）
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
                titleText: sheetTitleText(placeName: monthPlace)
            )
        }
    }

    // MARK: - Title / Navigation

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
        case .month:
            focusDate = cal.date(byAdding: .month, value: amount, to: focusDate) ?? focusDate
        case .day:
            break
        }
    }

    // MARK: - Date Utils

    private func monthSlots(for date: Date) -> [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: date) else { return [] }
        let monthStart = monthInterval.start

        let weekday = cal.component(.weekday, from: monthStart)
        let firstWeekday = cal.firstWeekday
        let leading = (weekday - firstWeekday + 7) % 7

        let days = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        var slots: [Date?] = Array(repeating: nil, count: leading)
        slots.append(contentsOf: (0..<days).compactMap { cal.date(byAdding: .day, value: $0, to: monthStart) })

        let remainder = slots.count % 7
        if remainder != 0 {
            slots.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return slots
    }

    private func monthTitle(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f.string(from: date)
    }

    private func dayNumber(for date: Date) -> String {
        String(cal.component(.day, from: date))
    }

    private func weekdaySymbolsStartingFromFirstWeekday() -> [String] {
        let symbols = cal.shortStandaloneWeekdaySymbols
        let startIndex = max(0, cal.firstWeekday - 1)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private func weekdayNumberForColumnIndex(_ index: Int) -> Int {
        let first = cal.firstWeekday // 1..7
        return ((first - 1 + index) % 7) + 1
    }

    private func makeEntryMapLatestPerDay(_ entries: [TodayPhotoEntry]) -> [String: TodayPhotoEntry] {
        entries.reduce(into: [:]) { dict, e in
            if let existing = dict[e.dayKey] {
                if e.date > existing.date { dict[e.dayKey] = e }
            } else {
                dict[e.dayKey] = e
            }
        }
    }

    private func todayHeaderDateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: date)
    }

    private func placeKey(for entry: TodayPhotoEntry) -> String {
        entry.fileName
    }

    private func sheetTitleText(placeName: String?) -> String {
        let trimmed = placeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return "\(trimmed) の おもいで"
        }
        return "おもいで"
    }

    // MARK: - Midnight Refresh

    private func scheduleNextMidnightRefresh() {
        let startOfToday = cal.startOfDay(for: Date())
        guard let nextMidnight = cal.date(byAdding: .day, value: 1, to: startOfToday) else { return }
        let interval = max(0.5, nextMidnight.timeIntervalSinceNow)

        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            now = Date()
            scheduleNextMidnightRefresh()
        }
    }

    // MARK: - Toast
    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.18)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.18)) { showToast = false }
        }
    }
}

// MARK: - Day Row（※旧day表示で使用していた行UI。将来戻す可能性があるため残置）
private struct DayRow: View {
    let entry: TodayPhotoEntry
    let thumb: UIImage?
    let placeName: String?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumb {
                    Image(uiImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.12))
                } else {
                    Color.white.opacity(0.18)
                        .overlay { ProgressView().tint(.white.opacity(0.9)) }
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(titleLine())
                    .font(.headline)
                    .lineLimit(1)

                Text(timeLine(entry))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background {
            ZStack {
                Image("Omoide_card")
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func titleLine() -> String {
        if let placeName, !placeName.isEmpty {
            return "\(placeName) の おもいで"
        }
        return "おもいで"
    }

    private func timeLine(_ entry: TodayPhotoEntry) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "HH:mm"
        return f.string(from: entry.date)
    }
}

// MARK: - Sheet Item
private struct DayPhotosSheetItem: Identifiable {
    let dayKey: String
    let initialFileName: String?
    let titleText: String
    var id: String { dayKey + "|" + (initialFileName ?? "latest") }
}
