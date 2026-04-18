import Foundation

struct DayGroup: Identifiable, Hashable {
    let id: Date
    let date: Date
    let assets: [RemoteAsset]
    var count: Int { assets.count }
    var cover: RemoteAsset? { assets.first }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func ==(lhs: DayGroup, rhs: DayGroup) -> Bool {
        lhs.id == rhs.id
    }
}

struct MonthGroup: Identifiable, Hashable {
    let id: Date
    let monthStart: Date
    let assets: [RemoteAsset]
    var count: Int { assets.count }
    var cover: RemoteAsset? { assets.first }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func ==(lhs: MonthGroup, rhs: MonthGroup) -> Bool {
        lhs.id == rhs.id
    }
}

struct YearGroup: Identifiable, Hashable {
    let id: Int
    let year: Int
    let assets: [RemoteAsset]
    var count: Int { assets.count }
    var cover: RemoteAsset? { assets.first }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func ==(lhs: YearGroup, rhs: YearGroup) -> Bool {
        lhs.id == rhs.id
    }
}

enum PhotoGrouper {
    static func groupByDay(_ assets: [RemoteAsset], calendar: Calendar = .current) -> [DayGroup] {
        let buckets = Dictionary(grouping: assets) { calendar.startOfDay(for: $0.modifiedAt) }
        return buckets
            .map { DayGroup(id: $0.key, date: $0.key, assets: $0.value.sorted { $0.modifiedAt > $1.modifiedAt }) }
            .sorted { $0.date > $1.date }
    }

    static func groupByMonth(_ assets: [RemoteAsset], calendar: Calendar = .current) -> [MonthGroup] {
        let buckets = Dictionary(grouping: assets) { asset -> Date in
            let comps = calendar.dateComponents([.year, .month], from: asset.modifiedAt)
            return calendar.date(from: comps) ?? asset.modifiedAt
        }
        return buckets
            .map { MonthGroup(id: $0.key, monthStart: $0.key, assets: $0.value.sorted { $0.modifiedAt > $1.modifiedAt }) }
            .sorted { $0.monthStart > $1.monthStart }
    }

    static func groupByYear(_ assets: [RemoteAsset], calendar: Calendar = .current) -> [YearGroup] {
        let buckets = Dictionary(grouping: assets) { calendar.component(.year, from: $0.modifiedAt) }
        return buckets
            .map { YearGroup(id: $0.key, year: $0.key, assets: $0.value.sorted { $0.modifiedAt > $1.modifiedAt }) }
            .sorted { $0.year > $1.year }
    }

    static func recentDays(_ assets: [RemoteAsset], limit: Int = 7, calendar: Calendar = .current) -> [DayGroup] {
        Array(groupByDay(assets, calendar: calendar).prefix(limit))
    }
}
