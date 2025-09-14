//
//  Makefile
//  Novel
//
//  Created by SerikaYuzuki on 2025/09/15.
//

.PHONY: lint test ci

# フォーマットはXcode内蔵を使用。必要なら別途ターゲットを作る。

lint:
    # SwiftLintを使うなら有効化（入れないならこのターゲットを空に）
    @if which swiftlint >/dev/null; then swiftlint; else echo "swiftlint not installed (skip)"; fi

test:
    # ワークスペース/スキーム名は環境に合わせて
    xcodebuild \
      -scheme Novel \
      -destination 'platform=macOS' \
      -disableAutomaticPackageResolution \
      clean test

ci: lint test
