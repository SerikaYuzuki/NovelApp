//
//  EditorView.swift
//  EditorKit
//
//  Created by SerikaYuzuki on 2025/08/17.
//

import SwiftUI

public protocol EditorAdapter: AnyObject {
    func setText(_ text: String)
    func getText() -> String
}

public struct EditorView: NSViewRepresentable {
    public final class Coordinator {
        public var adapter: EditorAdapter?
        init(adapter: EditorAdapter?) { self.adapter = adapter }
    }

    private let adapterFactory: () -> EditorAdapter

    public init(adapterFactory: @escaping () -> EditorAdapter) {
        self.adapterFactory = adapterFactory
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(adapter: adapterFactory())
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        scroll.documentView = textView

        // とりあえず単純バインド
        context.coordinator.adapter?.setText("")
        return scroll
    }

    public func updateNSView(_ view: NSScrollView, context: Context) { }
}

// 既定の単純Adapter
public final class SimpleEditorAdapter: EditorAdapter {
    private var text: String = ""
    public init() {}
    public func setText(_ text: String) { self.text = text }
    public func getText() -> String { text }
}
