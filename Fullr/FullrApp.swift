//
//  FullrApp.swift
//  Fullr
//
//  Created by Abe on 9/18/26.
//

import SwiftUI

@main
struct FullrApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .font(FullrFont.regular(16))
                .tint(FullrPalette.moss)
                .preferredColorScheme(.light)
        }
    }
}
