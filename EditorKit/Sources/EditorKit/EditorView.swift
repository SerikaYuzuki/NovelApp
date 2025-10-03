/**
 EditorKit の macOS 向けテキスト編集ビューとアダプタの実装。

 - Important: このファイルは macOS 専用の実装です。`NSViewRepresentable` と `NSTextView` を使用します。
 - SeeAlso: `EditorAdapter`, `EditorView`
 */

import SwiftUI

/// テキスト編集ビュー用のアダプタプロトコル。
/// `EditorView` が利用するバッキングストアの読み書きを定義します。
///
/// - Note: 実装はスレッドセーフである必要はありません。`EditorView` からの呼び出しはメインスレッドで行われます。
public protocol EditorAdapter: AnyObject {
    /// テキストをアダプターに設定します。
    /// - Parameter text: 設定するテキスト
    func setText(_ text: String)
    /// アダプターが保持するテキストを取得します。
    /// - Returns: 現在のテキスト
    func getText() -> String
}

/// 最も単純なEditorAdapter実装。インメモリでテキストを保持します。
/// - Note: データはプロセス内メモリにのみ保持され、永続化は行いません。
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

/// SwiftUI で利用可能な macOS 向けテキストエディタビュー。
/// `NSTextView` をラップし、`Binding<String>` と `EditorAdapter` を通じて
/// テキストの双方向同期とカスタマイズ可能なバッキングストアを提供します。
///
/// - SeeAlso: ``EditorAdapter``
public struct EditorView: NSViewRepresentable {
    /// 編集テキストのバインディング
    @Binding private var text: String
    /// 編集可能フラグ
    private var isEditable: Bool
    /// アダプターのインスタンス生成クロージャ
    private let adapterFactory: () -> EditorAdapter
    
    /// 新しい `EditorView` を作成します。
    ///
    /// - Parameters:
    ///   - text: 編集対象テキストの `Binding`。ユーザー操作やプログラム更新と双方向に同期されます。
    ///   - isEditable: テキストが編集可能かどうか。既定値は `true`。
    ///   - adapterFactory: バッキングストアを提供する ``EditorAdapter`` を生成するクロージャ。
    ///     既定では ``SimpleEditorAdapter`` を使用します。
    public init(
        text: Binding<String>,
        isEditable: Bool = true,
        adapterFactory: @escaping () -> EditorAdapter = { SimpleEditorAdapter() }
    ) {
        self._text = text
        self.isEditable = isEditable
        self.adapterFactory = adapterFactory
    }
    
    /// 内部コーディネーター。
    /// `NSTextView` のデリゲートとしてイベントを受け取り、`Binding` とアダプターへの
    /// 同期を仲介します。
    public final class Coordinator: NSObject, NSTextViewDelegate {
        /// ラップしている `NSTextView` への弱参照。
        weak var textView: NSTextView?
        /// SwiftUI 側のテキスト `Binding`。
        @Binding var text: String
        /// プログラムによる更新中かどうかのフラグ。無限ループ更新を防ぎます。
        var isProgrammaticUpdate = false
        /// 直近に反映したテキストのスナップショット。
        var currentText: String
        /// 変更のバッファリングに使用するディスパッチワーク。高速入力時の過剰更新を抑制します。
        private var pendingPush: DispatchWorkItem?
        /// バッキングストアを提供するアダプター。
        var adapter: EditorAdapter?
        
        init (text: Binding<String>, adapter: EditorAdapter) {
            self._text = text
            self.currentText = text.wrappedValue
            self.adapter = adapter
        }
        
        /// プログラムからテキストを適用し、ユーザー入力イベントとしては扱わないようにします。
        ///
        /// - Parameter newValue: 適用する新しい文字列。
        @MainActor func applyProgrammatic (text newValue: String){
            guard let tv = textView else { return }
            isProgrammaticUpdate = true
            tv.string = newValue
            currentText = newValue
            isProgrammaticUpdate = false
        }
        
        /// テキスト変更時に呼び出されます。IME 確定前の変更やプログラム更新は無視し、
        /// 適切なタイミングで `Binding` とアダプターへ変更を反映します。
        ///
        /// - Parameter notification: `NSTextView` の変更通知。
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

    /// 既存の `NSScrollView`/`NSTextView` を最新の状態に更新します。
    /// 編集可否を反映し、`Binding` の変更がビューに未反映の場合のみ
    /// プログラム的にテキストを適用します（IME 確定前は適用しません）。
    ///
    /// - Parameters:
    ///   - view: ラップしている `NSScrollView`。
    ///   - context: SwiftUI のコンテキスト。
    public func updateNSView(_ view: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        
        tv.isEditable = isEditable
        
        if context.coordinator.isProgrammaticUpdate == false,
           context.coordinator.currentText != text,
           !tv.hasMarkedText()
        {
            context.coordinator.applyProgrammatic(text: text)
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

