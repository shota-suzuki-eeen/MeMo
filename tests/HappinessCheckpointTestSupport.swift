import Foundation

// Dependency shells for the production AppState extensions. No test process
// writes the real app's UserDefaults or SwiftData. Actual persistence is checked
// separately in the isolated iOS QA app.
final class UserDefaults {
    static let standard = UserDefaults()
    var values: [String: Any] = [:]

    func object(forKey key: String) -> Any? { values[key] }
    func integer(forKey key: String) -> Int { (values[key] as? NSNumber)?.intValue ?? 0 }
    func bool(forKey key: String) -> Bool { (values[key] as? NSNumber)?.boolValue ?? false }
    func string(forKey key: String) -> String? { values[key] as? String }
    func stringArray(forKey key: String) -> [String]? { values[key] as? [String] }
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }

    func roundTrip(at url: URL) throws {
        let bytes = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
        try bytes.write(to: url)
        values = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), options: [], format: nil) as! [String: Any]
    }
}

final class AppState {
    var currentPetID = "pet_000"
    var normalizedCurrentPetID: String { currentPetID }
    var walletSteps = 12345
    private var pets = ["pet_000", "reward_000"]
    func ownedPetIDs() -> [String] { pets }
    func setOwnedPetIDs(_ value: [String]) { pets = value }
    func ensureDailyResetIfNeeded(now: Date) {}
    static func makeDayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
