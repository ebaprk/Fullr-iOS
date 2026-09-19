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
                ProgressView()
            } else if appViewModel.isAuthenticated {
                FullrTabView(appViewModel: appViewModel)
            } else {
                LoginView(appViewModel: appViewModel)
            }
        }
        .task {
            await appViewModel.restoreSession()
        }
    }
}

#Preview {
    LoginView(appViewModel: AppViewModel(authService: MockAuthService()))
}
