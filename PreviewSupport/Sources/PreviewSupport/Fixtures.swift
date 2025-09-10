//
//  Fixtures.swift
//  PreviewSupport
//
//  Created by SerikaYuzuki on 2025/08/17.
//

import NovelCore

public enum Fixtures {
    public static let sampleDoc = NovelDocument(
        title: "サンプル作品",
        chapters: [
            .init(title: "はじめに", content: "……", order: 0),
            .init(title: "世界観", content: "……", order: 1),
        ])
}
