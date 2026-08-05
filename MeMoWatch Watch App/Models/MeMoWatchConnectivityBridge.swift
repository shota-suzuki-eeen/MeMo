//
//  MeMoWatchConnectivityBridge.swift
//  MeMo
//
//  Shared iPhone / Watch bridge.
//  Add this file to both the iPhone App target and the Watch App target.
//

import Combine
import CoreGraphics
import Foundation

#if os(watchOS)
import ImageIO
import SwiftUI
#endif

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

#if os(iOS) && canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Dynamically transferred Watch assets

enum MeMoWatchDynamicAssetTransferConstants {
    static let assetNameMetadataKey = "memoDynamicAssetName"
    static let watchInstanceIDKey = "memoWatchInstanceID"
    static let watchBuildKey = "memoWatchBuild"
}

private struct MeMoWatchImmediateDynamicAssetEnvelope: Codable {
    let assetName: String
    let payload: Data
}

#if os(watchOS)
/// Watchの再インストール、またはビルド更新をiPhone側で識別するためのID。
/// 再インストール時はUserDefaultsが消えるためUUIDが変わり、ビルド更新時も再生成する。
private enum MeMoWatchInstallationIdentity {
    private static let storedIDKey = "memo.watch.installationIdentity.id"
    private static let storedBuildKey = "memo.watch.installationIdentity.build"

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static var identifier: String {
        let defaults = UserDefaults.standard
        let currentBuild = build

        if defaults.string(forKey: storedBuildKey) == currentBuild,
           let existingID = defaults.string(forKey: storedIDKey),
           !existingID.isEmpty {
            return existingID
        }

        let newID = UUID().uuidString
        defaults.set(newID, forKey: storedIDKey)
        defaults.set(currentBuild, forKey: storedBuildKey)
        return newID
    }
}

/// Bridge-local disk access used only by WatchConnectivity.
/// Build番号ごとに保存先を分けるため、Watch更新後に旧画像を誤利用しない。
private enum MeMoWatchBridgeDynamicAssetDiskStore {
    private static var directoryName: String {
        "MeMoWatchDynamicAssets-\(MeMoWatchInstallationIdentity.build)"
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
            print("❌ MeMoWatch bridge dynamic asset store failed: \(error)")
            return false
        }
    }

    @discardableResult
    static func storeReceivedData(
        _ data: Data,
        assetName: String
    ) -> Bool {
        guard !data.isEmpty,
              !assetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
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

            try data.write(to: stagingURL, options: .atomic)

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.moveItem(at: stagingURL, to: destinationURL)
            return true
        } catch {
            print("❌ MeMoWatch bridge immediate asset store failed: \(error)")
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

/// Watch-side in-memory cache for dynamically transferred images.
@MainActor
final class MeMoWatchDynamicAssetCache: ObservableObject {
    static let shared = MeMoWatchDynamicAssetCache()

    @Published private(set) var revision: Int = 0
    @Published private(set) var lastStoredAssetName: String?

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

        guard let image = MeMoWatchBridgeDynamicAssetDiskStore.cgImage(named: assetName) else {
            return nil
        }

        imageCache[assetName] = image
        return image
    }

    func containsAsset(named assetName: String) -> Bool {
        imageCache[assetName] != nil
            || MeMoWatchBridgeDynamicAssetDiskStore.containsAsset(named: assetName)
    }

    func notifyAssetStored(named assetName: String) {
        imageCache.removeValue(forKey: assetName)
        lastStoredAssetName = assetName
        revision &+= 1
    }
}

/// 新画像の到着までは直前の画像を保持し、同期中の空白表示を防ぐ。
@MainActor
struct MeMoWatchDynamicImage: View {
    let assetName: String

    @ObservedObject private var assetCache = MeMoWatchDynamicAssetCache.shared
    @State private var retainedImage: CGImage?

    private var resolvedImage: CGImage? {
        assetCache.cgImage(named: assetName) ?? retainedImage
    }

    var body: some View {
        Group {
            if let cgImage = resolvedImage {
                Image(
                    decorative: cgImage,
                    scale: 1,
                    orientation: .up
                )
                .resizable()
            } else {
                Color.clear
            }
        }
        .onAppear {
            updateRetainedImageIfAvailable()
        }
        .onChange(of: assetName) { _, _ in
            updateRetainedImageIfAvailable()
        }
        .onChange(of: assetCache.revision) { _, _ in
            updateRetainedImageIfAvailable()
        }
    }

    private func updateRetainedImageIfAvailable() {
        if let image = assetCache.cgImage(named: assetName) {
            retainedImage = image
        }
    }
}
#endif

#if os(iOS) && canImport(UIKit)
import UIKit
#endif

struct MeMoWatchFoodItemSnapshot: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var assetName: String
    var rarity: String
    var count: Int

    var isRare: Bool {
        rarity == "R"
    }
}

struct MeMoWatchToiletPoopSnapshot: Codable, Equatable, Identifiable {
    var id: String
    var centerXRatio: Double
    var centerYRatio: Double
    var rotationDegrees: Double
    var isFlippedHorizontally: Bool
    var cleanedProgress: Double
}

struct MeMoWatchSnapshot: Codable, Equatable {
    var todaySteps: Int
    var dailyStepGoal: Int

    var happinessPoint: Int
    var happinessLevel: Int
    var happinessMaxPoint: Int

    var fullnessLevel: Int
    var fullnessMaxLevel: Int

    var characterAssetName: String
    var backgroundAssetName: String

    // Optional fields keep snapshots saved by older app versions decodable.
    var desiredFoodID: String? = nil
    var desiredFoodAssetName: String? = nil
    var ownedFoods: [MeMoWatchFoodItemSnapshot]? = nil

    // Toilet fields are optional so snapshots stored by earlier app versions remain decodable.
    var hasToiletFlag: Bool? = nil
    var toiletPoops: [MeMoWatchToiletPoopSnapshot]? = nil

    var updatedAt: Date

    static let placeholder = MeMoWatchSnapshot(
        todaySteps: 0,
        dailyStepGoal: 10_000,
        happinessPoint: 0,
        happinessLevel: 0,
        happinessMaxPoint: 100,
        fullnessLevel: 0,
        fullnessMaxLevel: 5,
        characterAssetName: "person",
        backgroundAssetName: "Home_background",
        desiredFoodID: nil,
        desiredFoodAssetName: nil,
        ownedFoods: [],
        hasToiletFlag: false,
        toiletPoops: [],
        updatedAt: Date()
    )
}

@MainActor
final class MeMoWatchConnectivityBridge: NSObject, ObservableObject {
    static let shared = MeMoWatchConnectivityBridge()

    private static let userDefaultsKey = "memo.watch.latestSnapshot"

    @Published private(set) var latestSnapshot: MeMoWatchSnapshot =
        MeMoWatchConnectivityBridge.initialSnapshot()

    #if canImport(WatchConnectivity)
    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }
    #endif

    #if os(iOS)
    private static let dynamicAssetRetryInterval: TimeInterval = 3.0

    private weak var appState: AppState?
    private weak var healthKitManager: HealthKitManager?
    private var lastBackgroundAssetName: String = "Home_background"
    private var persistChangesHandler: (() -> Void)?
    private var pendingWatchEvents: [[String: Any]] = []
    private var processedWatchRequestIDs: Set<String> = []
    private var processedWatchRequestIDOrder: [String] = []
    private var isRefreshingStepsForWatch = false

    /// ACKを受信した画像だけを配信完了として扱う。
    private var acknowledgedDynamicAssetNames: Set<String> = []
    private var inFlightImmediateDynamicAssetNames: Set<String> = []
    private var inFlightFileDynamicAssetNames: Set<String> = []
    private var dynamicAssetLastAttemptDates: [String: Date] = [:]
    private var dynamicAssetRetryTask: Task<Void, Never>?
    private var knownWatchInstanceID: String?
    #endif

    #if os(watchOS)
    private static let dynamicAssetRequestRetryInterval: TimeInterval = 2.5
    private var dynamicAssetLastRequestDates: [String: Date] = [:]
    private var dynamicAssetRetryTask: Task<Void, Never>?
    #endif

    private override init() {
        super.init()
    }

    func activate() {
        #if canImport(WatchConnectivity)
        guard let session else { return }

        session.delegate = self

        if session.activationState == .notActivated {
            session.activate()
        }

        #if os(watchOS)
        announceWatchIdentity()
        requestMissingDynamicAssets(for: latestSnapshot)
        #endif
        #endif
    }

    #if os(iOS)
    func install(
        appState: AppState,
        healthKitManager: HealthKitManager,
        persistChanges: (() -> Void)? = nil
    ) {
        self.appState = appState
        self.healthKitManager = healthKitManager
        self.persistChangesHandler = persistChanges
        activate()
        publishCurrentSnapshot(backgroundAssetName: nil)
        flushPendingWatchEventsIfNeeded()
    }

    func refreshLatestStepsAndPublish(
        backgroundAssetName: String? = nil,
        now: Date = Date()
    ) async {
        guard !isRefreshingStepsForWatch else {
            publishCurrentSnapshot(backgroundAssetName: backgroundAssetName, now: now)
            return
        }

        isRefreshingStepsForWatch = true
        defer { isRefreshingStepsForWatch = false }

        if let healthKitManager {
            await healthKitManager.refreshTodayStepsForWidget(now: now)
        }

        synchronizeBackgroundStepGainIfNeeded(now: now)
        publishCurrentSnapshot(backgroundAssetName: backgroundAssetName, now: now)
    }

    private func synchronizeBackgroundStepGainIfNeeded(now: Date) {
        guard let appState, let healthKitManager else { return }

        #if canImport(UIKit)
        guard UIApplication.shared.applicationState == .background else { return }
        #endif

        let todayKey = AppState.makeDayKey(now)

        if appState.lastDayKey != todayKey {
            appState.cachedTodaySteps = 0
            appState.cachedTodayMeterSteps = 0
            appState.ensureDailyResetIfNeeded(now: now)
            appState.lastSyncedAt = Calendar.current.startOfDay(for: now)
        }

        let previousCachedSteps = max(0, appState.cachedTodaySteps)
        let fetchedSteps = max(0, healthKitManager.todaySteps)
        let cacheResult = appState.updateTodayStepCacheProtectingZero(
            fetchedSteps: fetchedSteps,
            todayKey: todayKey
        )

        let deltaSteps = max(0, cacheResult.stepsToUse - previousCachedSteps)
        appState.lastSyncedAt = now

        if deltaSteps > 0 {
            _ = appState.addWalletSteps(deltaSteps)
        }

        persistChangesHandler?()
        refreshWidgetSnapshotIfAvailable(appState: appState, now: now)
    }

    private func resetDynamicAssetDeliveryState() {
        acknowledgedDynamicAssetNames.removeAll()
        inFlightImmediateDynamicAssetNames.removeAll()
        inFlightFileDynamicAssetNames.removeAll()
        dynamicAssetLastAttemptDates.removeAll()
        dynamicAssetRetryTask?.cancel()
        dynamicAssetRetryTask = nil
    }

    private func registerWatchIdentityIfNeeded(from dictionary: [String: Any]) {
        guard let incomingID = dictionary[
            MeMoWatchDynamicAssetTransferConstants.watchInstanceIDKey
        ] as? String,
        !incomingID.isEmpty else {
            return
        }

        guard knownWatchInstanceID != incomingID else { return }

        knownWatchInstanceID = incomingID
        resetDynamicAssetDeliveryState()

        // Watchの再インストールまたはビルド更新後は、現在表示に必要な画像を強制再送する。
        forceResendCurrentPresentationAssets()
    }

    private func forceResendCurrentPresentationAssets() {
        guard appState != nil else { return }
        publishCurrentSnapshot(
            backgroundAssetName: nil,
            forceDynamicAssetNames: Set(
                Self.presentationDynamicAssetNames(for: latestSnapshot)
            )
        )
    }

    @discardableResult
    private func transferDynamicAssetsToWatch(
        assetNames: [String],
        force: Bool = false
    ) -> Set<String> {
        #if canImport(WatchConnectivity) && canImport(UIKit)
        guard let session,
              session.activationState == .activated else {
            return []
        }

        let outstandingNames = Set(
            session.outstandingFileTransfers.compactMap { transfer in
                transfer.file.metadata?[
                    MeMoWatchDynamicAssetTransferConstants.assetNameMetadataKey
                ] as? String
            }
        )

        var seenNames = Set<String>()
        let uniqueNames = assetNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seenNames.insert($0).inserted }
            .prefix(128)

        var scheduledNames = Set<String>()

        for assetName in uniqueNames {
            if !force,
               (acknowledgedDynamicAssetNames.contains(assetName)
                || inFlightFileDynamicAssetNames.contains(assetName)
                || outstandingNames.contains(assetName)) {
                continue
            }

            autoreleasepool {
                guard let fileURL = makeDynamicAssetTransferFile(assetName: assetName) else {
                    return
                }

                session.transferFile(
                    fileURL,
                    metadata: [
                        MeMoWatchDynamicAssetTransferConstants.assetNameMetadataKey: assetName
                    ]
                )
                inFlightFileDynamicAssetNames.insert(assetName)
                dynamicAssetLastAttemptDates[assetName] = Date()
                scheduledNames.insert(assetName)
            }
        }

        return scheduledNames
        #else
        return []
        #endif
    }

    @discardableResult
    private func sendImmediateDynamicAssetsToWatch(
        assetNames: [String],
        force: Bool = false
    ) -> Set<String> {
        #if canImport(WatchConnectivity) && canImport(UIKit)
        guard let session,
              session.activationState == .activated,
              session.isReachable else {
            return []
        }

        var seenNames = Set<String>()
        let uniqueNames = assetNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seenNames.insert($0).inserted }
            .prefix(16)

        var attemptedNames = Set<String>()

        for assetName in uniqueNames {
            if !force,
               (acknowledgedDynamicAssetNames.contains(assetName)
                || inFlightImmediateDynamicAssetNames.contains(assetName)) {
                continue
            }

            autoreleasepool {
                guard let data = makeImmediateDynamicAssetEnvelopeData(
                    assetName: assetName
                ) else {
                    return
                }

                inFlightImmediateDynamicAssetNames.insert(assetName)
                dynamicAssetLastAttemptDates[assetName] = Date()
                attemptedNames.insert(assetName)

                session.sendMessageData(
                    data,
                    replyHandler: nil,
                    errorHandler: { [weak self] _ in
                        Task { @MainActor in
                            guard let self else { return }
                            self.inFlightImmediateDynamicAssetNames.remove(assetName)
                            _ = self.transferDynamicAssetsToWatch(
                                assetNames: [assetName],
                                force: true
                            )
                            self.scheduleDynamicAssetRetryIfNeeded()
                        }
                    }
                )
            }
        }

        return attemptedNames
        #else
        return []
        #endif
    }

    private func invalidateDeliveryState(for assetNames: Set<String>) {
        guard !assetNames.isEmpty else { return }

        acknowledgedDynamicAssetNames.subtract(assetNames)
        inFlightImmediateDynamicAssetNames.subtract(assetNames)
        inFlightFileDynamicAssetNames.subtract(assetNames)

        for name in assetNames {
            dynamicAssetLastAttemptDates.removeValue(forKey: name)
        }
    }

    private func proactivelyTransferDynamicAssetsIfNeeded(
        for snapshot: MeMoWatchSnapshot,
        forceAssetNames: Set<String> = []
    ) {
        if !forceAssetNames.isEmpty {
            invalidateDeliveryState(for: forceAssetNames)
        }

        let now = Date()
        let criticalNames = Self.criticalDynamicAssetNames(for: snapshot)
        let immediateCandidates = criticalNames.filter { name in
            guard !acknowledgedDynamicAssetNames.contains(name) else { return false }
            if forceAssetNames.contains(name) { return true }
            guard !inFlightImmediateDynamicAssetNames.contains(name) else { return false }
            guard let lastAttempt = dynamicAssetLastAttemptDates[name] else { return true }
            return now.timeIntervalSince(lastAttempt) >= Self.dynamicAssetRetryInterval
        }

        _ = sendImmediateDynamicAssetsToWatch(
            assetNames: immediateCandidates,
            force: !forceAssetNames.isEmpty
        )

        // 即時送信とは別にファイル転送も予約し、到達性が変わっても配送を保証する。
        let requiredNames = Self.requiredDynamicAssetNames(for: snapshot)
        let fileCandidates = requiredNames.filter { name in
            guard !acknowledgedDynamicAssetNames.contains(name) else { return false }
            if forceAssetNames.contains(name) { return true }
            guard !inFlightFileDynamicAssetNames.contains(name) else { return false }
            guard let lastAttempt = dynamicAssetLastAttemptDates[name] else { return true }
            return now.timeIntervalSince(lastAttempt) >= Self.dynamicAssetRetryInterval
        }

        _ = transferDynamicAssetsToWatch(
            assetNames: fileCandidates,
            force: !forceAssetNames.isEmpty
        )

        scheduleDynamicAssetRetryIfNeeded()
    }

    private func scheduleDynamicAssetRetryIfNeeded() {
        guard dynamicAssetRetryTask == nil else { return }

        let required = Set(Self.requiredDynamicAssetNames(for: latestSnapshot))
        guard !required.isSubset(of: acknowledgedDynamicAssetNames) else { return }

        dynamicAssetRetryTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(
                    nanoseconds: UInt64(
                        Self.dynamicAssetRetryInterval * 1_000_000_000
                    )
                )
            } catch {
                self.dynamicAssetRetryTask = nil
                return
            }

            self.dynamicAssetRetryTask = nil
            self.proactivelyTransferDynamicAssetsIfNeeded(
                for: self.latestSnapshot
            )
        }
    }

    private func handleAssetStoredAcknowledgement(assetName: String) {
        let normalizedName = assetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }

        acknowledgedDynamicAssetNames.insert(normalizedName)
        inFlightImmediateDynamicAssetNames.remove(normalizedName)
        inFlightFileDynamicAssetNames.remove(normalizedName)
        dynamicAssetLastAttemptDates.removeValue(forKey: normalizedName)

        scheduleDynamicAssetRetryIfNeeded()
    }

    #if canImport(UIKit)
    private func makeDynamicAssetTransferFile(assetName: String) -> URL? {
        guard let sourceImage = UIImage(named: assetName) else {
            return nil
        }

        let maximumPixelDimension = preferredMaximumPixelDimension(for: assetName)
        guard let data = optimizedAssetData(
            from: sourceImage,
            assetName: assetName,
            maximumPixelDimension: maximumPixelDimension
        ) else {
            return nil
        }

        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "MeMoWatchDynamicAssetTransfers",
                isDirectory: true
            )

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let fileURL = directoryURL
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("png")

            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("❌ MeMoWatch dynamic asset preparation failed: \(error)")
            return nil
        }
    }

    private func makeImmediateDynamicAssetEnvelopeData(
        assetName: String
    ) -> Data? {
        guard let sourceImage = UIImage(named: assetName),
              let payload = optimizedAssetData(
                from: sourceImage,
                assetName: assetName,
                maximumPixelDimension: preferredImmediateMaximumPixelDimension(
                    for: assetName
                )
              ) else {
            return nil
        }

        return try? PropertyListEncoder().encode(
            MeMoWatchImmediateDynamicAssetEnvelope(
                assetName: assetName,
                payload: payload
            )
        )
    }

    private func preferredMaximumPixelDimension(for assetName: String) -> CGFloat {
        if Int(assetName) != nil { return 192 }
        if assetName == lastBackgroundAssetName { return 640 }
        if FoodCatalog.all.contains(where: { $0.assetName == assetName }) { return 320 }
        return 640
    }

    private func preferredImmediateMaximumPixelDimension(
        for assetName: String
    ) -> CGFloat {
        if Int(assetName) != nil { return 160 }
        if assetName == lastBackgroundAssetName { return 512 }
        if FoodCatalog.all.contains(where: { $0.assetName == assetName }) { return 256 }
        return 512
    }

    private func optimizedAssetData(
        from image: UIImage,
        assetName: String,
        maximumPixelDimension: CGFloat
    ) -> Data? {
        let pixelWidth = CGFloat(image.cgImage?.width ?? 0)
        let pixelHeight = CGFloat(image.cgImage?.height ?? 0)
        let currentMaximum = max(pixelWidth, pixelHeight)

        guard currentMaximum > 0,
              currentMaximum > maximumPixelDimension else {
            return encodedAssetData(from: image, assetName: assetName)
        }

        let ratio = maximumPixelDimension / currentMaximum
        let targetSize = CGSize(
            width: max(1, pixelWidth * ratio),
            height: max(1, pixelHeight * ratio)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return encodedAssetData(from: resizedImage, assetName: assetName)
    }

    private func encodedAssetData(
        from image: UIImage,
        assetName: String
    ) -> Data? {
        if assetName == lastBackgroundAssetName {
            return image.jpegData(compressionQuality: 0.84)
        }

        return image.pngData()
    }
    #endif

    func publishCurrentSnapshot(
        backgroundAssetName: String? = nil,
        now: Date = Date()
    ) {
        publishCurrentSnapshot(
            backgroundAssetName: backgroundAssetName,
            now: now,
            forceDynamicAssetNames: []
        )
    }

    private func publishCurrentSnapshot(
        backgroundAssetName: String?,
        now: Date = Date(),
        forceDynamicAssetNames: Set<String>
    ) {
        guard let appState else { return }

        if appState.hasToiletFlag {
            let didUpdateToiletPoops = appState.updateToiletPoopsByTime(now: now)
            if didUpdateToiletPoops {
                persistChangesHandler?()
                refreshWidgetSnapshotIfAvailable(appState: appState, now: now)
            }
        }

        let resolvedBackgroundAssetName: String
        if let backgroundAssetName,
           !backgroundAssetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedBackgroundAssetName = backgroundAssetName
            lastBackgroundAssetName = backgroundAssetName
        } else {
            resolvedBackgroundAssetName = lastBackgroundAssetName
        }

        let todaySteps = max(
            0,
            max(healthKitManager?.todaySteps ?? 0, appState.cachedTodaySteps)
        )

        let fullnessLevel = appState.currentSatisfaction(now: now)
        if fullnessLevel < AppState.fullnessMaxLevel {
            _ = appState.ensureDesiredFoodIfNeeded()
        }

        let desiredFood = appState.desiredFood
        let ownedFoods = FoodCatalog.all.compactMap { food -> MeMoWatchFoodItemSnapshot? in
            let count = appState.foodCount(foodId: food.id)
            guard count > 0 else { return nil }

            return MeMoWatchFoodItemSnapshot(
                id: food.id,
                name: food.name,
                assetName: food.assetName,
                rarity: food.isShopEligible ? "N" : "R",
                count: count
            )
        }

        let hasToiletFlag = appState.hasToiletFlag
        let toiletPoops = Array(
            appState.toiletPoops()
                .filter { !$0.isCleared }
                .prefix(AppState.toiletPoopMaxCount)
        )
        .map { poop in
            MeMoWatchToiletPoopSnapshot(
                id: poop.id,
                centerXRatio: poop.centerXRatio,
                centerYRatio: poop.centerYRatio,
                rotationDegrees: poop.rotationDegrees,
                isFlippedHorizontally: poop.isFlippedHorizontally,
                cleanedProgress: max(0, min(1, poop.cleanedProgress))
            )
        }

        let snapshot = MeMoWatchSnapshot(
            todaySteps: todaySteps,
            dailyStepGoal: AppState.fixedDailyStepGoal,
            happinessPoint: appState.happinessPoint,
            happinessLevel: appState.happinessLevel,
            happinessMaxPoint: AppState.happinessMaxPointsPerLevel,
            fullnessLevel: fullnessLevel,
            fullnessMaxLevel: AppState.fullnessMaxLevel,
            characterAssetName: PetMaster.assetName(
                for: appState.normalizedCurrentPetID
            ),
            backgroundAssetName: resolvedBackgroundAssetName,
            desiredFoodID: desiredFood?.id,
            desiredFoodAssetName: desiredFood?.assetName,
            ownedFoods: ownedFoods,
            hasToiletFlag: hasToiletFlag,
            toiletPoops: toiletPoops,
            updatedAt: now
        )

        let previousSnapshot = latestSnapshot
        var forcedNames = forceDynamicAssetNames

        if previousSnapshot.characterAssetName != snapshot.characterAssetName {
            forcedNames.formUnion(Self.characterDynamicAssetNames(for: snapshot))
        }

        if previousSnapshot.backgroundAssetName != snapshot.backgroundAssetName {
            forcedNames.insert(snapshot.backgroundAssetName)
        }

        apply(snapshot)
        send(snapshot, forceAssetNames: forcedNames)
    }

    @discardableResult
    private func resolveFoodFeedRequest(foodID: String) -> Bool {
        guard let appState else { return false }
        guard !appState.hasToiletFlag else {
            publishCurrentSnapshot(backgroundAssetName: nil)
            return false
        }
        guard let food = FoodCatalog.byId(foodID) else {
            publishCurrentSnapshot(backgroundAssetName: nil)
            return false
        }

        let now = Date()
        let feedState = appState.canFeedNow(now: now)
        guard feedState.can else {
            publishCurrentSnapshot(backgroundAssetName: nil, now: now)
            return false
        }

        guard appState.foodCount(foodId: foodID) > 0,
              appState.consumeFood(foodId: foodID, count: 1) else {
            publishCurrentSnapshot(backgroundAssetName: nil, now: now)
            return false
        }

        let feedResult = appState.feedOnce(now: now)
        guard feedResult.didFeed else {
            publishCurrentSnapshot(backgroundAssetName: nil, now: now)
            return false
        }

        _ = appState.resolveFood(now: now)

        let happinessBonus = appState.happinessBonusPoints(forFoodID: food.id)
            + appState.desiredFoodAdditionalHappinessBonus(forFoodID: food.id)

        _ = appState.registerDesiredFoodFeedingResult(foodID: food.id)

        if happinessBonus > 0 {
            _ = appState.addHappinessPoints(happinessBonus, now: now)
        }

        persistChangesHandler?()
        refreshWidgetSnapshotIfAvailable(appState: appState, now: now)
        publishCurrentSnapshot(backgroundAssetName: nil, now: now)
        return true
    }

    @discardableResult
    private func resolveToiletPoopProgressRequest(
        poopID: String,
        progress: Double
    ) -> Bool {
        guard let appState else { return false }

        let now = Date()

        if appState.hasToiletFlag {
            _ = appState.updateToiletPoopsByTime(now: now)
        }

        guard appState.hasToiletFlag else {
            publishCurrentSnapshot(backgroundAssetName: nil, now: now)
            return false
        }

        let clampedProgress = max(0, min(1, progress))
        guard appState.toiletPoops().contains(where: {
            $0.id == poopID && !$0.isCleared
        }) else {
            publishCurrentSnapshot(backgroundAssetName: nil, now: now)
            return false
        }

        _ = appState.updateToiletPoopProgress(id: poopID, progress: clampedProgress)

        if clampedProgress >= 1 {
            _ = appState.markToiletPoopCleared(id: poopID)
        }

        if !appState.hasRemainingToiletPoops {
            let result = appState.resolveToilet(now: now)
            if result.didResolve {
                _ = appState.addHappinessPoints(10, now: now)
            }
        }

        persistChangesHandler?()
        refreshWidgetSnapshotIfAvailable(appState: appState, now: now)
        publishCurrentSnapshot(backgroundAssetName: nil, now: now)
        return true
    }

    private func refreshWidgetSnapshotIfAvailable(appState: AppState, now: Date) {
        #if canImport(WidgetKit)
        let todaySteps = max(
            0,
            max(healthKitManager?.todaySteps ?? 0, appState.cachedTodaySteps)
        )
        let widgetState = appState.makeWidgetStateSnapshot(todaySteps: todaySteps)
        let changed = HomeWidgetBridge.save(widgetState: widgetState, state: appState)
        if changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
    #endif

    func sendPettingTouch() {
        #if os(watchOS)
        sendWatchEvent("pettingTouch")
        #endif
    }

    func sendFoodFeedRequest(foodID: String) {
        #if os(watchOS)
        guard !foodID.isEmpty else { return }
        sendWatchEvent("feedFood", payload: ["foodID": foodID])
        #endif
    }

    func sendToiletPoopProgress(
        poopID: String,
        progress: Double
    ) {
        #if os(watchOS)
        guard !poopID.isEmpty else { return }
        sendWatchEvent(
            "updateToiletPoopProgress",
            payload: [
                "poopID": poopID,
                "progress": max(0, min(1, progress))
            ]
        )
        #endif
    }

    func requestCurrentSnapshot() {
        #if os(watchOS)
        announceWatchIdentity()
        sendWatchEvent("requestSnapshot")
        #endif
    }

    #if os(watchOS)
    private func announceWatchIdentity() {
        sendWatchEvent("watchHello")
    }

    private func sendAssetStoredAcknowledgement(assetName: String) {
        sendWatchEvent(
            "assetStoredAck",
            payload: ["assetName": assetName]
        )
    }

    private func requestMissingDynamicAssets(
        for snapshot: MeMoWatchSnapshot,
        now: Date = Date()
    ) {
        let requiredNames = Self.requiredDynamicAssetNames(for: snapshot)
        let missingNames = requiredNames.filter { assetName in
            guard !MeMoWatchBridgeDynamicAssetDiskStore.containsAsset(named: assetName) else {
                dynamicAssetLastRequestDates.removeValue(forKey: assetName)
                return false
            }

            guard let lastRequestDate = dynamicAssetLastRequestDates[assetName] else {
                return true
            }

            return now.timeIntervalSince(lastRequestDate)
                >= Self.dynamicAssetRequestRetryInterval
        }

        guard !missingNames.isEmpty else { return }

        for assetName in missingNames {
            dynamicAssetLastRequestDates[assetName] = now
        }

        sendWatchEvent(
            "requestAssets",
            payload: ["assetNames": missingNames]
        )
        scheduleDynamicAssetRetryIfNeeded()
    }

    private func scheduleDynamicAssetRetryIfNeeded() {
        guard dynamicAssetRetryTask == nil else { return }

        dynamicAssetRetryTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(
                    nanoseconds: UInt64(
                        Self.dynamicAssetRequestRetryInterval * 1_000_000_000
                    )
                )
            } catch {
                self.dynamicAssetRetryTask = nil
                return
            }

            self.dynamicAssetRetryTask = nil
            self.requestMissingDynamicAssets(for: self.latestSnapshot)
        }
    }
    #endif

    private static func presentationDynamicAssetNames(
        for snapshot: MeMoWatchSnapshot
    ) -> [String] {
        var names = characterDynamicAssetNames(for: snapshot)
        names.append(snapshot.backgroundAssetName)
        return uniqueNormalizedAssetNames(names)
    }

    private static func characterDynamicAssetNames(
        for snapshot: MeMoWatchSnapshot
    ) -> [String] {
        let base = snapshot.characterAssetName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return [] }

        return uniqueNormalizedAssetNames([
            base,
            "\(base)_wc",
            "\(base)_idle_blink_0001",
            "\(base)_idle_blink_0002"
        ])
    }

    private static func criticalDynamicAssetNames(
        for snapshot: MeMoWatchSnapshot
    ) -> [String] {
        var names: [String] = []
        let baseCharacterName = snapshot.characterAssetName
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if snapshot.hasToiletFlag == true, !baseCharacterName.isEmpty {
            names.append("\(baseCharacterName)_wc")
        } else {
            names.append(baseCharacterName)
        }

        names.append(String(min(40, max(0, snapshot.happinessLevel))))
        names.append(snapshot.backgroundAssetName)

        if let desired = snapshot.desiredFoodAssetName {
            names.append(desired)
        }

        return uniqueNormalizedAssetNames(names)
    }

    private static func requiredDynamicAssetNames(
        for snapshot: MeMoWatchSnapshot
    ) -> [String] {
        var names = criticalDynamicAssetNames(for: snapshot)
        names.append(contentsOf: characterDynamicAssetNames(for: snapshot))

        for food in snapshot.ownedFoods ?? [] {
            names.append(food.assetName)
        }

        return uniqueNormalizedAssetNames(names)
    }

    private static func uniqueNormalizedAssetNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.compactMap { rawName in
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name).inserted else { return nil }
            return name
        }
    }

    #if os(watchOS)
    private func sendWatchEvent(
        _ event: String,
        payload: [String: Any] = [:]
    ) {
        #if canImport(WatchConnectivity)
        guard let session else { return }

        var message = payload
        message["event"] = event
        message["requestID"] = UUID().uuidString
        message["sentAt"] = Date().timeIntervalSince1970
        message[
            MeMoWatchDynamicAssetTransferConstants.watchInstanceIDKey
        ] = MeMoWatchInstallationIdentity.identifier
        message[
            MeMoWatchDynamicAssetTransferConstants.watchBuildKey
        ] = MeMoWatchInstallationIdentity.build

        guard session.activationState == .activated else {
            session.activate()

            if event == "requestSnapshot" || event == "watchHello" {
                try? session.updateApplicationContext(message)
            } else {
                session.transferUserInfo(message)
            }
            return
        }

        if session.isReachable {
            session.sendMessage(
                message,
                replyHandler: nil,
                errorHandler: { _ in
                    if event == "requestSnapshot" || event == "watchHello" {
                        try? session.updateApplicationContext(message)
                    } else {
                        session.transferUserInfo(message)
                    }
                }
            )
        } else if event == "requestSnapshot" || event == "watchHello" {
            try? session.updateApplicationContext(message)
        } else {
            session.transferUserInfo(message)
        }
        #endif
    }
    #endif

    private func apply(_ snapshot: MeMoWatchSnapshot) {
        latestSnapshot = snapshot
        Self.store(snapshot, key: Self.userDefaultsKey)

        #if os(watchOS)
        requestMissingDynamicAssets(for: snapshot)
        #endif
    }

    private func send(
        _ snapshot: MeMoWatchSnapshot,
        forceAssetNames: Set<String> = []
    ) {
        #if os(iOS)
        #if canImport(WatchConnectivity)
        guard let session else { return }
        guard session.activationState == .activated else { return }
        guard let payload = Self.payload(from: snapshot) else { return }

        do {
            try session.updateApplicationContext(payload)
        } catch {
            session.transferUserInfo(payload)
        }

        if session.isReachable {
            session.sendMessage(
                payload,
                replyHandler: nil,
                errorHandler: nil
            )
        }

        proactivelyTransferDynamicAssetsIfNeeded(
            for: snapshot,
            forceAssetNames: forceAssetNames
        )
        #endif
        #endif
    }

    private func handleIncomingOnMainActor(dictionary: [String: Any]) {
        #if os(iOS)
        registerWatchIdentityIfNeeded(from: dictionary)
        #endif

        if let snapshot = Self.snapshot(from: dictionary) {
            apply(snapshot)
            return
        }

        #if os(iOS)
        guard let event = dictionary["event"] as? String else { return }

        if appState == nil {
            enqueuePendingWatchEvent(dictionary)
            return
        }

        if let requestID = dictionary["requestID"] as? String {
            guard markWatchRequestAsProcessedIfNeeded(requestID) else { return }
        }

        switch event {
        case "watchHello":
            forceResendCurrentPresentationAssets()

        case "assetStoredAck":
            guard let assetName = dictionary["assetName"] as? String else { return }
            handleAssetStoredAcknowledgement(assetName: assetName)

        case "pettingTouch":
            guard let appState else { return }
            _ = appState.registerHappinessPettingTouch(count: 1, now: Date())
            persistChangesHandler?()
            publishCurrentSnapshot(backgroundAssetName: nil)

        case "feedFood":
            guard let foodID = dictionary["foodID"] as? String else { return }
            _ = resolveFoodFeedRequest(foodID: foodID)

        case "updateToiletPoopProgress":
            guard let poopID = dictionary["poopID"] as? String else { return }
            let progress: Double
            if let raw = dictionary["progress"] as? Double {
                progress = raw
            } else if let raw = dictionary["progress"] as? NSNumber {
                progress = raw.doubleValue
            } else {
                return
            }
            _ = resolveToiletPoopProgressRequest(
                poopID: poopID,
                progress: progress
            )

        case "requestAssets":
            guard let assetNames = dictionary["assetNames"] as? [String] else {
                return
            }

            let names = Set(Self.uniqueNormalizedAssetNames(assetNames))
            invalidateDeliveryState(for: names)
            _ = sendImmediateDynamicAssetsToWatch(
                assetNames: Array(names),
                force: true
            )
            _ = transferDynamicAssetsToWatch(
                assetNames: Array(names),
                force: true
            )
            scheduleDynamicAssetRetryIfNeeded()

        case "requestSnapshot":
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.refreshLatestStepsAndPublish(backgroundAssetName: nil)
            }

        default:
            break
        }
        #endif
    }

    #if os(watchOS)
    private func handleStoredDynamicAsset(
        assetName: String,
        didStore: Bool
    ) {
        dynamicAssetLastRequestDates.removeValue(forKey: assetName)

        if didStore {
            NotificationCenter.default.post(
                name: Notification.Name("memo.watch.dynamicAssetStored"),
                object: assetName
            )
            sendAssetStoredAcknowledgement(assetName: assetName)
        }

        requestMissingDynamicAssets(for: latestSnapshot)
    }
    #endif

    #if os(iOS)
    private func enqueuePendingWatchEvent(_ dictionary: [String: Any]) {
        if let requestID = dictionary["requestID"] as? String,
           pendingWatchEvents.contains(where: {
               $0["requestID"] as? String == requestID
           }) {
            return
        }

        pendingWatchEvents.append(dictionary)
        if pendingWatchEvents.count > 32 {
            pendingWatchEvents.removeFirst(pendingWatchEvents.count - 32)
        }
    }

    private func flushPendingWatchEventsIfNeeded() {
        guard appState != nil, !pendingWatchEvents.isEmpty else { return }
        let queuedEvents = pendingWatchEvents
        pendingWatchEvents.removeAll()

        for event in queuedEvents {
            handleIncomingOnMainActor(dictionary: event)
        }
    }

    private func markWatchRequestAsProcessedIfNeeded(_ requestID: String) -> Bool {
        guard !processedWatchRequestIDs.contains(requestID) else { return false }

        processedWatchRequestIDs.insert(requestID)
        processedWatchRequestIDOrder.append(requestID)

        if processedWatchRequestIDOrder.count > 128 {
            let overflow = processedWatchRequestIDOrder.count - 128
            let removed = Array(processedWatchRequestIDOrder.prefix(overflow))
            processedWatchRequestIDOrder.removeFirst(overflow)
            for id in removed {
                processedWatchRequestIDs.remove(id)
            }
        }

        return true
    }
    #endif

    private static func initialSnapshot() -> MeMoWatchSnapshot {
        loadStoredSnapshot(key: userDefaultsKey) ?? .placeholder
    }

    private static func payload(
        from snapshot: MeMoWatchSnapshot
    ) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return nil
        }
        return ["snapshotData": data]
    }

    private static func snapshot(
        from dictionary: [String: Any]
    ) -> MeMoWatchSnapshot? {
        guard let data = dictionary["snapshotData"] as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(MeMoWatchSnapshot.self, from: data)
    }

    private static func store(
        _ snapshot: MeMoWatchSnapshot,
        key: String
    ) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadStoredSnapshot(
        key: String
    ) -> MeMoWatchSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(MeMoWatchSnapshot.self, from: data)
    }
}

#if canImport(WatchConnectivity)
extension MeMoWatchConnectivityBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }

        Task { @MainActor in
            #if os(iOS)
            // 再有効化時は配送状態を破棄し、現在のキャラクターと壁紙を強制再送する。
            self.resetDynamicAssetDeliveryState()
            self.publishCurrentSnapshot(
                backgroundAssetName: nil,
                forceDynamicAssetNames: Set(
                    Self.presentationDynamicAssetNames(for: self.latestSnapshot)
                )
            )
            #elseif os(watchOS)
            self.announceWatchIdentity()
            self.requestCurrentSnapshot()
            #endif
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        let assetName = fileTransfer.file.metadata?[
            MeMoWatchDynamicAssetTransferConstants.assetNameMetadataKey
        ] as? String

        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)

        guard let assetName else { return }

        Task { @MainActor in
            // 転送完了は保存成功を意味しない。ACK到着までは未完了のまま再試行する。
            self.inFlightFileDynamicAssetNames.remove(assetName)
            if error != nil {
                self.dynamicAssetLastAttemptDates.removeValue(forKey: assetName)
            }
            self.scheduleDynamicAssetRetryIfNeeded()
        }
    }
    #endif

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            self.handleIncomingOnMainActor(dictionary: applicationContext)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            self.handleIncomingOnMainActor(dictionary: userInfo)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceive file: WCSessionFile
    ) {
        #if os(watchOS)
        guard let assetName = file.metadata?[
            MeMoWatchDynamicAssetTransferConstants.assetNameMetadataKey
        ] as? String else {
            return
        }

        let didStore = MeMoWatchBridgeDynamicAssetDiskStore.storeReceivedFile(
            from: file.fileURL,
            assetName: assetName
        )

        Task { @MainActor in
            self.handleStoredDynamicAsset(
                assetName: assetName,
                didStore: didStore
            )
        }
        #endif
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessageData messageData: Data
    ) {
        #if os(watchOS)
        guard let envelope = try? PropertyListDecoder().decode(
            MeMoWatchImmediateDynamicAssetEnvelope.self,
            from: messageData
        ) else {
            return
        }

        let didStore = MeMoWatchBridgeDynamicAssetDiskStore.storeReceivedData(
            envelope.payload,
            assetName: envelope.assetName
        )

        Task { @MainActor in
            self.handleStoredDynamicAsset(
                assetName: envelope.assetName,
                didStore: didStore
            )
        }
        #endif
    }

    nonisolated func sessionReachabilityDidChange(
        _ session: WCSession
    ) {
        guard session.isReachable else { return }

        Task { @MainActor in
            #if os(iOS)
            self.proactivelyTransferDynamicAssetsIfNeeded(
                for: self.latestSnapshot,
                forceAssetNames: Set(
                    Self.presentationDynamicAssetNames(for: self.latestSnapshot)
                )
            )
            #elseif os(watchOS)
            self.announceWatchIdentity()
            self.requestCurrentSnapshot()
            self.requestMissingDynamicAssets(for: self.latestSnapshot)
            #endif
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            self.handleIncomingOnMainActor(dictionary: message)
        }
    }
}
#endif
