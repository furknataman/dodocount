import Foundation
import Combine

/// Service to manage analytics data for multiple properties simultaneously
class MultiPropertyService: ObservableObject {
    static let shared = MultiPropertyService()

    @Published var propertyDataList: [PropertyData] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date = Date()

    private var refreshTimer: Timer?
    private var authObserver: NSObjectProtocol?

    // GA4 API endpoint
    private let dataAPIBase = "https://analyticsdata.googleapis.com/v1beta"

    private init() {
        observeAuthChanges()

        // Initial load after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if GoogleAuthService.shared.isAuthenticated {
                Task {
                    await self?.loadAllProperties()
                }
            }
        }
    }

    private func observeAuthChanges() {
        authObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("GoogleAuthStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if GoogleAuthService.shared.isAuthenticated {
                Task {
                    await self?.loadAllProperties()
                }
            } else {
                self?.propertyDataList = []
            }
        }
    }

    deinit {
        if let observer = authObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stopRefreshTimer()
    }

    // MARK: - Public Methods

    @MainActor
    func loadAllProperties() async {
        guard !isLoading else { return }
        isLoading = true

        // Get properties from AnalyticsService
        var properties = AnalyticsService.shared.properties

        // Wait for properties to be loaded (max 5 retries)
        var retries = 0
        while properties.isEmpty && retries < 5 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            properties = AnalyticsService.shared.properties
            retries += 1
        }

        if properties.isEmpty {
            isLoading = false
            return
        }

        // Initialize property data list if empty
        if propertyDataList.isEmpty {
            propertyDataList = properties.map { PropertyData(property: $0) }
        }

        // Fetch data for all properties in parallel
        await withTaskGroup(of: (String, RealtimeData?, DailyMetrics?, String?).self) { group in
            for property in properties {
                group.addTask { [weak self] in
                    do {
                        async let realtimeTask = self?.fetchRealtimeData(propertyId: property.id)
                        async let dailyTask = self?.fetchDailyMetrics(propertyId: property.id)

                        let (realtime, daily) = try await (realtimeTask, dailyTask)
                        return (property.id, realtime, daily, nil)
                    } catch {
                        return (property.id, nil, nil, error.localizedDescription)
                    }
                }
            }

            for await (propertyId, realtime, daily, error) in group {
                if let index = propertyDataList.firstIndex(where: { $0.id == propertyId }) {
                    if let realtime = realtime {
                        propertyDataList[index].realtime = realtime
                    }
                    if let daily = daily {
                        propertyDataList[index].daily = daily
                    }
                    propertyDataList[index].error = error
                    propertyDataList[index].lastUpdated = Date()
                    propertyDataList[index].isLoading = false
                }
            }
        }

        lastUpdated = Date()
        isLoading = false
    }

    func refreshData() {
        guard !isLoading else { return }

        if GoogleAuthService.shared.isAuthenticated {
            Task { @MainActor in
                await refreshAllPropertyData()
            }
        }
    }

    @MainActor
    private func refreshAllPropertyData() async {
        guard !isLoading else { return }
        guard !propertyDataList.isEmpty else {
            await loadAllProperties()
            return
        }

        isLoading = true

        // Fetch data for all existing properties in parallel
        await withTaskGroup(of: (String, RealtimeData?, DailyMetrics?, String?).self) { group in
            for propertyData in propertyDataList {
                group.addTask { [weak self] in
                    do {
                        async let realtimeTask = self?.fetchRealtimeData(propertyId: propertyData.property.id)
                        async let dailyTask = self?.fetchDailyMetrics(propertyId: propertyData.property.id)

                        let (realtime, daily) = try await (realtimeTask, dailyTask)
                        return (propertyData.property.id, realtime, daily, nil)
                    } catch {
                        return (propertyData.property.id, nil, nil, error.localizedDescription)
                    }
                }
            }

            for await (propertyId, realtime, daily, error) in group {
                if let index = propertyDataList.firstIndex(where: { $0.id == propertyId }) {
                    if let realtime = realtime {
                        propertyDataList[index].realtime = realtime
                    }
                    if let daily = daily {
                        propertyDataList[index].daily = daily
                    }
                    propertyDataList[index].error = error
                    propertyDataList[index].lastUpdated = Date()
                }
            }
        }

        lastUpdated = Date()
        isLoading = false
    }

    // MARK: - API Methods

    private func fetchRealtimeData(propertyId: String) async throws -> RealtimeData {
        let token = try await GoogleAuthService.shared.getValidAccessToken()

        guard let url = URL(string: "\(dataAPIBase)/\(propertyId):runRealtimeReport") else {
            throw AnalyticsError.apiError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "metrics": [["name": "activeUsers"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AnalyticsError.apiError("Failed to fetch realtime data")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let rows = json?["rows"] as? [[String: Any]] ?? []
        let activeUsers = rows.first?["metricValues"] as? [[String: Any]]
        let value = activeUsers?.first?["value"] as? String ?? "0"

        return RealtimeData(activeUsers: Int(value) ?? 0, sparklineHistory: [])
    }

    private func fetchDailyMetrics(propertyId: String) async throws -> DailyMetrics {
        let token = try await GoogleAuthService.shared.getValidAccessToken()

        guard let url = URL(string: "\(dataAPIBase)/\(propertyId):runReport") else {
            throw AnalyticsError.apiError("Invalid URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "dateRanges": [
                ["startDate": "yesterday", "endDate": "yesterday"],
                ["startDate": "today", "endDate": "today"]
            ],
            "metrics": [
                ["name": "activeUsers"],
                ["name": "sessions"],
                ["name": "screenPageViews"],
                ["name": "bounceRate"],
                ["name": "averageSessionDuration"]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AnalyticsError.apiError("Failed to fetch daily metrics")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let rows = json?["rows"] as? [[String: Any]] ?? []

        var yesterday: [Double] = [0, 0, 0, 0, 0]
        var today: [Double] = [0, 0, 0, 0, 0]

        for row in rows {
            let dimensionValues = row["dimensionValues"] as? [[String: Any]] ?? []
            let dateRangeIndex = dimensionValues.first?["value"] as? String ?? "0"
            let metricValues = row["metricValues"] as? [[String: Any]] ?? []

            let values = metricValues.compactMap { ($0["value"] as? String).flatMap { Double($0) } }

            if dateRangeIndex == "date_range_0" {
                yesterday = values
            } else {
                today = values
            }
        }

        return DailyMetrics(
            users: MetricComparison(today: today[safe: 0] ?? 0, yesterday: yesterday[safe: 0] ?? 0),
            sessions: MetricComparison(today: today[safe: 1] ?? 0, yesterday: yesterday[safe: 1] ?? 0),
            pageviews: MetricComparison(today: today[safe: 2] ?? 0, yesterday: yesterday[safe: 2] ?? 0),
            bounceRate: MetricComparison(today: (today[safe: 3] ?? 0) * 100, yesterday: (yesterday[safe: 3] ?? 0) * 100),
            avgSessionDuration: MetricComparison(today: today[safe: 4] ?? 0, yesterday: yesterday[safe: 4] ?? 0)
        )
    }

    // MARK: - Timer

    func startRefreshTimer() {
        stopRefreshTimer()

        let interval = SettingsManager.shared.settings.refreshInterval.seconds
        DispatchQueue.main.async { [weak self] in
            self?.refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                if GoogleAuthService.shared.isAuthenticated {
                    self?.refreshData()
                }
            }
            RunLoop.main.add(self!.refreshTimer!, forMode: .common)
        }
    }

    func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
