import Testing
import Foundation
@testable import NovelStorage
import NovelCore

@Test func storage_save_and_load() async throws {
    let base = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let url = base.appending(path: "doc.json")
    let repo = FileDocumentRepository(filename: "doc.json", location: .custom(url))

    let original = NovelDocument(title: "T", chapters: [.init(title: "C1")])
    try repo.save(original)

    let loaded = try #require(repo.loadRecent())
    #expect(loaded.title == "T")
    #expect(loaded.chapters.count == 1)
}
