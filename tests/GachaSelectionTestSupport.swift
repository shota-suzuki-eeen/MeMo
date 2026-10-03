import Foundation

// Dependency shells compile the actual Gacha owner without using the real
// app's UserDefaults, SwiftData store or Simulator. iOS/UI checks remain separate.
final class UserDefaults {
    static let standard = UserDefaults()
    var values: [String: Any] = [:]
    var writes: [String: Int] = [:]
    func object(forKey key: String) -> Any? { values[key] }
    func integer(forKey key: String) -> Int { (values[key] as? NSNumber)?.intValue ?? 0 }
    func bool(forKey key: String) -> Bool { (values[key] as? NSNumber)?.boolValue ?? false }
    func string(forKey key: String) -> String? { values[key] as? String }
    func stringArray(forKey key: String) -> [String]? { values[key] as? [String] }
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func set(_ value: Any?, forKey key: String) {
        values[key] = value
        writes[key, default: 0] += 1
    }
    func roundTrip(at url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
        try data.write(to: url)
        values = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), options: [], format: nil) as! [String: Any]
    }
}

final class AppState {
    var walletSteps = 10000
    func ensureDailyResetIfNeeded(now: Date) {}
    static func makeDayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
