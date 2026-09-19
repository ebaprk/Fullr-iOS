import SwiftUI

struct LoginView: View {
    let appViewModel: AppViewModel
    @State private var viewModel = LoginViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                    .background(alignment: .top) {
                        FullrPalette.cream
                            .frame(height: 320)
                            .offset(y: -220)
                    }

                VStack(alignment: .leading, spacing: 22) {
                    intro
                    form
                    errorMessage
                    primaryButton
                    toggleButton
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .background(FullrPalette.moss)
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.all, edges: .all)
    }

    private var header: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let controlTopPadding = max(topInset + 22, 96)

            ZStack(alignment: .top) {
                FullrPalette.cream

                VStack(spacing: 0) {
                    Spacer(minLength: topInset + 92)
                    LoginLandscape()
                        .frame(height: 150)
                }

                HStack(spacing: 8) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 43, weight: .black))

                    Text("FULLR")
                        .font(.system(size: 39, weight: .heavy, design: .serif))
                }
                .foregroundStyle(FullrPalette.pine)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, controlTopPadding)
            }
        }
        .frame(height: 286)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.isCreatingAccount ? "Join Fullr" : "Welcome back")
                .font(.title.bold())
                .foregroundStyle(FullrPalette.cream)

            Text("Find nearby surplus food from restaurants, pantries, businesses, and campus partners.")
                .font(.subheadline)
                .foregroundStyle(FullrPalette.cream.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.didSendConfirmationLink {
                confirmationNotice
            } else {
                if viewModel.isCreatingAccount {
                    LoginField(systemImage: "person.fill") {
                        TextField("Name", text: $viewModel.name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                    }
                }

                LoginField(systemImage: "envelope.fill") {
                    TextField("School Email (.edu)", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                LoginField(systemImage: "lock.fill") {
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(viewModel.isCreatingAccount ? .newPassword : .password)
                }
            }
        }
    }

    private var confirmationNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "envelope.badge.fill")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(FullrPalette.gold, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(FullrPalette.pine)

            Text("We sent a confirmation link to \(viewModel.email). Open it from your email, then come back and log in.")
                .font(.footnote)
                .foregroundStyle(FullrPalette.pine)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(FullrPalette.cream, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let message = appViewModel.authErrorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FullrPalette.cream)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var primaryButton: some View {
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
            Group {
                if appViewModel.isAuthenticating {
                    ProgressView()
                        .tint(FullrPalette.pine)
                } else {
                    Text(viewModel.primaryButtonTitle)
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .foregroundStyle(FullrPalette.pine)
            .background(FullrPalette.gold, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(appViewModel.isAuthenticating || viewModel.didSendConfirmationLink)
        .opacity(viewModel.didSendConfirmationLink ? 0.6 : 1)
    }

    private var toggleButton: some View {
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FullrPalette.gold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct LoginField<Content: View>: View {
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(FullrPalette.moss)
                .frame(width: 20)

            content
                .foregroundStyle(FullrPalette.pine)
                .tint(FullrPalette.moss)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(FullrPalette.cream, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct LoginLandscape: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            FullrPalette.cream

            UnevenRoundedRectangle(topLeadingRadius: 160, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 80)
                .fill(FullrPalette.olive)
                .frame(height: 110)
                .offset(x: 118, y: 4)

            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 180)
                .fill(FullrPalette.ink)
                .frame(height: 102)
                .offset(x: -82, y: 28)

            UnevenRoundedRectangle(topLeadingRadius: 120, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 12)
                .fill(FullrPalette.pine)
                .frame(height: 76)
                .offset(x: 116, y: 42)

            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 130)
                .fill(FullrPalette.moss)
                .frame(height: 72)
                .offset(x: -104, y: 56)
        }
        .clipped()
    }
}

#Preview { LoginView(appViewModel: AppViewModel(authService: MockAuthService())) }
