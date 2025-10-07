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
                // TODO: 現状は更新のたびにスナップショットが更新されるような形になっているが、一定時間間隔でスナップショットの保存、画面更新時のスナップショットの自動保存・削除を実装する
                .onChange(of: state.document, initial: false) { oldValue, newValue in
                    try? deps.repo.save(newValue)
                }
        }
    }
}
