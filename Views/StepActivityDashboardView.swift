//
//  StepActivityDashboardView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/04/09.
//

import SwiftUI
import SwiftData
import UIKit
import Charts

struct MemoStepActivityDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager

    let records: [WorkoutSessionRecord]
    let bottomInset: CGFloat
    let characterAssetName: String
    let plainBackgroundAssetName: String
    @Binding var isPickerPresented: Bool
    let onTapRun: () -> Void

    @State private var selectedRange: MemoStepActivityRange = .week
    @State private var selectedWeekOptionID: String?
    @State private var selectedMonthOptionID: String?
    @State private var selectedYearOptionID: String?
    @State private var pickerSelectionID = ""

    @State private var selectedRecordForDetail: WorkoutSessionRecord?
    @State private var pendingDeleteRecord: WorkoutSessionRecord?

    private var summary: MemoStepActivitySummary {
        MemoStepActivitySummary(records: records, selection: currentSelection)
    }

    private var recentRecords: [WorkoutSessionRecord] {
        Array(records.prefix(12))
    }

    private var currentSelection: MemoStepActivitySelection {
        switch selectedRange {
        case .week:
            return .week(selectedWeekOption)
        case .month:
            return .month(selectedMonthOption)
        case .year:
            return .year(selectedYearOption)
        case .all:
            return .all(title: allPeriodTitle)
        }
    }

    private var weekOptions: [MemoStepActivityPickerOption] {
        MemoStepActivityPickerOption.weekOptions(now: Date())
    }

    private var monthOptions: [MemoStepActivityPickerOption] {
        MemoStepActivityPickerOption.monthOptions(records: records)
    }

    private var yearOptions: [MemoStepActivityPickerOption] {
        MemoStepActivityPickerOption.yearOptions(records: records)
    }

    private var selectedWeekOption: MemoStepActivityPickerOption {
        resolvedOption(in: weekOptions, preferredID: selectedWeekOptionID) ?? weekOptions[0]
    }

    private var selectedMonthOption: MemoStepActivityPickerOption {
        resolvedOption(in: monthOptions, preferredID: selectedMonthOptionID)
            ?? MemoStepActivityPickerOption.currentMonthFallback(now: Date())
    }

    private var selectedYearOption: MemoStepActivityPickerOption {
        resolvedOption(in: yearOptions, preferredID: selectedYearOptionID)
            ?? MemoStepActivityPickerOption.currentYearFallback(now: Date())
    }

    private var activePickerOptions: [MemoStepActivityPickerOption] {
        switch selectedRange {
        case .week:
            return weekOptions
        case .month:
            return monthOptions
        case .year:
            return yearOptions
        case .all:
            return []
        }
    }

    private var canPresentPicker: Bool {
        switch selectedRange {
        case .week:
            return !activePickerOptions.isEmpty
        case .month, .year:
            return activePickerOptions.count > 1
        case .all:
            return false
        }
    }

    private var shouldShowPeriodSelector: Bool {
        selectedRange != .all
    }

    private var selectorLabel: String {
        switch selectedRange {
        case .week:
            return selectedWeekOption.title
        case .month:
            return selectedMonthOption.title
        case .year:
            return selectedYearOption.title
        case .all:
            return allPeriodTitle
        }
    }

    private var allPeriodTitle: String {
        MemoStepActivitySummary.allPeriodTitle(records: records, now: Date())
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.68) : .secondary
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.90)
    }

    private var pickerBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.16) : Color.white
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteRecord != nil },
            set: { newValue in
                if !newValue {
                    pendingDeleteRecord = nil
                }
            }
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    Text("アクティビティ")
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(primaryTextColor)
                        .padding(.top, 86)

                    VStack(alignment: .leading, spacing: 14) {
                        MemoStepActivityRangePicker(selectedRange: $selectedRange)

                        if shouldShowPeriodSelector {
                            MemoStepActivityPeriodSelectorButton(
                                title: selectorLabel,
                                isEnabled: canPresentPicker,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor
                            ) {
                                presentPicker()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(summary.periodTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(primaryTextColor)

                        Text(summary.distanceText)
                            .font(.system(size: 78, weight: .black, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                            .minimumScaleFactor(0.68)
                            .lineLimit(1)

                        Text("KM")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        MemoStepActivityMetricColumn(
                            title: "ラン",
                            value: summary.runCountText,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor
                        )
                        MemoStepActivityMetricColumn(
                            title: "平均ペース",
                            value: summary.paceText,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor
                        )
                        MemoStepActivityMetricColumn(
                            title: "時間",
                            value: summary.durationText,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor
                        )
                    }

                    MemoStepActivityChartCard(
                        summary: summary,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        Text("最近のアクティビティ")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(primaryTextColor)

                        if recentRecords.isEmpty {
                            MemoStepActivityEmptyStateCard(
                                onTapRun: onTapRun,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                                backgroundColor: cardBackgroundColor
                            )
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(recentRecords, id: \.id) { record in
                                    MemoStepRecentActivityCard(
                                        record: record,
                                        primaryTextColor: primaryTextColor,
                                        secondaryTextColor: secondaryTextColor,
                                        backgroundColor: cardBackgroundColor,
                                        onTapRoute: {
                                            bgmManager.playSE(.push)
                                            selectedRecordForDetail = record
                                        },
                                        onTapDelete: {
                                            bgmManager.playSE(.push)
                                            pendingDeleteRecord = record
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, bottomInset)
            }
            .scrollDisabled(isPickerPresented)

            if isPickerPresented {
                Color.black.opacity(colorScheme == .dark ? 0.55 : 0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        dismissPicker()
                    }

                MemoStepActivityWheelPickerSheet(
                    options: activePickerOptions,
                    selectionID: $pickerSelectionID,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    backgroundColor: pickerBackgroundColor,
                    onConfirm: applyPickerSelection
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isPickerPresented)
        .fullScreenCover(
            isPresented: Binding(
                get: { selectedRecordForDetail != nil },
                set: { newValue in
                    if !newValue {
                        selectedRecordForDetail = nil
                    }
                }
            )
        ) {
            if let record = selectedRecordForDetail {
                MemoStepActivityRouteDetailScreen(
                    record: record,
                    characterAssetName: characterAssetName,
                    plainBackgroundAssetName: plainBackgroundAssetName
                )
            }
        }
        .alert(
            "ラン記録を削除しますか？",
            isPresented: deleteAlertBinding,
            presenting: pendingDeleteRecord
        ) { record in
            Button("もどる", role: .cancel) {
                pendingDeleteRecord = nil
            }

            Button("消す", role: .destructive) {
                delete(record)
            }
        } message: { _ in
            Text("このラン記録は元に戻せません。")
        }
    }

    private func resolvedOption(
        in options: [MemoStepActivityPickerOption],
        preferredID: String?
    ) -> MemoStepActivityPickerOption? {
        if let preferredID,
           let matched = options.first(where: { $0.id == preferredID }) {
            return matched
        }

        return options.first
    }

    private func presentPicker() {
        guard canPresentPicker, let currentOption = currentPickerOption else { return }
        pickerSelectionID = currentOption.id
        isPickerPresented = true
    }

    private var currentPickerOption: MemoStepActivityPickerOption? {
        switch selectedRange {
        case .week:
            return selectedWeekOption
        case .month:
            return resolvedOption(in: monthOptions, preferredID: selectedMonthOptionID)
        case .year:
            return resolvedOption(in: yearOptions, preferredID: selectedYearOptionID)
        case .all:
            return nil
        }
    }

    private func applyPickerSelection() {
        switch selectedRange {
        case .week:
            selectedWeekOptionID = pickerSelectionID
        case .month:
            selectedMonthOptionID = pickerSelectionID
        case .year:
            selectedYearOptionID = pickerSelectionID
        case .all:
            break
        }

        dismissPicker()
    }

    private func dismissPicker() {
        isPickerPresented = false
    }

    private func delete(_ record: WorkoutSessionRecord) {
        do {
            modelContext.delete(record)
            try modelContext.save()
            pendingDeleteRecord = nil
        } catch {
            pendingDeleteRecord = nil
        }
    }
}

private struct MemoStepActivityRouteDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bgmManager: BGMManager

    let record: WorkoutSessionRecord
    let characterAssetName: String
    let plainBackgroundAssetName: String

    @State private var isRouteCapturePresented = false
    @State private var shareItem: MemoSharePreviewImage?

    private var primaryTextColor: Color { .white }
    private var secondaryTextColor: Color { Color.white.opacity(0.72) }

    private var distanceText: String {
        String(format: "%.2f", record.distanceKilometers)
    }

    private var paceText: String {
        MemoStepActivityFormatter.paceText(
            elapsedSeconds: record.elapsedSeconds,
            distanceKilometers: record.distanceKilometers
        )
    }

    private var durationText: String {
        MemoStepActivityFormatter.durationText(seconds: record.elapsedSeconds)
    }

    private var titleText: String {
        MemoStepActivityFormatter.relativeDateText(for: record.startedAt)
    }

    private var subtitleText: String {
        "\(MemoStepActivityFormatter.weekdayText(for: record.startedAt)) ラン"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.10, blue: 0.13),
                    Color(red: 0.06, green: 0.07, blue: 0.09),
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Spacer()

                    Button {
                        bgmManager.playSE(.push)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                VStack(alignment: .leading, spacing: 6) {
                    Text(titleText)
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(primaryTextColor)

                    Text(subtitleText)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                Group {
                    if record.routePoints.isEmpty {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay {
                                Image(systemName: "map")
                                    .font(.system(size: 48, weight: .medium))
                                    .foregroundStyle(secondaryTextColor)
                            }
                    } else {
                        WorkoutRouteMapView(points: record.routePoints)
                    }
                }
                .frame(height: 380)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 20)

                HStack(alignment: .top, spacing: 18) {
                    MemoStepRecentMetricColumn(
                        value: distanceText,
                        unit: "km",
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor
                    )
                    MemoStepRecentMetricColumn(
                        value: paceText,
                        unit: "平均ペース",
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor
                    )
                    MemoStepRecentMetricColumn(
                        value: durationText,
                        unit: "時間",
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor
                    )
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)

                HStack(spacing: 14) {
                    Button {
                        bgmManager.playSE(.push)
                        dismiss()
                    } label: {
                        Text("閉じる")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        bgmManager.playSE(.push)
                        isRouteCapturePresented = true
                    } label: {
                        Text("シェア")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(isPresented: $isRouteCapturePresented) {
            MemoRouteCameraCaptureView(
                initialMode: .plain,
                plainBackgroundAssetName: plainBackgroundAssetName,
                characterAssetName: characterAssetName,
                routePoints: record.routePoints
            ) {
                isRouteCapturePresented = false
            } onCapture: { image in
                isRouteCapturePresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    shareItem = MemoSharePreviewImage(image: image)
                }
            }
        }
        .sheet(item: $shareItem) { item in
            MemoImageShareSheet(activityItems: [item.image])
        }
    }
}

private struct MemoSharePreviewImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct MemoImageShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

private struct MemoStepActivityRangePicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedRange: MemoStepActivityRange

    private var selectedTextColor: Color { .black }
    private var unselectedTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.56) : .secondary
    }
    private var backgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.92)
    }
    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MemoStepActivityRange.allCases) { range in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.title)
                        .font(.system(size: 17, weight: selectedRange == range ? .bold : .medium))
                        .foregroundStyle(selectedRange == range ? selectedTextColor : unselectedTextColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            Capsule()
                                .fill(selectedRange == range ? Color(red: 0.96, green: 0.84, blue: 0.12) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(backgroundColor))
        .overlay(
            Capsule().stroke(borderColor, lineWidth: 1)
        )
    }
}

private struct MemoStepActivityPeriodSelectorButton: View {
    let title: String
    let isEnabled: Bool
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isEnabled ? primaryTextColor : secondaryTextColor)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isEnabled ? primaryTextColor : secondaryTextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct MemoStepActivityWheelPickerSheet: View {
    let options: [MemoStepActivityPickerOption]
    @Binding var selectionID: String
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let backgroundColor: Color
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(secondaryTextColor.opacity(0.35))
                .frame(width: 44, height: 5)
                .padding(.top, 8)

            Picker("期間", selection: $selectionID) {
                ForEach(options) { option in
                    Text(option.title)
                        .tag(option.id)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 180)

            Button(action: onConfirm) {
                Text("選択")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(secondaryTextColor.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }
}

private struct MemoStepActivityMetricColumn: View {
    let title: String
    let value: String
    let primaryTextColor: Color
    let secondaryTextColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(secondaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MemoStepActivityChartCard: View {
    let summary: MemoStepActivitySummary
    let primaryTextColor: Color
    let secondaryTextColor: Color

    private var axisGridColor: Color {
        primaryTextColor.opacity(0.10)
    }

    private var referenceLineColor: Color {
        primaryTextColor.opacity(0.28)
    }

    private var referenceLineLabelBackground: Color {
        Color.black.opacity(0.22)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Chart {
                ForEach(summary.chartEntries) { entry in
                    BarMark(
                        x: .value("期間", entry.axisValue),
                        y: .value("距離", entry.distanceKilometers)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .foregroundStyle(Color(red: 0.96, green: 0.84, blue: 0.12))
                }

                if let referenceValue = summary.referenceLineValue {
                    RuleMark(y: .value("平均", referenceValue))
                        .foregroundStyle(referenceLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .trailing, alignment: .center) {
                            Text(summary.referenceLineText)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryTextColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(referenceLineLabelBackground)
                                )
                                .offset(x: -18)
                        }
                }
            }
            .chartYScale(domain: 0 ... summary.chartUpperBound)
            .chartXAxis {
                AxisMarks(values: summary.axisMarkValues) { value in
                    AxisValueLabel(centered: true) {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: summary.yAxisMarkValues) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(axisGridColor)

                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(summary.yAxisText(for: doubleValue))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                }
            }
            .frame(height: 228)

            if summary.hasNoActivityInRange {
                Text("この期間の記録はまだありません")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
            }
        }
        .padding(.top, 6)
    }
}

private struct MemoStepActivityEmptyStateCard: View {
    let onTapRun: () -> Void
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let backgroundColor: Color

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(secondaryTextColor)

            Text("まだアクティビティがありません")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(primaryTextColor)

            Text("最初のランを始めると、ここに記録が表示されます。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .multilineTextAlignment(.center)

            Button(action: onTapRun) {
                Text("ラン画面へ")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.84, blue: 0.12))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(backgroundColor)
        )
    }
}

private struct MemoStepRecentActivityCard: View {
    let record: WorkoutSessionRecord
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let backgroundColor: Color
    let onTapRoute: () -> Void
    let onTapDelete: () -> Void

    private var distanceText: String {
        String(format: "%.2f", record.distanceKilometers)
    }

    private var paceText: String {
        MemoStepActivityFormatter.paceText(
            elapsedSeconds: record.elapsedSeconds,
            distanceKilometers: record.distanceKilometers
        )
    }

    private var durationText: String {
        MemoStepActivityFormatter.durationText(seconds: record.elapsedSeconds)
    }

    private var headlineText: String {
        MemoStepActivityFormatter.relativeDateText(for: record.startedAt)
    }

    private var subtitleText: String {
        "\(MemoStepActivityFormatter.weekdayText(for: record.startedAt)) ラン"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Button(action: onTapRoute) {
                    Group {
                        if record.routePoints.isEmpty {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(primaryTextColor.opacity(0.06))
                                .overlay {
                                    Image(systemName: "map")
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundStyle(secondaryTextColor)
                                }
                        } else {
                            WorkoutRouteMapView(points: record.routePoints)
                        }
                    }
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(headlineText)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(primaryTextColor)

                    Text(subtitleText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }

                Spacer(minLength: 0)

                Button(action: onTapDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(Color.black.opacity(0.26), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 18) {
                MemoStepRecentMetricColumn(
                    value: distanceText,
                    unit: "km",
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor
                )
                MemoStepRecentMetricColumn(
                    value: paceText,
                    unit: "平均ペース",
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor
                )
                MemoStepRecentMetricColumn(
                    value: durationText,
                    unit: "時間",
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor
                )
            }

            if let memo = record.memo, !memo.isEmpty {
                Text(memo)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(backgroundColor)
        )
    }
}

private struct MemoStepRecentMetricColumn: View {
    let value: String
    let unit: String
    let primaryTextColor: Color
    let secondaryTextColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text(unit)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(secondaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum MemoStepActivityRange: String, CaseIterable, Identifiable {
    case week
    case month
    case year
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            return "週"
        case .month:
            return "月"
        case .year:
            return "年"
        case .all:
            return "すべて"
        }
    }
}

private struct MemoStepActivityPickerOption: Identifiable, Hashable {
    let id: String
    let title: String
    let anchorDate: Date
    let interval: DateInterval?

    init(id: String, title: String, anchorDate: Date, interval: DateInterval?) {
        self.id = id
        self.title = title
        self.anchorDate = anchorDate
        self.interval = interval
    }

    static func weekOptions(now: Date) -> [MemoStepActivityPickerOption] {
        let calendar = Calendar.memoActivity
        let currentWeekStart = calendar.startOfWeek(for: now)

        return (0...3).compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: -(offset * 7), to: currentWeekStart),
                  let end = calendar.date(byAdding: .day, value: 7, to: start) else {
                return nil
            }

            let title: String
            switch offset {
            case 0:
                title = "今週"
            case 1:
                title = "先週"
            default:
                title = MemoStepActivityFormatter.weekRangeText(start: start, endExclusive: end)
            }

            return MemoStepActivityPickerOption(
                id: "week-\(offset)",
                title: title,
                anchorDate: start,
                interval: DateInterval(start: start, end: end)
            )
        }
    }

    static func monthOptions(records: [WorkoutSessionRecord]) -> [MemoStepActivityPickerOption] {
        let calendar = Calendar.memoActivity
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"

        let uniqueStarts = Set(
            records.compactMap { record in
                calendar.dateInterval(of: .month, for: record.startedAt)?.start
            }
        )

        return uniqueStarts
            .sorted(by: >)
            .compactMap { start in
                guard let interval = calendar.dateInterval(of: .month, for: start) else { return nil }
                return MemoStepActivityPickerOption(
                    id: Self.monthIdentifier(for: start, calendar: calendar),
                    title: formatter.string(from: start),
                    anchorDate: start,
                    interval: interval
                )
            }
    }

    static func yearOptions(records: [WorkoutSessionRecord]) -> [MemoStepActivityPickerOption] {
        let calendar = Calendar.memoActivity
        let years = Set(records.map { calendar.component(.year, from: $0.startedAt) })

        return years
            .sorted(by: >)
            .compactMap { year in
                var components = DateComponents()
                components.year = year
                components.month = 1
                components.day = 1
                guard let start = calendar.date(from: components),
                      let interval = calendar.dateInterval(of: .year, for: start) else {
                    return nil
                }

                return MemoStepActivityPickerOption(
                    id: "year-\(year)",
                    title: "\(year)年",
                    anchorDate: start,
                    interval: interval
                )
            }
    }

    static func currentMonthFallback(now: Date) -> MemoStepActivityPickerOption {
        let calendar = Calendar.memoActivity
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        let interval = calendar.dateInterval(of: .month, for: now)
        let anchorDate = interval?.start ?? now

        return MemoStepActivityPickerOption(
            id: Self.monthIdentifier(for: anchorDate, calendar: calendar),
            title: formatter.string(from: anchorDate),
            anchorDate: anchorDate,
            interval: interval
        )
    }

    static func currentYearFallback(now: Date) -> MemoStepActivityPickerOption {
        let calendar = Calendar.memoActivity
        let year = calendar.component(.year, from: now)
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        let anchorDate = calendar.date(from: components) ?? now
        let interval = calendar.dateInterval(of: .year, for: anchorDate)

        return MemoStepActivityPickerOption(
            id: "year-\(year)",
            title: "\(year)年",
            anchorDate: anchorDate,
            interval: interval
        )
    }

    private static func monthIdentifier(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "month-%04d-%02d", year, month)
    }
}

private enum MemoStepActivitySelection {
    case week(MemoStepActivityPickerOption)
    case month(MemoStepActivityPickerOption)
    case year(MemoStepActivityPickerOption)
    case all(title: String)

    var range: MemoStepActivityRange {
        switch self {
        case .week:
            return .week
        case .month:
            return .month
        case .year:
            return .year
        case .all:
            return .all
        }
    }

    var title: String {
        switch self {
        case .week(let option), .month(let option), .year(let option):
            return option.title
        case .all(let title):
            return title
        }
    }

    var interval: DateInterval? {
        switch self {
        case .week(let option), .month(let option), .year(let option):
            return option.interval
        case .all:
            return nil
        }
    }
}

private struct MemoStepActivitySummary {
    let range: MemoStepActivityRange
    let periodTitle: String
    let totalDistanceKilometers: Double
    let totalElapsedSeconds: Int
    let runCount: Int
    let chartEntries: [MemoStepActivityChartEntry]
    let referenceLineValue: Double?
    let chartUpperBound: Double
    let yAxisStep: Double

    private let activeRecords: [WorkoutSessionRecord]

    init(records: [WorkoutSessionRecord], selection: MemoStepActivitySelection) {
        let calendar = Calendar.memoActivity
        let filteredRecords = MemoStepActivitySummary.records(for: selection, from: records)
        self.range = selection.range
        self.activeRecords = filteredRecords
        self.periodTitle = selection.title
        self.totalDistanceKilometers = filteredRecords.reduce(0) { $0 + $1.distanceKilometers }
        self.totalElapsedSeconds = filteredRecords.reduce(0) { $0 + max(0, $1.elapsedSeconds) }
        self.runCount = filteredRecords.count
        self.chartEntries = MemoStepActivitySummary.chartEntries(
            for: selection,
            records: filteredRecords,
            allRecords: records,
            calendar: calendar
        )

        let nonZeroEntries = chartEntries.filter { $0.distanceKilometers > 0 }
        if nonZeroEntries.isEmpty {
            self.referenceLineValue = nil
        } else {
            self.referenceLineValue = nonZeroEntries.reduce(0) { $0 + $1.distanceKilometers } / Double(nonZeroEntries.count)
        }

        let chartScale = MemoStepActivitySummary.chartScale(
            for: chartEntries,
            referenceLineValue: referenceLineValue
        )
        self.chartUpperBound = chartScale.upperBound
        self.yAxisStep = chartScale.step
    }

    var distanceText: String {
        String(format: "%.1f", totalDistanceKilometers)
    }

    var runCountText: String {
        String(runCount)
    }

    var paceText: String {
        MemoStepActivityFormatter.paceText(
            elapsedSeconds: totalElapsedSeconds,
            distanceKilometers: totalDistanceKilometers
        )
    }

    var durationText: String {
        MemoStepActivityFormatter.durationText(seconds: totalElapsedSeconds)
    }

    var axisMarkValues: [String] {
        chartEntries.filter(\.showsAxisLabel).map(\.axisValue)
    }

    var yAxisMarkValues: [Double] {
        guard chartUpperBound > 0, yAxisStep > 0 else { return [0] }

        var values = stride(from: 0.0, through: chartUpperBound, by: yAxisStep).map { value in
            (value * 10).rounded() / 10
        }

        if values.last != chartUpperBound {
            values.append(chartUpperBound)
        }

        return values
    }

    var hasNoActivityInRange: Bool {
        activeRecords.isEmpty
    }

    var referenceLineText: String {
        guard let referenceLineValue else { return "" }
        return String(format: "%.1f", referenceLineValue)
    }

    func yAxisText(for value: Double) -> String {
        if value == 0 {
            return "0km"
        }

        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }

        return String(format: "%.1f", value)
    }

    static func allPeriodTitle(records: [WorkoutSessionRecord], now: Date) -> String {
        let calendar = Calendar.memoActivity
        let currentYear = calendar.component(.year, from: now)
        let firstYear = records.map { calendar.component(.year, from: $0.startedAt) }.min() ?? currentYear

        if firstYear == currentYear {
            return "\(currentYear)年"
        }

        return "\(firstYear)年〜\(currentYear)年"
    }

    private static func records(
        for selection: MemoStepActivitySelection,
        from records: [WorkoutSessionRecord]
    ) -> [WorkoutSessionRecord] {
        guard let interval = selection.interval else { return records }
        return records.filter { interval.contains($0.startedAt) }
    }

    private static func chartEntries(
        for selection: MemoStepActivitySelection,
        records: [WorkoutSessionRecord],
        allRecords: [WorkoutSessionRecord],
        calendar: Calendar
    ) -> [MemoStepActivityChartEntry] {
        switch selection {
        case .week(let option):
            guard let interval = option.interval else { return [] }
            let weekdaySymbols = ["月", "火", "水", "木", "金", "土", "日"]

            return (0..<7).compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start) else {
                    return nil
                }

                let distance = records
                    .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                    .reduce(0) { $0 + $1.distanceKilometers }

                return MemoStepActivityChartEntry(
                    axisValue: weekdaySymbols[offset],
                    distanceKilometers: distance,
                    showsAxisLabel: true
                )
            }

        case .month(let option):
            guard let monthInterval = option.interval,
                  let dayRange = calendar.range(of: .day, in: .month, for: option.anchorDate) else {
                return []
            }

            let highlightedDays = Set(Self.monthAxisDays(lastDay: dayRange.count))

            return dayRange.compactMap { day in
                guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) else {
                    return nil
                }

                let distance = records
                    .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
                    .reduce(0) { $0 + $1.distanceKilometers }

                return MemoStepActivityChartEntry(
                    axisValue: "\(day)",
                    distanceKilometers: distance,
                    showsAxisLabel: highlightedDays.contains(day)
                )
            }

        case .year(let option):
            let selectedYear = calendar.component(.year, from: option.anchorDate)

            return (1...12).map { month in
                let distance = records
                    .filter {
                        calendar.component(.year, from: $0.startedAt) == selectedYear &&
                        calendar.component(.month, from: $0.startedAt) == month
                    }
                    .reduce(0) { $0 + $1.distanceKilometers }

                return MemoStepActivityChartEntry(
                    axisValue: "\(month)",
                    distanceKilometers: distance,
                    showsAxisLabel: true
                )
            }

        case .all:
            let currentYear = calendar.component(.year, from: Date())
            let firstYear = allRecords.map { calendar.component(.year, from: $0.startedAt) }.min() ?? currentYear

            return (firstYear...max(firstYear, currentYear)).map { year in
                let distance = records
                    .filter { calendar.component(.year, from: $0.startedAt) == year }
                    .reduce(0) { $0 + $1.distanceKilometers }

                return MemoStepActivityChartEntry(
                    axisValue: "\(year)",
                    distanceKilometers: distance,
                    showsAxisLabel: true
                )
            }
        }
    }

    private static func monthAxisDays(lastDay: Int) -> [Int] {
        let candidates = [1, 5, 12, 19, 26, lastDay]
        var result: [Int] = []

        for candidate in candidates where candidate >= 1 && candidate <= lastDay {
            if !result.contains(candidate) {
                result.append(candidate)
            }
        }

        return result
    }

    private static func chartScale(
        for entries: [MemoStepActivityChartEntry],
        referenceLineValue: Double?
    ) -> (upperBound: Double, step: Double) {
        let maxValue = max(entries.map(\.distanceKilometers).max() ?? 0, referenceLineValue ?? 0)

        guard maxValue > 0 else {
            return (upperBound: 2, step: 1)
        }

        let step: Double
        switch maxValue {
        case ...4:
            step = 1
        case ...10:
            step = 2
        case ...20:
            step = 4
        case ...40:
            step = 8
        default:
            step = 10
        }

        return (
            upperBound: ceil(maxValue / step) * step,
            step: step
        )
    }
}

private struct MemoStepActivityChartEntry: Identifiable {
    let id = UUID()
    let axisValue: String
    let distanceKilometers: Double
    let showsAxisLabel: Bool
}

private enum MemoStepActivityFormatter {
    private static let calendar = Calendar.memoActivity

    static func durationText(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let secs = safeSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }

        return String(format: "%02d:%02d", minutes, secs)
    }

    static func paceText(elapsedSeconds: Int, distanceKilometers: Double) -> String {
        guard distanceKilometers > 0 else { return "--'--''" }
        let secondsPerKilometer = max(0, Int((Double(elapsedSeconds) / distanceKilometers).rounded()))
        let minutes = secondsPerKilometer / 60
        let seconds = secondsPerKilometer % 60
        return String(format: "%d'%02d''", minutes, seconds)
    }

    static func relativeDateText(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "今日" }
        if calendar.isDateInYesterday(date) { return "昨日" }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    static func weekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    static func weekRangeText(start: Date, endExclusive: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"

        let endDate = calendar.date(byAdding: .day, value: -1, to: endExclusive) ?? endExclusive
        return "\(formatter.string(from: start))〜\(formatter.string(from: endDate))"
    }
}

private extension Calendar {
    static var memoActivity: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 2
        return calendar
    }

    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}
