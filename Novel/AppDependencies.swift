//
//  AppDependencies.swift
//  Novel
//
//  Created by SerikaYuzuki on 2025/08/17.
//

/// アプリ全体で共有する依存関係をまとめるコンテナ。
/// - 役割: ドキュメント保存用のリポジトリを構築し、アプリ各所に提供します。
/// - 保存場所: ユーザの `Documents/Novel` 配下（`Snapshots` を含む）に作品データを配置します。
/// - 注意: アプリのサンドボックス内 `Documents` を使用するため、iCloudバックアップやファイル共有設定の影響を受ける可能性があります。

import Foundation   // ファイル操作・URL生成などの基盤機能
import NovelCore    // ドキュメントモデルやリポジトリプロトコル等のコア定義
import NovelStorage // ストレージ実装（NovelpkgRepository など）
import EditorKit    // エディタ機能との連携が必要な場合に使用

/// アプリの依存性を構築・保持するコンテナ。
///
/// アプリ起動時に一度初期化され、`Documents/Novel` 配下に
/// 作品保存用のベースディレクトリとスナップショット用ディレクトリを用意します。
/// その上で `DocumentRepository` 実装（`NovelpkgRepository`）を生成して公開します。
final class AppDependencies {
    /// 作品データの読み書きを担うリポジトリ。
    /// `NovelpkgRepository` の抽象プロトコル型として公開します。
    let repo: DocumentRepository

    /// 依存性を初期化します。
    /// - 概要:
    ///   1. ユーザの `Documents` ディレクトリを取得
    ///   2. `Documents/Novel` と `Documents/Novel/Snapshots` を作成（存在しなければ）
    ///   3. それらを基に `NovelpkgRepository` を構築
    init() {
        // ✅ 保存先: ApplicationSupport → Documents に変更
        // 1) ユーザの Documents ディレクトリ
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]

        // 2) ベースとスナップショットのフォルダを用意
        //    例: ~/Documents/Novel, ~/Documents/Novel/Snapshots
        let base = docs.appendingPathComponent("Novel", isDirectory: true)
        let snaps = base.appendingPathComponent("Snapshots", isDirectory: true)

        // ディレクトリを必要に応じて作成
        try? FileManager.default.createDirectory(at: base,  withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: snaps, withIntermediateDirectories: true)

        // 3) リポジトリを構築
        self.repo = NovelpkgRepository(options: .init(baseDirectory: base,
                                                      snapshotsDirectory: snaps))
    }
}
