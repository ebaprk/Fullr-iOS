import SwiftUI

struct LoginView: View {
    let appViewModel: AppViewModel
    @State private var viewModel = LoginViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        FullrWordmark(size: 38)
                        Spacer()
                        Image(systemName: "leaf.circle")
                            .font(FullrFont.regular(32))
                            .foregroundStyle(FullrPalette.moss)
                            .accessibilityHidden(true)
                    }
                    .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(viewModel.didSendConfirmationLink ? "Check your inbox." : "Good food.\nBetter together.")
                            .font(FullrFont.medium(42, relativeTo: .largeTitle))
                            .tracking(-1.5)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(viewModel.didSendConfirmationLink ? "One little step, then you’re part of something good." : "Find surplus food nearby and give something good a second chance.")
                            .font(FullrFont.regular(16))
                            .foregroundStyle(FullrPalette.moss)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HomeLandscape(scrollOffset: 0)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 18) {
                        Text(viewModel.didSendConfirmationLink ? "You’re almost there" : viewModel.isCreatingAccount ? "Make yourself at home" : "Welcome back")
                            .font(FullrFont.semibold(24, relativeTo: .title2))
                            .tracking(-0.5)

                        if viewModel.isCreatingAccount && !viewModel.didSendConfirmationLink {
                            field(title: "Your name", systemImage: "person") {
                                TextField("Name", text: $viewModel.name, prompt: Text("Alex Green").foregroundStyle(FullrPalette.moss))
                                    .textContentType(.name)
                                    .textInputAutocapitalization(.words)
                            }
                        }

                        if viewModel.didSendConfirmationLink {
                            Text("We sent a confirmation link to \(viewModel.email). Open it from your email, then come back and log in.")
                                .font(FullrFont.regular(15))
                                .foregroundStyle(FullrPalette.moss)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            field(title: "School email", systemImage: "envelope") {
                                TextField("School email", text: $viewModel.email, prompt: Text(verbatim: "you@school.edu").foregroundStyle(FullrPalette.moss))
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            field(title: "Password", systemImage: "lock") {
                                SecureField("Password", text: $viewModel.password, prompt: Text("Your password").foregroundStyle(FullrPalette.moss))
                                    .textContentType(viewModel.isCreatingAccount ? .newPassword : .password)
                            }
                        }
                    }

                    if let message = appViewModel.authErrorMessage {
                        Label(message, systemImage: "exclamationmark.circle")
                            .font(FullrFont.regular(14, relativeTo: .footnote))
                            .foregroundStyle(FullrPalette.moss)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 12) {
                        if !viewModel.didSendConfirmationLink {
                            Button(action: authenticate) {
                                HStack {
                                    Spacer()
                                    if appViewModel.isAuthenticating {
                                        ProgressView().tint(FullrPalette.cream)
                                    } else {
                                        Text(viewModel.primaryButtonTitle)
                                        Image(systemName: "arrow.up.right")
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(FullrPrimaryButtonStyle())
                            .disabled(appViewModel.isAuthenticating)
                        }

                        Button {
                            withAnimation(reduceMotion ? nil : .snappy) {
                                if viewModel.didSendConfirmationLink {
                                    viewModel.resetConfirmation()
                                } else {
                                    viewModel.isCreatingAccount.toggle()
                                }
                            }
                        } label: {
                            Text(viewModel.toggleButtonTitle)
                                .font(FullrFont.medium(14, relativeTo: .subheadline))
                                .foregroundStyle(FullrPalette.moss)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(FullrPressStyle())
                        .disabled(appViewModel.isAuthenticating)
                    }
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(FullrPalette.cream)
            .foregroundStyle(FullrPalette.pine)
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(FullrPalette.moss)
    }

    private func field<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FullrFont.medium(13, relativeTo: .caption))
                .foregroundStyle(FullrPalette.moss)
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(FullrPalette.moss)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                content()
                    .font(FullrFont.regular(16))
            }
            .padding(17)
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(FullrPalette.olive, lineWidth: 1) }
        }
    }

    private func authenticate() {
        Task {
            if viewModel.isCreatingAccount {
                let didSendLink = await appViewModel.signUp(name: viewModel.name, email: viewModel.email, password: viewModel.password)
                if didSendLink {
                    withAnimation(reduceMotion ? nil : .snappy) { viewModel.didSendConfirmationLink = true }
                }
            } else {
                await appViewModel.signIn(email: viewModel.email, password: viewModel.password)
            }
        }
    }
}

#Preview { LoginView(appViewModel: AppViewModel(authService: MockAuthService())) }
