import Foundation

/// Complete data snapshot for a single property (used in grid view)
struct PropertyData: Identifiable {
    let id: String
    let property: GA4Property
    var realtime: RealtimeData
    var daily: DailyMetrics
    var isLoading: Bool
    var error: String?
    var lastUpdated: Date

    init(property: GA4Property) {
        self.id = property.id
        self.property = property
        self.realtime = .empty
        self.daily = .empty
        self.isLoading = false
        self.error = nil
        self.lastUpdated = Date()
    }
}
