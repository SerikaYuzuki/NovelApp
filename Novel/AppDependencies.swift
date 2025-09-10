//
//  AppDependencies.swift
//  Novel
//
//  Created by SerikaYuzuki on 2025/08/17.
//

import Foundation
import NovelCore
import NovelStorage
import EditorKit

final class AppDependencies {
    let repo: DocumentRepository
    init() {
        self.repo = FileDocumentRepository(
            filename: "Novel.json",
            location: .appDocuments
        )
    }
}
