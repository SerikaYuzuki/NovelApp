//
//  NovelApp.swift
//  Novel
//
//  Created by SerikaYuzuki on 2025/08/16.
//

import NovelCore
import SwiftUI

@main
struct NovelApp: App {
    private let deps = AppDependencies()
    @State private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .onAppear {
                    if let loaded = try? deps.repo.loadRecent() {
                        state.document = loaded
                    }
                }
                .onChange(of: state.document) {
                    try? deps.repo.save(state.document)
                }
        }
    }
}
