//
//  FileDocumentRepository.swift
//  NovelStorage
//
//  Created by SerikaYuzuki on 2025/08/16.
//

import Foundation
import NovelCore

public final class FileDocumentRepository: DocumentRepository {
    public enum Location {
        case appDocuments   // 両OSで安全
        case appSupport     // Macでパッケージ化したい時はこちらも有力
        case custom(URL)
    }

    let url: URL

    public init(filename: String = "Novel.json", location: Location = .appDocuments) {
        self.url = Self.resolveURL(filename: filename, location: location)
    }

    public func loadRecent() throws -> NovelDocument? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(NovelDocument.self, from: data)
    }

    public func save(_ doc: NovelDocument) throws {
        let data = try JSONEncoder().encode(doc)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }

    private static func resolveURL(filename: String, location: Location) -> URL {
        switch location {
        case .custom(let u): return u
        case .appDocuments:
            let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return base.appendingPathComponent(filename)
        case .appSupport:
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            #if os(macOS)
            return base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Novel").appendingPathComponent(filename)
            #else
            return base.appendingPathComponent(filename)
            #endif
        }
    }
}
