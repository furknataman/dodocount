import SwiftUI

/// Main popover view that switches between single property and grid view
struct MainPopoverView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared

    var body: some View {
        Group {
            if settingsManager.settings.useGridView {
                PropertyGridView()
            } else {
                MenuBarView()
            }
        }
    }
}

#Preview {
    MainPopoverView()
}
