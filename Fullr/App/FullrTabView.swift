import SwiftUI

enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case home, map, stats, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Discover"
        case .map: "Map"
        case .stats: "Stats"
        case .settings: "You"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "leaf"
        case .map: "map"
        case .stats: "chart.bar"
        case .settings: "person.crop.circle"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .home: "leaf.fill"
        case .map: "map.fill"
        case .stats: "chart.bar.fill"
        case .settings: "person.crop.circle.fill"
        }
    }
}

struct FullrTabView: View {
    let appViewModel: AppViewModel
    @State private var selectedSection: AppSection = .home
    @State private var homeViewModel: HomeViewModel
    @State private var mapViewModel: MapViewModel
    @State private var settingsViewModel: SettingsViewModel

    init(appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
        let settingsViewModel = SettingsViewModel(user: appViewModel.currentUser)
        let homeViewModel = HomeViewModel(offeringService: appViewModel.offeringService)
        let mapViewModel = MapViewModel(offeringService: appViewModel.offeringService)
        homeViewModel.filter.showOnlyStudentVerifiedProviders = settingsViewModel.showOnlyStudentVerifiedProviders
        mapViewModel.showOnlyStudentVerifiedProviders = settingsViewModel.showOnlyStudentVerifiedProviders
        _settingsViewModel = State(initialValue: settingsViewModel)
        _homeViewModel = State(initialValue: homeViewModel)
        _mapViewModel = State(initialValue: mapViewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedSection) {
                NavigationStack {
                    HomeView(viewModel: homeViewModel)
                }
                .tag(AppSection.home)
                .toolbar(.hidden, for: .tabBar)

                NavigationStack {
                    MapScreenView(viewModel: mapViewModel)
                }
                .tag(AppSection.map)
                .toolbar(.hidden, for: .tabBar)

                NavigationStack {
                    RestaurantStatsView(service: appViewModel.statsService)
                }
                .tag(AppSection.stats)
                .toolbar(.hidden, for: .tabBar)

                NavigationStack {
                    SettingsView(viewModel: settingsViewModel, offeringService: appViewModel.offeringService) {
                        Task { await appViewModel.signOut() }
                    }
                }
                .tag(AppSection.settings)
                .toolbar(.hidden, for: .tabBar)
            }
            navigationBar.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .font(FullrFont.regular(16))
        .tint(FullrPalette.moss)
        .background(FullrPalette.cream)
        .onChange(of: settingsViewModel.showOnlyStudentVerifiedProviders) { _, showOnlyVerifiedProviders in
            Task {
                await homeViewModel.updateStudentVerifiedProviders(showOnlyVerifiedProviders)
                await mapViewModel.updateStudentVerifiedProviders(showOnlyVerifiedProviders)
            }
        }
    }

    @ViewBuilder
    private func tabIcon(for section: AppSection) -> some View {
        if section == .home {
            Image("logo")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: selectedSection == section ? section.selectedSystemImage : section.systemImage)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 8) {
            ForEach(AppSection.allCases) { section in
                Button { selectedSection = section } label: {
                    VStack(spacing: 6) {
                        tabIcon(for: section)
                            .font(FullrFont.medium(18))
                        Text(section.title)
                            .font(FullrFont.medium(13, relativeTo: .caption))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(selectedSection == section ? FullrPalette.cream : FullrPalette.moss)
                    .background(selectedSection == section ? FullrPalette.moss : FullrPalette.cream, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(FullrPressStyle())
                .accessibilityLabel(section == .settings ? "Your settings" : section.title)
                .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
            }
        }
        .frame(maxWidth: 680)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(FullrPalette.cream)
        .overlay(alignment: .top) { Rectangle().fill(FullrPalette.olive).frame(height: 0.5) }
    }
}

#Preview {
    FullrTabView(appViewModel: AppViewModel(authService: MockAuthService(), offeringService: MockFoodOfferingService(), statsService: MockRestaurantStatsService()))
}
