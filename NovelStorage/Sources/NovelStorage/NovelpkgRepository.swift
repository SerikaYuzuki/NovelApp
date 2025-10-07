/// NovelpkgRepository.swift
///
/// このファイルは、小説ドキュメント（`NovelDocument`）をアプリ独自のパッケージ形式「.novelpkg」で
/// 読み書き（ロード/セーブ）するためのリポジトリ実装を提供します。
///
/// .novelpkg はディレクトリベースのパッケージで、以下の構造を持ちます：
/// - manifest.json: メタデータ（タイトル、章ID、章タイトルなど）
/// - chapters/     : 章本文を並び順に `0001.md`, `0002.md` ... として保存
/// - attachments/  : 画像などの添付（将来拡張用）
///
/// このリポジトリは、アトミックな保存（途中で失敗しても壊れにくい）や、
/// スナップショットの自動作成（簡易バックアップ）を行い、安全なデータ保存を目指します。
import Foundation
import NovelCore

/// .novelpkg 形式のドキュメントを読み書きするためのリポジトリ。
///
/// - 何をしているか: `NovelDocument` をファイルシステム上の .novelpkg パッケージに保存/読み込みします。
/// - なぜ必要か: データの整合性を保ちつつ（アトミックな置換、スナップショット作成）、
///   シンプルで人間にも読みやすい構造（JSON + Markdown）で永続化するためです。
/// - 特徴: 直近のパッケージ自動検出、旧フォーマット（`Novel.json`）からの移行、
///   スナップショットの自動作成、ファイル名のサニタイズなど。
public final class NovelpkgRepository: DocumentRepository {
    /// リポジトリの入出力先をまとめた設定値。
    /// - Parameters:
    ///   - baseDirectory: .novelpkg を配置するベースのディレクトリ。
    ///   - snapshotsDirectory: 保存時にスナップショット（バックアップ）を置くディレクトリ。
    public struct Options: Sendable {
        /// .novelpkg を配置するベースディレクトリ（ユーザープロジェクトのルートなど）
        public var baseDirectory: URL
        /// 保存前の状態を退避するスナップショットの保存先ディレクトリ
        public var snapshotsDirectory: URL
        /// Options を生成します。
        /// - Parameters:
        ///   - baseDirectory: .novelpkg を作成・検索する基点のフォルダ。
        ///   - snapshotsDirectory: スナップショット（バックアップ）を保管するフォルダ。
        public init(baseDirectory: URL, snapshotsDirectory: URL) {
            self.baseDirectory = baseDirectory
            self.snapshotsDirectory = snapshotsDirectory
        }
    }

    /// リポジトリの動作に必要なディレクトリ設定
    private let options: Options
    /// ファイル/ディレクトリ操作のためのユーティリティ
    private let fileManager = FileManager()

    /// 指定されたオプションでリポジトリを初期化します。
    /// - Parameter options: 入出力先ディレクトリなどの設定。
    public init(options: Options) {
        self.options = options
    }

    // MARK: - Entry points
    // ここでは、アプリから直接呼ばれる「入口」メソッド（最近のドキュメント読み込み、保存）を提供します。

    /// 直近で更新された .novelpkg を読み込みます。なければ旧フォーマットからの移行を試みます。
    ///
    /// - 何をしているか:
    ///   1. `baseDirectory` 内の .novelpkg を更新日時でソートし、最新を読み込み。
    ///   2. 見つからなければ、旧フォーマット `Novel.json` が存在する場合に読み込んで .novelpkg に変換保存。
    /// - 戻り値: 読み込んだ `NovelDocument`。該当がなければ `nil`。
    /// - 失敗時: ファイルI/OやJSONデコードに失敗した場合は throw します。
    public func loadRecent() throws -> NovelDocument? {
        // 1) 既存 .novelpkg を探し、あればそれを読み込む
        if let url = try latestNovelpkg() {
            return try load(from: url)
        }
        // 2) 旧フォーマット（単一JSON）からの移行パス
        //    旧 `Novel.json` が残っている環境では、まずそれを読み込み、
        //    新しい .novelpkg 構造で保存し直してからドキュメントを返します。
        let legacy = options.baseDirectory.appendingPathComponent("Novel.json")
        if fileManager.fileExists(atPath: legacy.path) {
            let data = try Data(contentsOf: legacy)
            let legacyDoc = try JSONDecoder().decode(NovelDocument.self, from: data)
            let target = options.baseDirectory.appendingPathComponent(defaultPackageName(for: legacyDoc))
            try save(legacyDoc, to: target)
            // 旧ファイルは残す（安全策）。削除したければここで removeItem してOK。
            return legacyDoc
        }
        return nil
    }

    /// ドキュメントをデフォルトのパッケージ名で保存します。
    /// - Parameter doc: 保存対象の `NovelDocument`。
    /// - Note: ファイル名はタイトルから安全な文字のみを用いて自動生成されます。
    public func save(_ doc: NovelDocument) throws {
        let url = options.baseDirectory.appendingPathComponent(defaultPackageName(for: doc))
        try save(doc, to: url)
    }

    // MARK: - Core I/O
    // ここから下は、実際の読み込み/書き込み処理（低レベルI/O）を担当します。

    /// 指定された .novelpkg から `NovelDocument` を復元します。
    /// - Parameter packageURL: .novelpkg ディレクトリのURL。
    /// - Returns: 復元した `NovelDocument`。
    /// - Throws: ファイルの読み込みやJSONデコードに失敗した場合。
    public func load(from packageURL: URL) throws -> NovelDocument {
        // パッケージの基本パスを組み立てる（マニフェストと章ディレクトリ）
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        let chaptersDir = packageURL.appendingPathComponent("chapters")

        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))

        // 章IDの順序に基づき、ファイル名（0001.md など）から本文を読み出し、
        // マニフェストのタイトル辞書から各章のタイトルを復元します。
        var chapters: [Chapter] = []
        for (index, id) in manifest.chapterIDs.enumerated() {
            let filename = String(format: "%04d.md", index + 1)
            let mdURL = chaptersDir.appendingPathComponent(filename)
            let text = (try? String(contentsOf: mdURL, encoding: .utf8)) ?? ""
            let title = manifest.chapterTitles[id] ?? "無題の章"
            chapters.append(Chapter(id: ChapterID(id), title: title, content: text, order: index))
        }
        return NovelDocument(id: manifest.documentID,
                             title: manifest.title,
                             chapters: chapters)
    }

    /// `NovelDocument` を指定の場所に .novelpkg として保存します。
    ///
    /// - 何をしているか（概要）:
    ///   1. 一時ディレクトリに完全なパッケージ構造を作る（失敗時に既存を壊さないため）。
    ///   2. 章を並び順に `0001.md` 形式で書き出す。
    ///   3. マニフェスト（JSON）を生成する。
    ///   4. スナップショットを作成（保存前の状態/初回の状態を退避）。
    ///   5. 既存パッケージがあればアトミックに置換、なければ移動。
    /// - Parameter doc: 保存するドキュメント。
    /// - Parameter packageURL: 保存先の .novelpkg ディレクトリURL。
    /// - Throws: ディレクトリ作成、ファイル書き込み、置換処理でのエラー。
    public func save(_ doc: NovelDocument, to packageURL: URL) throws {
        // 1) 一時作業ディレクトリを作成し、必要なサブディレクトリ（chapters/ attachments/）を用意
        //    → 途中で失敗しても既存データを壊さないための安全策
        let tmp = options.baseDirectory.appendingPathComponent(".novelpkg_tmp_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tmp, withIntermediateDirectories: true)
        let chaptersDir = tmp.appendingPathComponent("chapters")
        let attachmentsDir = tmp.appendingPathComponent("attachments")
        try fileManager.createDirectory(at: chaptersDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

        // 2) 章を書き出し（順番 = ファイル名）
        //    並び順は `order` に基づき、`0001.md` から連番で保存します。
        //    章ID一覧とタイトル辞書はマニフェスト用に同時に組み立てます。
        let sorted = doc.chapters.sorted(by: { $0.order < $1.order })
        var idList: [UUID] = []
        var titles: [UUID:String] = [:]
        for (i, ch) in sorted.enumerated() {
            idList.append(ch.id.rawValue)
            titles[ch.id.rawValue] = ch.title
            let filename = String(format: "%04d.md", i + 1)
            let mdURL = chaptersDir.appendingPathComponent(filename)
            try (ch.content).data(using: .utf8)?.write(to: mdURL, options: [.atomic])
        }

        // 3) マニフェストの生成
        //    保存時刻は ISO8601 文字列で記録します。
        let manifest = Manifest(
            formatVersion: 1,
            documentID: doc.id,
            title: doc.title,
            chapterIDs: idList,
            chapterTitles: titles,
            createdAt: currentISO8601(),
            updatedAt: currentISO8601()
        )
        let mURL = tmp.appendingPathComponent("manifest.json")
        try JSONEncoder.pretty.encode(manifest).write(to: mURL, options: [.atomic])

        // 4) スナップショット作成（任意だが強力な安全策）
        //    既存のパッケージがある場合はそれを、初回は tmp を snapshots/ に退避します。
        try snapshot(packageTempURL: tmp, originalPackageURL: packageURL)

        // 5) アトミックな入れ替え/移動
        //    既存があれば `replaceItem` で置換（バックアップも作成可能）。なければ単純移動。
        if fileManager.fileExists(atPath: packageURL.path) {
            // 既存→置換
            let bak = packageURL.deletingLastPathComponent()
                .appendingPathComponent("\(packageURL.lastPathComponent).bak")
            _ = try? fileManager.removeItem(at: bak)
            try fileManager.replaceItem(
                at: packageURL,
                withItemAt: tmp,
                backupItemName: bak.lastPathComponent,
                options: [.usingNewMetadataOnly],
                resultingItemURL: nil)
            _ = try? fileManager.removeItem(at: bak) // バックアップを残したいなら消さない
        } else {
            try fileManager.moveItem(at: tmp, to: packageURL)
        }
    }

    /// baseDirectory 内で最も更新日時が新しい .novelpkg を返します。
    /// - Returns: 見つかった場合はURL。なければ `nil`。
    /// - Throws: ディレクトリ列挙に失敗した場合。
    private func latestNovelpkg() throws -> URL? {
        let contents = try fileManager.contentsOfDirectory(at: options.baseDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        let pkgs = contents.filter { $0.pathExtension == "novelpkg" }
        return try pkgs.max { a, b in
            let aDate = try a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            let bDate = try b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            return aDate < bDate
        }
    }

    /// ドキュメントタイトルから安全なファイル名を生成し、拡張子 `.novelpkg` を付与します。
    /// - Parameter doc: ファイル名の元になるドキュメント。
    /// - Returns: サニタイズ済みのパッケージ名（例: `My_Title.novelpkg`）。
    private func defaultPackageName(for doc: NovelDocument) -> String {
        let safe = sanitizeFilename(doc.title.isEmpty ? "Untitled" : doc.title)
        return "\(safe).novelpkg"
    }

    /// ファイル名に使えない文字を `_` に置き換え、前後の空白を除去します。
    /// - Parameter s: 元の文字列。
    /// - Returns: 安全なファイル名として使える文字列。
    private func sanitizeFilename(_ s: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let compact = s.unicodeScalars.map { invalid.contains($0) ? "_" : Character($0) }.reduce("") { $0 + String($1) }
        return compact.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 現在時刻を ISO8601 文字列として返します。
    private func currentISO8601() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    /// 保存前の状態を snapshots ディレクトリに退避します。
    ///
    /// - 目的: 保存処理で問題が起きても、直前の状態に戻せるようにするための簡易バックアップ。
    /// - 振る舞い:
    ///   - 既存のパッケージがある場合: それを `snapshotsDirectory` にコピー。
    ///   - 初回保存（既存なし）の場合: 作成した一時ディレクトリ（tmp）をコピー。
    /// - Parameters:
    ///   - packageTempURL: 一時作業ディレクトリ。
    ///   - originalPackageURL: 既存（または保存先）の .novelpkg ディレクトリURL。
    private func snapshot(packageTempURL tmp: URL, originalPackageURL dest: URL) throws {
        // スナップショット先ディレクトリを確実に作成
        let snapDir = options.snapshotsDirectory
        try fileManager.createDirectory(at: snapDir, withIntermediateDirectories: true)
        // ファイル名用のタイムスタンプ（コロンはファイル名に不向きなのでハイフンに置換）
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let snapURL = snapDir.appendingPathComponent("\(dest.deletingPathExtension().lastPathComponent)_\(stamp).novelpkg")
        // 既存パッケージの有無でコピー元を切り替える
        if fileManager.fileExists(atPath: dest.path) {
            // すでにあるパッケージをコピー
            try? fileManager.copyItem(at: dest, to: snapURL)
        } else {
            // 初回は tmp をコピーしておく
            try? fileManager.copyItem(at: tmp, to: snapURL)
        }
    }
}

/// .novelpkg のマニフェスト（メタデータ）を表すモデル。
/// 読み書きともに JSON へエンコード/デコードされます。
/// - Note: `chapterIDs` の配列順が章の並び順を決定します。
fileprivate struct Manifest: Codable {
    /// フォーマットのバージョン。将来の互換性のために保持
    let formatVersion: Int
    /// ドキュメント全体の一意なID
    let documentID: UUID
    /// ドキュメントのタイトル
    let title: String
    /// 章のID一覧（この配列の順序が章の並び順を決定）
    let chapterIDs: [UUID]
    /// 章IDをキーにしたタイトル辞書
    let chapterTitles: [UUID:String]
    /// 作成日時（ISO8601 文字列）
    let createdAt: String
    /// 更新日時（ISO8601 文字列）
    let updatedAt: String
}

/// JSON を見やすい形式で出力するためのユーティリティ。
/// `prettyPrinted` と `sortedKeys` を有効にして、差分管理やレビューをしやすくします。
fileprivate extension JSONEncoder {
    /// 整形設定済みの `JSONEncoder` を返します。
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }
}
