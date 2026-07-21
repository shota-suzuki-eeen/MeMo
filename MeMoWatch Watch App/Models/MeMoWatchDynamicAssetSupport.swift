//
//  MeMoWatchDynamicAssetSupport.swift
//  MeMo Watch App
//
//  Watch-side storage and rendering support for images transferred dynamically
//  from the paired iPhone. Keep this file in the Watch App target.
//

import Combine
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI

#if os(watchOS)

/// Stores images transferred from the iPhone outside the Watch app bundle.
/// Character, background, food and level-number images can therefore be removed
/// from WatchAssets.xcassets and supplied only when the Watch actually needs them.
enum MeMoWatchDynamicAssetDiskStore {
    private static var directoryName: String {
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "0"
        return "MeMoWatchDynamicAssets-\(build)"
    }

    static func containsAsset(named assetName: String) -> Bool {
        guard let url = assetURL(for: assetName) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    static func cgImage(named assetName: String) -> CGImage? {
        guard let url = assetURL(for: assetName),
              FileManager.default.fileExists(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// WCSessionFile's temporary URL is valid only during the receive callback,
    /// so copy the file into the Watch cache before the callback returns.
    @discardableResult
    static func storeReceivedFile(
        from sourceURL: URL,
        assetName: String
    ) -> Bool {
        guard !assetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let directoryURL = cacheDirectoryURL(),
              let destinationURL = assetURL(for: assetName) else {
            return false
        }

        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let stagingURL = directoryURL
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("incoming")

            try fileManager.copyItem(at: sourceURL, to: stagingURL)

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.moveItem(at: stagingURL, to: destinationURL)
            return true
        } catch {
            print("❌ MeMoWatch dynamic asset store failed: \(error)")
            return false
        }
    }

    private static func cacheDirectoryURL() -> URL? {
        FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent(
            directoryName,
            isDirectory: true
        )
    }

    private static func assetURL(for assetName: String) -> URL? {
        guard let directoryURL = cacheDirectoryURL() else { return nil }

        return directoryURL
            .appendingPathComponent(safeFileName(for: assetName))
            .appendingPathExtension("asset")
    }

    private static func safeFileName(for assetName: String) -> String {
        let encoded = Data(assetName.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")

        return encoded.isEmpty ? "unnamed" : encoded
    }
}

@MainActor
final class MeMoWatchDynamicAssetCache: ObservableObject {
    static let shared = MeMoWatchDynamicAssetCache()

    @Published private(set) var revision: Int = 0

    private var imageCache: [String: CGImage] = [:]
    private var assetStoredCancellable: AnyCancellable?

    private init() {
        assetStoredCancellable = NotificationCenter.default
            .publisher(for: Notification.Name("memo.watch.dynamicAssetStored"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let assetName = notification.object as? String else { return }
                self?.notifyAssetStored(named: assetName)
            }
    }

    func cgImage(named assetName: String) -> CGImage? {
        if let cached = imageCache[assetName] {
            return cached
        }

        guard let image = MeMoWatchDynamicAssetDiskStore.cgImage(named: assetName) else {
            return nil
        }

        imageCache[assetName] = image
        return image
    }

    func containsAsset(named assetName: String) -> Bool {
        imageCache[assetName] != nil
            || MeMoWatchDynamicAssetDiskStore.containsAsset(named: assetName)
    }

    func notifyAssetStored(named assetName: String) {
        imageCache.removeValue(forKey: assetName)
        revision &+= 1
    }
}

/// Displays a dynamically transferred image when cached, otherwise falls back
/// to a bundled image with the same asset name.
@MainActor
struct MeMoWatchDynamicImage: View {
    let assetName: String

    @ObservedObject private var assetCache = MeMoWatchDynamicAssetCache.shared

    var body: some View {
        Group {
            if let cgImage = assetCache.cgImage(named: assetName) {
                Image(
                    decorative: cgImage,
                    scale: 1,
                    orientation: .up
                )
                .resizable()
            } else {
                Image(assetName)
                    .resizable()
            }
        }
        // Reading revision makes the view refresh immediately after a newly
        // transferred image is stored in the Watch cache.
        .id(assetCache.revision)
    }
}

#endif
