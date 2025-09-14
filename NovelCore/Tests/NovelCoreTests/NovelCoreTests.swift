import Testing
@testable import NovelCore

@Test func chapterID_is_unique() async throws {
    let a = ChapterID()
    let b = ChapterID()
    #expect(a != b)
    
}
