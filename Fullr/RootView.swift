//
//  RootView.swift
//  Fullr
//
//  Created by Abe and Jonathan on 9/18/26.
//

import SwiftUI

struct RootView: View {
    @State private var appViewModel = AppViewModel()

    var body: some View {
        Group {
            if appViewModel.isRestoringSession {
                ProgressView("Finding your place…")
                    .font(FullrFont.regular(16))
                    .tint(FullrPalette.moss)
                    .foregroundStyle(FullrPalette.moss)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(FullrPalette.cream)
            } else if appViewModel.isAuthenticated {
                FullrTabView(appViewModel: appViewModel)
            } else {
                LoginView(appViewModel: appViewModel)
            }
        }
        .task {
            await appViewModel.restoreSession()
        }
        .onOpenURL { url in
            Task {
                await appViewModel.handleAuthCallback(url)
            }
        }
    }
}

#Preview {
    LoginView(appViewModel: AppViewModel(authService: MockAuthService()))
}
