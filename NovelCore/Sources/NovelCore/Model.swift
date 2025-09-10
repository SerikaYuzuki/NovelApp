//
//  Model.swift
//  NovelCore
//
//  Created by SerikaYuzuki on 2025/08/16.
//

import Foundation

/// 型安全な章識別子。
///
/// - Note: 内部的には `UUID` を保持します。`Equatable`/`Hashable` により
///   コレクションのキーとして利用でき、`Sendable` により並行処理間で安全に受け渡しできます。
/// - SeeAlso: `Chapter`
public struct ChapterID: Hashable, Codable, Sendable, Equatable {
    /// 識別子の実体。
    public let rawValue: UUID

    /// 新しい識別子を生成します。
    /// - Parameter id: 既存の `UUID` を用いる場合に指定します（省略時は新規生成）。
    public init(_ id: UUID = .init()) { self.rawValue = id }
}

/// 物語の「章」を表すモデル。
///
/// - Important: 並び順は `order` もしくは `chapters` 配列の順序で管理します。
///   本モデルでは `order` を「章の並び順インデックス」として想定しています（0始まりを推奨）。
///   配列順と `order` のどちらを正とするかはアプリのポリシーに従ってください。
/// - Note: `Sendable` 準拠のため、並行処理間でも安全に受け渡しできます。
public struct Chapter: Codable, Sendable, Identifiable, Equatable {
    /// 章の一意な識別子。
    public var id: ChapterID
    /// 章タイトル。未設定時は「無題の章」。
    public var title: String
    /// 章本文。プレーンテキストを想定（マークアップを扱う場合は別途仕様化してください）。
    public var content: String
    /// 並び順インデックス（0始まりを推奨）。UI 表示や並べ替えで使用します。
    ///
    /// - Note: 欠番や重複が発生しうる場合、保存前に正規化することを推奨します。
    public var order: Int

    /// 新しい章を生成します。
    /// - Parameters:
    ///   - id: 章の識別子（省略時は自動生成）。
    ///   - title: 章タイトル（省略時は「無題の章」）。
    ///   - content: 本文（省略時は空文字）。
    ///   - order: 並び順インデックス（省略時 0）。
    public init(id: ChapterID = .init(), title: String = "無題の章", content: String = "", order: Int = 0) {
        self.id = id; self.title = title; self.content = content; self.order = order
    }
}

/// 小説ドキュメント全体を表すモデル。
///
/// 作品タイトルと複数の章から構成されます。章の順序は `chapters` 配列の順序、
/// もしくは各 `Chapter.order` に基づいて管理します。
///
/// - Design: 単純なデータモデルとして `Codable` に準拠し、
///   リポジトリ層（`DocumentRepository`）での保存・読み込みに利用します。
public struct NovelDocument: Codable, Sendable, Identifiable, Equatable {
    /// ドキュメントの識別子。
    public var id: UUID
    /// 作品タイトル。未設定時は「無題の作品」。
    public var title: String
    /// 章の配列。配列順と `Chapter.order` の整合性は上位レイヤーで担保してください。
    public var chapters: [Chapter]

    /// 新しいドキュメントを生成します。
    /// - Parameters:
    ///   - id: ドキュメント識別子（省略時は自動生成）。
    ///   - title: 作品タイトル（省略時は「無題の作品」）。
    ///   - chapters: 章の配列（省略時は空配列）。
    public init(id: UUID = .init(), title: String = "無題の作品", chapters: [Chapter] = []) {
        self.id = id; self.title = title; self.chapters = chapters
    }
}

/// 小説ドキュメントの保存層を抽象化するプロトコル。
///
/// 具体的な保存先（ローカルファイル、iCloud Drive、データベース等）に依存しない
/// アプリケーション層のためのインターフェースです。
///
/// - Throws: 実装に応じた入出力エラーを投げます。エラー型は実装側で定義してください。
/// - Note: 現在は同期 API（`throws`）ですが、将来的に `async`/`await` 版の追加も検討できます。
public protocol DocumentRepository {
    /// 最近使用したドキュメントを読み込みます。
    ///
    /// - Returns: ドキュメントが存在する場合は `NovelDocument`、存在しない場合は `nil`。
    /// - Throws: 入出力エラーやデコードエラー等。
    func loadRecent() throws -> NovelDocument?

    /// ドキュメントを保存します。
    ///
    /// - Parameter doc: 保存対象のドキュメント。
    /// - Throws: 入出力エラーやエンコードエラー等。
    func save(_ doc: NovelDocument) throws
}
