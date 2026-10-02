import Foundation

enum GachaFreeAdSlot: String, CaseIterable, Codable, Identifiable {
    case morning
    case noon
    case evening

    var id: String { rawValue }

    var startHour: Int {
        switch self {
        case .morning: return 5
        case .noon: return 10
        case .evening: return 15
        }
    }

    var title: String {
        switch self {
        case .morning: return "朝"
        case .noon: return "昼"
        case .evening: return "夜"
        }
    }

    var windowText: String {
        switch self {
        case .morning: return "5:00-10:00"
        case .noon: return "10:00-15:00"
        case .evening: return "15:00-23:00"
        }
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        switch self {
        case .morning:
            return (5..<10).contains(hour)
        case .noon:
            return (10..<15).contains(hour)
        case .evening:
            return (15..<23).contains(hour)
        }
    }

    static func current(at date: Date, calendar: Calendar = .current) -> GachaFreeAdSlot? {
        allCases.first { $0.contains(date, calendar: calendar) }
    }
}
