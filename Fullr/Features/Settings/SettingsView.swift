import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    let onSignOut: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your little corner")
                        .font(FullrFont.semibold(32, relativeTo: .largeTitle))
                        .tracking(-1)
                    Text("Good things start with you.")
                        .font(FullrFont.regular(15, relativeTo: .subheadline))
                        .foregroundStyle(FullrPalette.moss)
                }
                .padding(.top, 22)

                HStack(alignment: .center, spacing: 16) {
                    Text(String(viewModel.displayName.prefix(1)).uppercased())
                        .font(FullrFont.medium(30, relativeTo: .title))
                        .frame(width: 64, height: 64)
                        .foregroundStyle(FullrPalette.cream)
                        .background(FullrPalette.moss, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(viewModel.displayName)
                            .font(FullrFont.semibold(21, relativeTo: .title3))
                        Text(viewModel.email)
                            .font(FullrFont.regular(13, relativeTo: .subheadline))
                            .foregroundStyle(FullrPalette.moss)
                        Label(viewModel.schoolName, systemImage: "graduationcap")
                            .font(FullrFont.regular(12, relativeTo: .caption))
                            .foregroundStyle(FullrPalette.moss)
                    }
                    .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(FullrPalette.olive, lineWidth: 1) }

                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("Make it yours")
                    Toggle(isOn: $viewModel.notificationsEnabled) {
                        preferenceLabel("Pickup reminders", subtitle: "A little nudge before it’s time.", symbol: "bell")
                    }
                    .padding(.vertical, 12)
                    separator
                    Toggle(isOn: $viewModel.showOnlyStudentVerifiedProviders) {
                        preferenceLabel("Student-verified providers", subtitle: "Show verified providers only.", symbol: "checkmark.seal")
                    }
                    .padding(.vertical, 12)
                }
                .toggleStyle(FullrToggleStyle())

                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("Your food finds")
                    NavigationLink {
                        collectionPlaceholder(title: "Saved offerings", message: "Your saved food finds will feel right at home here.", systemImage: "bookmark")
                    } label: {
                        navigationRow("Saved offerings", symbol: "bookmark")
                    }
                    separator
                    NavigationLink {
                        collectionPlaceholder(title: "Pickup history", message: "A little record of the good food you’ve rescued will live here.", systemImage: "clock.arrow.circlepath")
                    } label: {
                        navigationRow("Pickup history", symbol: "clock.arrow.circlepath")
                    }
                }
                .buttonStyle(FullrPressStyle())

                Button(action: onSignOut) {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(FullrFont.medium(15))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .overlay { Capsule().strokeBorder(FullrPalette.olive, lineWidth: 1) }
                }
                .buttonStyle(FullrPressStyle())
                .foregroundStyle(FullrPalette.moss)

                HStack(spacing: 6) {
                    Image(systemName: "leaf")
                    Text("A fuller plate. A lighter footprint.")
                }
                .font(FullrFont.regular(12, relativeTo: .caption))
                .foregroundStyle(FullrPalette.moss)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(FullrPalette.cream)
        .foregroundStyle(FullrPalette.pine)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var separator: some View {
        Rectangle().fill(FullrPalette.olive).frame(height: 0.5)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(FullrFont.semibold(20, relativeTo: .title3))
            .tracking(-0.3)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }

    private func preferenceLabel(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(FullrFont.regular(19))
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(FullrFont.medium(15))
                Text(subtitle)
                    .font(FullrFont.regular(12, relativeTo: .caption))
                    .foregroundStyle(FullrPalette.moss)
            }
        }
    }

    private func navigationRow(_ title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(FullrFont.regular(19))
                .frame(width: 24)
            Text(title).font(FullrFont.medium(15))
            Spacer()
            Image(systemName: "chevron.right")
                .font(FullrFont.medium(12))
        }
        .foregroundStyle(FullrPalette.moss)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }

    private func collectionPlaceholder(title: String, message: String, systemImage: String) -> some View {
        FullrEmptyState(title: title, message: message, systemImage: systemImage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(FullrPalette.cream)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(FullrPalette.cream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel(user: .preview), onSignOut: { })
    }
}
