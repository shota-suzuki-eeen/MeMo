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
    let initialFileName: String?   // ✅ これで開始インデックスを決める
    let titleText: String

    @ObservedObject var viewModel: MemoriesViewModel
    let onToast: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bgmManager: BGMManager

    @Query private var dayEntries: [TodayPhotoEntry]

    // ✅ 追加：保存完了を画面中央に出す
    @State private var centerToastMessage: String?
    @State private var showCenterToast: Bool = false

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

        let predicate = #Predicate<TodayPhotoEntry> { $0.dayKey == dayKey }
        _dayEntries = Query(filter: predicate, sort: [SortDescriptor(\.date, order: .reverse)])
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    // ✅ monthタップ → シートで出る画面（カード）の背景を画像にする
                    //    既存UIレイアウトに影響しないよう、最背面に敷くだけ
                    Image("Omoide_card")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()

                    // ✅ 読みやすさ用の薄い暗幕（不要なら opacity を 0 にしてOK）
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()

                    if dayEntries.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text("この日の写真がありません")
                                .font(.title3).bold()
                        }
                    } else {
                        ScrollViewReader { proxy in
                            // ✅ 仕様変更：左右スワイプ（横ページング）
                            ScrollView(.horizontal) {
                                LazyHStack(spacing: 0) {
                                    ForEach(dayEntries) { e in
                                        PhotoPage(
                                            entry: e,
                                            image: viewModel.image(forFileName: e.fileName),
                                            timeText: viewModel.timeText(for: e.date),
                                            placeTitleText: placeTitleText(for: e),
                                            onDownload: { img in
                                                bgmManager.playSE(.push)

                                                Task {
                                                    do {
                                                        try await viewModel.saveToPhotos(img)

                                                        // ✅ 仕様：保存完了を画面中央に表示
                                                        showCenterToastNow("保存しました！")

                                                    } catch {
                                                        onToast(error.localizedDescription)
                                                    }
                                                }
                                            }
                                        )
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .id(e.fileName)
                                        .onAppear {
                                            // ✅ 画像がまだなら読み込み
                                            if viewModel.image(forFileName: e.fileName) == nil {
                                                viewModel.loadImageIfNeeded(fileName: e.fileName)
                                            }
                                        }
                                    }
                                }
                            }
                            .scrollTargetBehavior(.paging)
                            .scrollIndicators(.hidden)
                            .onAppear {
                                // ✅ 最初に表示したい写真へジャンプ
                                if let initialFileName {
                                    DispatchQueue.main.async {
                                        proxy.scrollTo(initialFileName, anchor: .center)
                                    }
                                }
                            }
                        }
                    }

                    // ✅ 中央トースト（最前面）
                    if showCenterToast, let msg = centerToastMessage {
                        CenterToastView(message: msg)
                            .transition(.opacity.combined(with: .scale))
                            .zIndex(999)
                            .allowsHitTesting(false)
                    }
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

    // MARK: - Place title

    private func placeTitleText(for entry: TodayPhotoEntry) -> String {
        let trimmed = entry.placeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return "おもいで"
    }

    // MARK: - Center toast

    private func showCenterToastNow(_ message: String) {
        centerToastMessage = message
        withAnimation(.easeInOut(duration: 0.18)) { showCenterToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.18)) { showCenterToast = false }
        }
    }
}

// MARK: - Page

struct PhotoPage: View {
    let entry: TodayPhotoEntry
    let image: UIImage?
    let timeText: String

    // ✅ 追加：場所タイトル
    let placeTitleText: String

    let onDownload: (UIImage) -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 10) {
                Spacer().frame(height: 10)

                // ✅ 仕様変更：タイトルを場所に（バーではなく画面内に表示）
                Text(placeTitleText)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // ✅ 時刻は残したい場合はサブ表示（既存を壊さない）
                Text("撮影 \(timeText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 12)
                } else {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("読み込み中…")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                Spacer()
            }

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
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

// ✅ 画面中央表示用トースト
private struct CenterToastView: View {
    let message: String

    var body: some View {
        VStack {
            Text(message)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.black.opacity(0.82), in: Capsule())
                .shadow(radius: 10)

            // ちょい下に余白（視認性）
            Spacer().frame(height: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
