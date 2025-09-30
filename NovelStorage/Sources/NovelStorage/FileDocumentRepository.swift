//
//  FileDocumentRepository.swift
//  NovelStorage
//
//  Created by SerikaYuzuki on 2025/08/16.
//

/// 小説データ(JSON)のファイル入出力を担うリポジトリ。

import Foundation
import NovelCore

/// ファイルベースで小説データを保存/読込するリポジトリ。
/// 保存場所ディレクトリの切り替えも可能です。
public final class FileDocumentRepository: DocumentRepository {
    /// 小説データファイルの保存先ディレクトリ種別。
    public enum Location {
        /// アプリのドキュメントディレクトリ（両OSで安全）
        case appDocuments
        /// アプリケーションサポートディレクトリ（Macでパッケージ化に有効）
        case appSupport
        /// 任意のURL
        case custom(URL)
    }

    /// 読み書きするファイルの絶対URL。
    let url: URL

    /// 指定されたファイル名・保存場所でリポジトリを初期化します。
    /// - Parameters:
    ///   - filename: 保存するファイル名（デフォルト: "Novel.json"）
    ///   - location: ファイル保存場所（デフォルト: .appDocuments）
    public init(filename: String = "Novel.json", location: Location = .appDocuments) {
        self.url = Self.resolveURL(filename: filename, location: location)
    }

    /// 保存済み小説データを読み込みます。
    /// ファイルが存在しない場合はnilを返します。
    /// - Returns: 復元したNovelDocument。存在しない場合はnil。
    /// - Throws: デコードやファイル読み込み失敗時。
    public func loadRecent() throws -> NovelDocument? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(NovelDocument.self, from: data)
    }

    /// 小説データを保存します。
    /// - Parameter doc: 保存するNovelDocumentインスタンス。
    /// - Throws: エンコードやファイル書き込み失敗時。
    public func save(_ doc: NovelDocument) throws {
        let data = try JSONEncoder().encode(doc)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }

    /// 保存先ディレクトリ種別とファイル名から絶対URLを解決します。
    /// - Parameters:
    ///   - filename: 保存ファイル名。
    ///   - location: 保存場所種別。
    /// - Returns: 保存先ファイルの絶対URL。
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

