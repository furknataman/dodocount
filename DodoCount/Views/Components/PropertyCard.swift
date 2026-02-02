import SwiftUI

/// Compact property card for grid view - shows key metrics at a glance
struct PropertyCard: View {
    let propertyData: PropertyData
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with property name
            HStack {
                Text(propertyData.property.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                // Live indicator
                Circle()
                    .fill(propertyData.realtime.activeUsers > 0 ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)
            }

            Divider()
                .opacity(0.3)

            // Realtime users - big number
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(propertyData.realtime.activeUsers)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("live")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                    .padding(.bottom, 5)
            }

            // Today's metrics
            VStack(spacing: 4) {
                CompactMetricRow(
                    label: "Users",
                    value: AnalyticsService.formatNumber(propertyData.daily.users.today),
                    change: propertyData.daily.users.percentChange
                )

                CompactMetricRow(
                    label: "Sessions",
                    value: AnalyticsService.formatNumber(propertyData.daily.sessions.today),
                    change: propertyData.daily.sessions.percentChange
                )

                CompactMetricRow(
                    label: "Pageviews",
                    value: AnalyticsService.formatNumber(propertyData.daily.pageviews.today),
                    change: propertyData.daily.pageviews.percentChange
                )
            }

            // Loading/Error state
            if propertyData.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.6)
                    Spacer()
                }
            } else if let error = propertyData.error {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(minWidth: 150, maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(isHovered ? 0.08 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(isHovered ? 0.2 : 0.1), lineWidth: 1)
                )
        )
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

/// Compact metric row for property cards in grid view
struct CompactMetricRow: View {
    let label: String
    let value: String
    let change: Double

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)

            // Change indicator
            HStack(spacing: 2) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 7, weight: .bold))
                Text(String(format: "%.0f%%", abs(change)))
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(change >= 0 ? .green : .red)
            .frame(width: 35, alignment: .trailing)
        }
    }
}

#Preview {
    let mockProperty = GA4Property(id: "123", displayName: "My App", websiteUrl: nil)
    var mockData = PropertyData(property: mockProperty)
    mockData.realtime = RealtimeData(activeUsers: 42, sparklineHistory: [])
    mockData.daily = DailyMetrics(
        users: MetricComparison(today: 1250, yesterday: 1100),
        sessions: MetricComparison(today: 2340, yesterday: 2100),
        pageviews: MetricComparison(today: 5600, yesterday: 5200),
        bounceRate: MetricComparison(today: 45, yesterday: 48),
        avgSessionDuration: MetricComparison(today: 180, yesterday: 165)
    )

    return PropertyCard(propertyData: mockData, onTap: {})
        .frame(width: 180)
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
}
