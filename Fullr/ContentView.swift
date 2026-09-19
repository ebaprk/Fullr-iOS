//
//  ContentView.swift
//  Fullr
//
//  Created by Abe and Jonathan on 9/18/26.
//

import SwiftUI

struct ContentView: View {
    @State private var appViewModel = AppViewModel()

    var body: some View {
        Group {
            if appViewModel.isAuthenticated {
                FullrTabView(appViewModel: appViewModel)
            } else {
                LoginView(appViewModel: appViewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
