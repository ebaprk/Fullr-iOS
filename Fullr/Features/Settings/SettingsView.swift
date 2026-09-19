import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    let onSignOut: () -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.displayName).font(.headline)
                        Text(viewModel.email).font(.subheadline).foregroundStyle(.secondary)
                        Label(viewModel.schoolName, systemImage: "graduationcap").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Preferences") {
                Toggle("Pickup reminders", isOn: $viewModel.notificationsEnabled)
                Toggle("Student-verified providers only", isOn: $viewModel.showOnlyStudentVerifiedProviders)
            }

            Section("Food rescue") {
                NavigationLink { Text("Saved offerings will live here.").foregroundStyle(.secondary).navigationTitle("Saved") } label: { Label("Saved offerings", systemImage: "bookmark") }
                NavigationLink { Text("Pickup history will live here.").foregroundStyle(.secondary).navigationTitle("History") } label: { Label("Pickup history", systemImage: "clock.arrow.circlepath") }
            }

            Section {
                Button(role: .destructive, action: onSignOut) {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel(user: .preview), onSignOut: { })
    }
}
