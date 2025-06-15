# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

OtetsudaiCoinは、SwiftUIとCore Dataを使用したiOSアプリです。MVVM + クリーンアーキテクチャパターンを採用し、TDD開発プロセスに従って開発されています。

## 開発コマンド

### ビルドと実行
```bash
# Xcodeでプロジェクトを開く
open app/OtetsudaiCoin.xcodeproj

# コマンドラインでビルド
xcodebuild -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### テスト実行
```bash
# 全テスト実行
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 15'

# 特定のテストクラス実行
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:OtetsudaiCoinTests/OtetsudaiCoinTests

# 特定のテストメソッド実行  
xcodebuild test -project app/OtetsudaiCoin.xcodeproj -scheme OtetsudaiCoin -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:OtetsudaiCoinTests/OtetsudaiCoinTests/testExample
```

## アーキテクチャ

### Core Dataスタック
- **PersistenceController**: NSPersistentContainerを管理するシングルトン
- **データモデル**: `OtetsudaiCoin.xcdatamodeld`でItemエンティティを定義
- **コンテキスト注入**: SwiftUI環境でviewContextを管理

### レイヤー構成
- **Presentation Layer**: SwiftUIビュー（MVVM パターン）
- **Domain Layer**: ビジネスロジックとエンティティ
- **Data Layer**: Core Data永続化層

## 一般ルール
- 回答は全て日本語で作成してください。
- ユーザから今回限りでなく、常に対応が必要と思われる指示を受けた場合、ユーザにこれを標準ルールにするか質問してください。YESの場合、CLAUDE.mdに追加ルールを記載してください。このプロセスにより、プロジェクトルールを継続的に改善してください。

## 開発ルール
- SwiftUI,MVVM,クリーンアーキテクチャを採用し、TDDのプロセスに従ってイテレーティブに開発を進めてください。
- できる限り、TDDのプロセスに厳格に従い、テストを一つずつ書きながら開発を進めてください。
- 適宜、リファクタリングを実施し、コードをクリーンに保ってください。
- テストがグリーンになったタイミングで、適宜コミットをしてください。
- SwiftUIのView追加時もユニットテストを書いてください。ViewInspectorを使う想定です。
- ViewInspectorなど、ライブラリはSPMで管理してください(https://github.com/nalexn/ViewInspector)
- UIテストは開発効率を下げるので、ある程度まとまった機能が実装できたタイミングごとに、ハッピーパスだけのテストを実施してください。
