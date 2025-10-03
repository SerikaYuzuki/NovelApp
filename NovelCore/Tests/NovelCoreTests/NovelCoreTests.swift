import Testing
@testable import NovelCore

@Test func chapterID_is_unique() async throws {
    let a = ChapterID()
    let b = ChapterID()
    #expect(a != b)
}

@Test func chapter_init_defaults() async throws {
    let chapter = Chapter()
    #expect(chapter.title == "無題の章")
    #expect(chapter.content.isEmpty)
    #expect(chapter.order == 0)
}


