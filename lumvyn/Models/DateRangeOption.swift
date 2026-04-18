import Foundation

enum DateRangeType: String, Codable, CaseIterable, Equatable, Identifiable {
    case allTime
    case last24Hours
    case last7Days
    case last30Days
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .allTime: return NSLocalizedString("Gesamter Zeitraum", comment: "Date range: all time")
        case .last24Hours: return NSLocalizedString("Letzte 24 Stunden", comment: "Date range: last 24 hours")
        case .last7Days: return NSLocalizedString("Letzte 7 Tage", comment: "Date range: last 7 days")
        case .last30Days: return NSLocalizedString("Letzte 30 Tage", comment: "Date range: last 30 days")
        case .custom: return NSLocalizedString("Benutzerdefiniert", comment: "Date range: custom")
        }
    }
}

struct DateRangeOption: Codable, Equatable {
    var type: DateRangeType = .allTime
    var startDate: Date? = nil
    var endDate: Date? = nil

    var computedStartDate: Date? {
        switch type {
        case .allTime:
            return nil
        case .last24Hours:
            return Calendar.current.date(byAdding: .day, value: -1, to: Date())
        case .last7Days:
            return Calendar.current.date(byAdding: .day, value: -7, to: Date())
        case .last30Days:
            return Calendar.current.date(byAdding: .day, value: -30, to: Date())
        case .custom:
            return startDate
        }
    }

    var computedEndDate: Date? {
        switch type {
        case .custom:
            return endDate
        default:
            return Date()
        }
    }

    var isValid: Bool {
        guard type == .custom else { return true }
        guard let startDate, let endDate else { return false }
        return startDate <= endDate
    }

    func matches(_ date: Date) -> Bool {
        if let start = computedStartDate, date < start { return false }
        if let end = computedEndDate, date > end { return false }
        return true
    }
}
