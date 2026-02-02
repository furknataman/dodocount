import SwiftUI

/// Grid view showing all properties at once
struct PropertyGridView: View {
    @ObservedObject private var multiPropertyService = MultiPropertyService.shared
    @ObservedObject private var analyticsService = AnalyticsService.shared
    @ObservedObject private var settingsManager = SettingsManager.shared

    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 10)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                headerSection

                // Grid of property cards
                if multiPropertyService.propertyDataList.isEmpty && multiPropertyService.isLoading {
                    loadingView
                } else if multiPropertyService.propertyDataList.isEmpty {
                    emptyView
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(multiPropertyService.propertyDataList) { propertyData in
                            PropertyCard(propertyData: propertyData) {
                                // Switch to single view for this property
                                if let property = analyticsService.properties.first(where: { $0.id == propertyData.id }) {
                                    analyticsService.selectProperty(property)
                                    settingsManager.settings.useGridView = false
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                }

                // Footer
                footerSection
                    .padding(.top, 12)
            }
            .padding(.bottom, 8)
        }
        .frame(width: 380, height: 520)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
                Color.black.opacity(0.3)
            }
        )
        .preferredColorScheme(.dark)
        .onAppear {
            multiPropertyService.startRefreshTimer()
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 10) {
            // App icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .blur(radius: 4)

                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("All Properties")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text("\(multiPropertyService.propertyDataList.count) apps")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Single view toggle
            HeaderButton(icon: "rectangle.portrait", tooltip: "Single View") {
                settingsManager.settings.useGridView = false
            }

            // Refresh button
            HeaderButton(icon: "arrow.clockwise", tooltip: "Refresh") {
                multiPropertyService.refreshData()
            }

            // Settings button
            HeaderButton(icon: "gearshape", tooltip: "Settings") {
                openSettings()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Footer
    private var footerSection: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text("Updated \(DateUtilities.timeAgo(multiPropertyService.lastUpdated))")
                    .font(.system(size: 10))
            }
            .foregroundColor(.secondary.opacity(0.7))

            Spacer()

            // Total live users
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("\(totalLiveUsers) live total")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
            }

            if multiPropertyService.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Empty/Loading Views
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading properties...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No properties found")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text("Sign in to see your GA4 properties")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Computed
    private var totalLiveUsers: Int {
        multiPropertyService.propertyDataList.reduce(0) { $0 + $1.realtime.activeUsers }
    }

    // MARK: - Actions
    private func openSettings() {
        NSApp.sendAction(#selector(AppDelegate.openSettingsWindow), to: nil, from: nil)
    }
}

#Preview {
    PropertyGridView()
}
