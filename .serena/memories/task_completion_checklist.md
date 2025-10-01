# タスク完了時のチェックリスト

## 開発タスク完了時の標準フロー

### 1. テスト実行
```bash
xcodebuild test \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**確認ポイント:**
- ✅ すべてのテストがパス
- ✅ 新規追加したテストが含まれている
- ✅ 既存のテストに破壊的変更がない

### 2. ビルド確認
```bash
xcodebuild build \
  -project app/OtetsudaiCoin.xcodeproj \
  -scheme OtetsudaiCoin \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**確認ポイント:**
- ✅ ビルドエラーがない
- ✅ 警告が最小限
- ✅ deprecation warningへの対応

### 3. コード品質チェック

**アーキテクチャ準拠:**
- ✅ Data/Domain/Presentation層の分離が維持されている
- ✅ 依存関係の方向が正しい（Presentation → Domain ← Data）
- ✅ Repositoryパターンが適切に使用されている

**命名規則:**
- ✅ ファイル名が規約に従っている
- ✅ クラス・構造体名がPascalCase
- ✅ 変数・関数名がcamelCase

**@Observable パターン:**
- ✅ ViewModelに@Observableマクロを使用
- ✅ @MainActorが適切に付与されている
- ✅ @Publishedを使用していない（移行済み）

### 4. Git コミット
```bash
# 変更確認
git status
git diff

# ステージング
git add .

# コミット
git commit -m "feat: 機能の説明"
```

**コミットメッセージ規約:**
- `feat:` - 新機能
- `fix:` - バグ修正
- `refactor:` - リファクタリング
- `test:` - テスト追加・修正
- `docs:` - ドキュメント更新
- `chore:` - その他の変更

### 5. 最終確認

**ドキュメント:**
- ✅ README.mdの更新（必要な場合）
- ✅ CLAUDE.mdの更新（開発プロセス変更時）
- ✅ コードコメントの追加（複雑なロジック）

**クリーンアップ:**
- ✅ デバッグ用のprintやコメントアウトを削除
- ✅ 未使用のimportを削除
- ✅ TODOコメントをissue化または削除

## パフォーマンス検証（必要時）

### ベンチマーク実行
```bash
./scripts/benchmark-tests.sh
```

**確認ポイント:**
- ✅ テスト実行時間が許容範囲内
- ✅ パフォーマンス劣化がない
- ✅ メモリリークがない

## TDD（テスト駆動開発）フロー

### 開発サイクル
1. **Red**: テストを書く（失敗）
2. **Green**: 最小限の実装で通す
3. **Refactor**: コードを改善
4. **Repeat**: 次の機能へ

### テスト作成時のポイント
- ✅ テストファイルは`app/OtetsudaiCoinTests/`の適切な階層に配置
- ✅ テスト名は`test_[機能]_[条件]_[期待結果]()`形式
- ✅ ViewInspectorを使用したSwiftUIテスト
- ✅ モックリポジトリを使用した単体テスト

## リリース前チェック（該当時）

### ビルド設定
- ✅ DEBUGビルド機能が無効化されている
- ✅ バージョン番号が更新されている
- ✅ App Storeメタデータが最新

### セキュリティ
- ✅ 機密情報がハードコードされていない
- ✅ プライバシーポリシーが最新
- ✅ データ保護が適切に実装されている

## トラブルシューティング

### テスト失敗時
1. エラーメッセージを確認
2. 関連するテストケースを特定
3. デバッグログを追加
4. 必要に応じてシミュレータをリセット

### ビルド失敗時
1. クリーンビルドを試す
2. 依存関係を確認
3. Xcodeキャッシュをクリア
4. プロジェクト設定を確認

### パフォーマンス問題時
1. Instrumentsでプロファイリング
2. ベンチマークスクリプトで計測
3. Core Dataクエリを最適化
4. 不要な状態更新を削減
