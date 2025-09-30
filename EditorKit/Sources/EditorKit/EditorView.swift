//
//  EditorView.swift
//  EditorKit
//
//  Created by SerikaYuzuki on 2025/08/17.
//

/// macOS向けのテキストエディタビューを提供します。
/// SwiftUI環境で利用可能なカスタマイズ可能なテキスト編集コンポーネントです。

import SwiftUI

/// テキスト編集ビュー用のアダプタプロトコル。
/// バッキングストアとしてのテキスト取得・設定を定義します。
public protocol EditorAdapter: AnyObject {
    /// テキストをアダプターに設定します。
    /// - Parameter text: 設定するテキスト
    func setText(_ text: String)
    /// アダプターが保持するテキストを取得します。
    /// - Returns: 現在のテキスト
    func getText() -> String
}

/// 最も単純なEditorAdapter実装。インメモリでテキストを保持します。
public final class SimpleEditorAdapter: EditorAdapter {
    /// 保持中のテキスト内容
    private var text: String = ""

    /// 新しいSimpleEditorAdapterを初期化します。
    public init() {}

    /// テキストをアダプターに設定します。
    /// - Parameter text: 設定するテキスト
    public func setText(_ text: String) { self.text = text }

    /// アダプターが保持するテキストを取得します。
    /// - Returns: 現在のテキスト
    public func getText() -> String { text }
}

/// SwiftUIで利用可能なmacOS用テキストエディタビュー。
/// EditorAdapterによるカスタマイズに対応します。
public struct EditorView: NSViewRepresentable {
    /// 編集テキストのバインディング
    @Binding private var text: String
    /// 編集可能フラグ
    private var isEditable: Bool
    /// アダプターのインスタンス生成クロージャ
    private let adapterFactory: () -> EditorAdapter
    
    public init(
        text: Binding<String>,
        isEditable: Bool = true,
        adapterFactory: @escaping () -> EditorAdapter = { SimpleEditorAdapter() }
    ) {
        self._text = text
        self.isEditable = isEditable
        self.adapterFactory = adapterFactory
    }
    
    /// 内部コーディネーター。アダプターの参照を管理します。
    public final class Coordinator: NSObject, NSTextViewDelegate {
        weak var textView: NSTextView?
        @Binding var text: String
        var isProgrammaticUpdate = false
        var currentText: String
        private var pendingPush: DispatchWorkItem?
        var adapter: EditorAdapter?
        
        init (text: Binding<String>, adapter: EditorAdapter) {
            self._text = text
            self.currentText = text.wrappedValue
            self.adapter = adapter
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let tv =  textView else { return }
            
            if tv.hasMarkedText() { return } // IME入力中は無視
            
            if isProgrammaticUpdate { return }
            
            let newText = tv.string
            currentText = newText
            
            pendingPush?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.text = newText
                self.adapter?.setText(newText)
                self.pendingPush = nil
            }
            
            pendingPush = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: work)
            
        }
    }
    
    /// コーディネーターを生成します。
    /// - Returns: 新しいCoordinatorインスタンス
    public func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, adapter: adapterFactory())
    }
    
    /// NSTextViewをラップしたNSScrollViewを生成します。
    /// - Parameter context: SwiftUIコンテキスト
    /// - Returns: 編集ビューとしてのNSScrollView
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        
        let tv = NSTextView()
        tv.isRichText = false
        tv.isEditable = isEditable
        tv.isSelectable = true
        tv.allowsUndo = true           // Undo/Redo をOS標準の仕組みに委ねる
        tv.usesFindBar = true          // ⌘Fで検索バー
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDataDetectionEnabled = false
        tv.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        tv.textContainerInset = NSSize(width: 8, height: 8)
        
        tv.string = text
        tv.delegate = context.coordinator
        scrollView.documentView = tv
        context.coordinator.textView = tv
        context.coordinator.adapter?.setText(text)

        return scrollView
    }

    /// ビューの状態を最新に更新します。（未実装）
    /// - Parameters:
    ///   - view: 現在のNSScrollView
    ///   - context: SwiftUIコンテキスト
    public func updateNSView(_ view: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        
        tv.isEditable = isEditable
        
        if context.coordinator.currentText != text {
        }
    }
}

#Preview {
    // プレビュー内で状態を管理するためのコンテナViewを定義します
    struct EditorPreviewContainer: View {
        // EditorViewに渡すための状態。これが「真の状態」の元になります。
        @State private var documentText: String = """
        これは#Preview用の初期テキストです。
        
        ここでリアルタイムに編集を試すことができます。
        下のテキストが連動して更新されれば、Bindingは正常に機能しています。
        """

        var body: some View {
            VStack(spacing: 16) {
                // EditorViewのインスタンスを作成し、@State変数をBindingとして渡します
                EditorView(text: $documentText)
                    // プレビューが見やすいように枠線をつけます
                    .border(Color.gray)

                // --- デバッグ用の補助ビュー ---
                Divider()
                
                VStack(alignment: .leading) {
                    Text("Bindingの現在の値：")
                        .font(.headline)
                    // EditorViewへの入力がここに反映されるかを確認します
                    Text(documentText)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(width: 400, height: 400) // プレビューのサイズを調整
        }
    }

    // プレビューにコンテナViewを表示します
    return EditorPreviewContainer()
}
