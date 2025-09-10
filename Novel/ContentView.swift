//
//  ContentView.swift
//  Novel
//
//  Created by SerikaYuzuki on 2025/08/16.
//

import SwiftUI
import NovelCore
import NovelUI
import EditorKit

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { state.selection },
                set: { state.selection = $0 }
            )) {
                ForEach(state.document.chapters, id: \.id) { ch in
                    SidebarRow(chapter: ch, isSelected: state.selection == ch.id)
                        .tag(Optional(ch.id))
                        .contextMenu {
                            Button("この下に追加") { insertBelow(ch.id) }
                        }
                }
                .onMove(perform: moveChapters)
            }
        } detail: {
            if let ch = state.selectedChapter {
                EditorView { SimpleEditorAdapter() } // Step1は仮
                    .overlay(alignment: .topLeading) {
                        Text(ch.title).font(.headline).padding(8)
                    }
            } else {
                Text("章を選択してください").foregroundStyle(.secondary)
            }
        }
    }

    private func insertBelow(_ id: ChapterID) {
        guard let idx = state.document.chapters.firstIndex(where: { $0.id == id }) else { return }
        let new = Chapter(title: "新しい章", content: "", order: idx + 1)
        state.document.chapters.insert(new, at: idx + 1)
        state.selection = new.id
        renumber()
    }

    private func moveChapters(from: IndexSet, to: Int) {
        state.document.chapters.move(fromOffsets: from, toOffset: to)
        renumber()
    }

    private func renumber() {
        for (i, _) in state.document.chapters.enumerated() { state.document.chapters[i].order = i }
    }
}
