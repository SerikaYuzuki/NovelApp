//
//  SidebarRow.swift
//  NovelUI
//
//  Created by SerikaYuzuki on 2025/08/17.
//

import SwiftUI
import NovelCore

public struct SidebarRow: View {
    let chapter: Chapter
    let isSelected: Bool
    public init(chapter: Chapter, isSelected: Bool) {
        self.chapter = chapter; self.isSelected = isSelected
    }
    public var body: some View {
        HStack {
            Text(chapter.title).lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
