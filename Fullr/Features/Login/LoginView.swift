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
                    if viewModel.isCreatingAccount && !viewModel.didSendConfirmationLink {
                        TextField("Name", text: $viewModel.name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .textFieldStyle(.roundedBorder)
                    }
                    if viewModel.didSendConfirmationLink {
                        Text("We sent a confirmation link to \(viewModel.email). Open it from your email, then come back and log in.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        TextField("School Email (.edu)", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(viewModel.isCreatingAccount ? .newPassword : .password)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                if let message = appViewModel.authErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task {
                        if viewModel.isCreatingAccount && !viewModel.didSendConfirmationLink {
                            let didSendLink = await appViewModel.signUp(name: viewModel.name, email: viewModel.email, password: viewModel.password)
                            if didSendLink {
                                withAnimation(.snappy) { viewModel.didSendConfirmationLink = true }
                            }
                        } else if !viewModel.didSendConfirmationLink {
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
                .disabled(appViewModel.isAuthenticating || viewModel.didSendConfirmationLink)

                Button {
                    withAnimation(.snappy) {
                        if viewModel.didSendConfirmationLink {
                            viewModel.resetConfirmation()
                        } else {
                            viewModel.isCreatingAccount.toggle()
                        }
                    }
                } label: {
                    Text(viewModel.toggleButtonTitle)
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

#Preview { LoginView(appViewModel: AppViewModel(authService: MockAuthService())) }
