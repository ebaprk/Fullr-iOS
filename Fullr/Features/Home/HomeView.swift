import SwiftUI

struct HomeView: View {
    @State var viewModel: HomeViewModel
    @State private var showsFilters = true

    private var featuredOfferings: [FoodOffering] {
        Array(viewModel.offerings.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                searchBar
                if showsFilters {
                    providerCategories
                }
                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.requestLocationIfNeeded()
            await viewModel.loadOfferings()
        }
        .refreshable { await viewModel.loadOfferings() }
        .onChange(of: viewModel.filter.searchText) {
            viewModel.scheduleLoadOfferings()
        }
        .alert("Could not load offerings", isPresented: errorIsPresented) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Available now", systemImage: "takeoutbag.and.cup.and.straw.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Fresh offers from local stores")
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button { showsFilters.toggle() } label: {
                    Image(systemName: showsFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                        .background(.white, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Filters")
            }

            HStack(spacing: 10) {
                InfoPill(title: "Free pickup", systemImage: "takeoutbag.and.cup.and.straw")
                InfoPill(title: "\(viewModel.offerings.count) active", systemImage: "bolt.fill")
            }
        }
        .padding(.top, 18)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search food or providers", text: $viewModel.filter.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.loadOfferings() } }

            if !viewModel.filter.searchText.isEmpty {
                Button {
                    viewModel.filter.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private var providerCategories: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Browse by store", actionTitle: nil)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ProviderCategoryButton(
                        title: "All",
                        systemImage: "square.grid.2x2.fill",
                        isSelected: viewModel.filter.providerType == nil
                    ) {
                        Task { await viewModel.updateProviderType(nil) }
                    }

                    ForEach(ProviderType.allCases) { providerType in
                        ProviderCategoryButton(
                            title: providerType.displayName,
                            systemImage: providerType.systemImageName,
                            isSelected: viewModel.filter.providerType == providerType
                        ) {
                            Task { await viewModel.updateProviderType(providerType) }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        } else if viewModel.offerings.isEmpty {
            ContentUnavailableView(
                "No offerings found",
                systemImage: "tray",
                description: Text("Try widening your filters or checking again soon.")
            )
            .padding(.vertical, 48)
        } else {
            featuredSection
            nearbySection
        }
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Ready soon", actionTitle: nil)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(featuredOfferings) { offering in
                        FeaturedOfferingCard(offering: offering)
                            .frame(width: 280)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "All active offers", actionTitle: nil)

            VStack(spacing: 12) {
                ForEach(viewModel.offerings) { offering in
                    FoodOfferingCard(offering: offering)
                }
            }
        }
    }

    private func sectionHeader(title: String, actionTitle: String?) -> some View {
        HStack {
            Text(title)
                .font(.title3.bold())
            Spacer()
            if let actionTitle {
                Button(actionTitle) { }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

private struct InfoPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white, in: Capsule())
            .foregroundStyle(.secondary)
    }
}

private struct ProviderCategoryButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(width: 46, height: 46)
                    .background(isSelected ? .green : .white, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.primary)
            }
            .frame(width: 74)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(offeringService: MockFoodOfferingService()))
    }
}
