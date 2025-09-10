//
//  AppState.swift
//  Novel
//
//  Created by SerikaYuzuki on 2025/08/17.
//

import Observation
import NovelCore

@Observable
final class AppState {
    var document: NovelDocument = .init(title: "新規作品", chapters: [
        .init(title: "第一章", content: "はじめに…", order: 0),
        .init(title: "第二章", content: "", order: 1)
    ])
    var selection: ChapterID? = nil

    var selectedChapter: Chapter? {
        guard let id = selection else { return nil }
        return document.chapters.first { $0.id == id }
    }
}
