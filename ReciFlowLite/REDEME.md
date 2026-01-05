# ReciFlowLite

現場で使える「レシピ記録・検索」アプリ（iOS専用）。
素早い入力導線と、材料入力エンジン（IngredientEngine）による編集体験を重視しています。

- App Store: （リンク）
- 対応OS: iOS xx 以降（iPadは除外）
- 開発: Swift / SwiftUI / SQLite3

---

## Features（できること）
- レシピの追加・編集・削除
- 材料入力（IngredientEngine）
- レシピ一覧表示

※Liteは「最小構成で実運用できること」を優先し、段階的に機能拡張します。

---

## Tech Stack（技術）
- Swift / SwiftUI
- SQLite3（ローカル永続化）
- App Store 審査対応（Releaseビルド・ログ制御・最小権限）

---

## Architecture（設計の考え方）
本プロジェクトは責務分離を重視しています。

- View：UI（入力・表示）
- Store：状態管理（ObservableObject）
- Engine：入力体験のコア（IngredientEngine）
- Persistence：DB（SQLite3）

---

## Release
- `release-1.0.0`：初回リリース（App Store 審査通過版）
- `release-1.1.0`：操作導線改善（縦遷移 + Dock）※予定

詳細は [CHANGELOG.md](./CHANGELOG.md) を参照してください。

---

## How to Build
1. Xcode xx で `ReciFlowLite.xcodeproj` を開く
2. 実機 or シミュレータで実行

（必要なら注意点：DBファイル場所、初回起動、デバッグ設定など）
