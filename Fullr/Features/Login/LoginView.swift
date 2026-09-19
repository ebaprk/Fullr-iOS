import SwiftUI

struct LoginView: View {
    let appViewModel: AppViewModel
    @State private var viewModel = LoginViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green)
                    Text("Fullr")
                        .font(.largeTitle.bold())
                    Text("Find nearby surplus food from restaurants, pantries, businesses, and campus partners.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 14) {
                    if viewModel.isCreatingAccount {
                        TextField("Name", text: $viewModel.name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(viewModel.isCreatingAccount ? .newPassword : .password)
                        .textFieldStyle(.roundedBorder)
                }

                if let message = appViewModel.authErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task {
                        if viewModel.isCreatingAccount {
                            await appViewModel.signUp(name: viewModel.name, email: viewModel.email, password: viewModel.password)
                        } else {
                            await appViewModel.signIn(email: viewModel.email, password: viewModel.password)
                        }
                    }
                } label: {
                    if appViewModel.isAuthenticating {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(viewModel.primaryButtonTitle).frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(appViewModel.isAuthenticating)

                Button {
                    withAnimation(.snappy) { viewModel.isCreatingAccount.toggle() }
                } label: {
                    Text(viewModel.isCreatingAccount ? "Already have an account? Log in" : "New here? Create an account")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.green)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Welcome")
        }
    }
}

#Preview { LoginView(appViewModel: AppViewModel()) }
