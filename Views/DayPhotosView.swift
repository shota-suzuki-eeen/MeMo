//
//  DayPhotosView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData
import UIKit

struct DayPhotosView: View {
    let dayKey: String
    let initialFileName: String?
    let titleText: String

    @ObservedObject var viewModel: MemoriesViewModel
    let onToast: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bgmManager: BGMManager

    @Query private var dayEntries: [TodayPhotoEntry]

    @State private var centerToastMessage: String?
    @State private var showCenterToast: Bool = false
    @State private var currentFileName: String

    init(
        dayKey: String,
        initialFileName: String?,
        titleText: String,
        viewModel: MemoriesViewModel,
        onToast: @escaping (String) -> Void
    ) {
        self.dayKey = dayKey
        self.initialFileName = initialFileName
        self.titleText = titleText
        self.viewModel = viewModel
        self.onToast = onToast
        _currentFileName = State(initialValue: initialFileName ?? "")

        let predicate = #Predicate<TodayPhotoEntry> { $0.dayKey == dayKey }
        _dayEntries = Query(filter: predicate, sort: [SortDescriptor(\.date, order: .reverse)])
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Image("Omoide_card")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.18)
                    .ignoresSafeArea()

                if dayEntries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)

                        Text("この日の写真がありません")
                            .font(.title3)
                            .bold()
                    }
                } else {
                    TabView(selection: $currentFileName) {
                        ForEach(dayEntries) { entry in
                            PhotoPage(
                                entry: entry,
                                image: viewModel.image(forFileName: entry.fileName),
                                timeText: viewModel.timeText(for: entry.date),
                                placeTitleText: placeTitleText(for: entry),
                                onDownload: { image in
                                    bgmManager.playSE(.push)

                                    Task {
                                        do {
                                            try await viewModel.saveToPhotos(image)
                                            await MainActor.run {
                                                showCenterToastNow("保存しました！")
                                            }
                                        } catch {
                                            onToast(error.localizedDescription)
                                        }
                                    }
                                }
                            )
                            .tag(entry.fileName)
                            .onAppear {
                                if viewModel.image(forFileName: entry.fileName) == nil {
                                    viewModel.loadImageIfNeeded(fileName: entry.fileName)
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .ignoresSafeArea(edges: .bottom)
                    .onAppear {
                        normalizeCurrentSelection()
                    }
                    .onChange(of: dayEntries.map(\.fileName)) { _, _ in
                        normalizeCurrentSelection()
                    }
                }

                if showCenterToast, let message = centerToastMessage {
                    CenterToastView(message: message)
                        .transition(.opacity.combined(with: .scale))
                        .zIndex(999)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") {
                        bgmManager.playSE(.push)
                        dismiss()
                    }
                }
            }
        }
    }

    private func normalizeCurrentSelection() {
        let fileNames = dayEntries.map(\.fileName)

        guard !fileNames.isEmpty else {
            currentFileName = ""
            return
        }

        if !currentFileName.isEmpty, fileNames.contains(currentFileName) {
            return
        }

        if let initialFileName, fileNames.contains(initialFileName) {
            currentFileName = initialFileName
        } else if let first = fileNames.first {
            currentFileName = first
        }
    }

    private func placeTitleText(for entry: TodayPhotoEntry) -> String {
        let trimmed = entry.placeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return "おもいで"
    }

    private func showCenterToastNow(_ message: String) {
        centerToastMessage = message
        withAnimation(.easeInOut(duration: 0.18)) {
            showCenterToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.18)) {
                showCenterToast = false
            }
        }
    }
}

// MARK: - Page

struct PhotoPage: View {
    let entry: TodayPhotoEntry
    let image: UIImage?
    let timeText: String
    let placeTitleText: String
    let onDownload: (UIImage) -> Void

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 28
            let availableWidth = max(220, proxy.size.width - (horizontalPadding * 2))
            let cardWidth = min(availableWidth, 380)

            VStack(spacing: 14) {
                Spacer(minLength: 10)

                Text(placeTitleText)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("撮影 \(timeText)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))

                MemoryPhotoCardView(
                    image: image,
                    placeholderSystemImage: "photo",
                    showsTiltEffect: true,
                    showsStroke: true
                )
                .frame(width: cardWidth)
                .padding(.top, 4)

                if let image {
                    Button {
                        onDownload(image)
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(.black.opacity(0.78), in: Circle())
                            .shadow(radius: 8)
                    }
                    .padding(.top, 6)
                }

                Spacer(minLength: 24)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct CenterToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.black.opacity(0.82), in: Capsule())
            .shadow(radius: 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
