import SwiftUI

enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case home
    case map
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .map: "Map"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .map: "map"
        case .settings: "gearshape"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .home: "house.fill"
        case .map: "map.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct FullrTabView: View {
    let appViewModel: AppViewModel
    @State private var selectedSection: AppSection = .home

    var body: some View {
        TabView(selection: $selectedSection) {
            NavigationStack {
                HomeView(viewModel: HomeViewModel(offeringService: appViewModel.offeringService))
            }
            .tabItem {
                Label(AppSection.home.title, systemImage: selectedSection == .home ? AppSection.home.selectedSystemImage : AppSection.home.systemImage)
            }
            .tag(AppSection.home)

            NavigationStack {
                MapScreenView(viewModel: MapViewModel(offeringService: appViewModel.offeringService))
            }
            .tabItem {
                Label(AppSection.map.title, systemImage: selectedSection == .map ? AppSection.map.selectedSystemImage : AppSection.map.systemImage)
            }
            .tag(AppSection.map)

            NavigationStack {
                SettingsView(viewModel: SettingsViewModel(user: appViewModel.currentUser)) {
                    Task { await appViewModel.signOut() }
                }
            }
            .tabItem {
                Label(AppSection.settings.title, systemImage: selectedSection == .settings ? AppSection.settings.selectedSystemImage : AppSection.settings.systemImage)
            }
            .tag(AppSection.settings)
        }
        .tint(.green)
    }
}

#Preview { FullrTabView(appViewModel: AppViewModel()) }
