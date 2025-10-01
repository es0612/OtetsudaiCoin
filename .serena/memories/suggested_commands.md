# 推奨コマンド

## テスト実行

### 全テスト実行
```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### 特定のテストターゲット実行
```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:OtetsudaiCoinTests/AllowanceCalculatorTests
```

### シミュレータ事前起動（テスト高速化）
```bash
./scripts/prepare-simulator.sh -s "iPhone 16"
```

### パフォーマンスベンチマーク
```bash
./scripts/benchmark-tests.sh
```

## ビルド

### ビルド実行
```bash
xcodebuild build \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### クリーンビルド
```bash
xcodebuild clean build \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## シミュレータ管理

### シミュレータ一覧
```bash
xcrun simctl list devices available
```

### シミュレータ起動
```bash
xcrun simctl boot "iPhone 16"
```

### シミュレータシャットダウン
```bash
xcrun simctl shutdown all
```

### シミュレータデータ消去
```bash
xcrun simctl erase "iPhone 16"
```

## Git操作

### 状態確認
```bash
git status
git branch
```

### コミット
```bash
git add .
git commit -m "feat: 機能追加の説明"
```

### ブランチ作成
```bash
git checkout -b feature/new-feature
```

## プロジェクト管理

### ファイル検索
```bash
find app -name "*.swift" -type f
```

### コード検索（ripgrep）
```bash
rg "pattern" app/
```

### ディレクトリ構造表示
```bash
ls -R app/OtetsudaiCoin/
```

## Darwin/macOS 固有コマンド

### プロセス管理
```bash
# プロセス一覧
ps aux | grep Simulator

# プロセス終了
pkill -9 Simulator
```

### ファイル操作
```bash
# ファイルを開く
open path/to/file

# アプリケーションで開く
open -a Xcode app/OtetsudaiCoin.xcodeproj
```

### システム情報
```bash
# OSバージョン
sw_vers

# アーキテクチャ
uname -m
```

## 開発ワークフロー

### タスク完了時の標準フロー
1. テスト実行: `xcodebuild test ...`
2. ビルド確認: `xcodebuild build ...`
3. Git コミット: `git add . && git commit -m "..."`
4. ステータス確認: `git status`

### パフォーマンス最適化フロー
1. シミュレータ準備: `./scripts/prepare-simulator.sh`
2. ベンチマーク実行: `./scripts/benchmark-tests.sh`
3. 結果確認: `scripts/test-performance-report.md`

## デバッグ用コマンド（DEBUGビルドのみ）

### サンプルデータ生成
- アプリ内の設定画面から実行
- 3ヶ月分のサンプルデータを自動生成

### データ削除
- 記録データのみ削除: アプリ内設定から実行
- 全データ削除: アプリ内設定から実行
