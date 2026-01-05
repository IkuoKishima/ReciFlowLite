
| プロトコル名   | 目的                         | 使う場面               |
| ----------- | ------------------           | ---------------      |
| Identifiable| 一意のIDで識別できる            | ForEachで一覧表示する時  |
| Equatable   | @Binding で編集が必要なとき Equatable で比較が必要になる   |
| Codable     | JSON変換保存可能にする
| Hashable    | 辞書のキー・セットで使える・重複回避| 集合演算・検索          |


ContentView 　　「玄関ホール」
NavigationStack「アプリ全体の廊下」
RecipeListView 「レシピの一覧」
RecipeEditView 「編集ページ」
IngredientEngineView は、この編集画面の中に後から入れる“コンポーネント”
つまり、
ナビゲーションで繋ぐのは「画面」と「画面」
エンジンは「画面の中身」として置く
（エンジンそのもので画面遷移はしない）

って構造。




🟨@ObservedObject var store: RecipeStore
「このビューは store の変化を購読します」という宣言
監視しているのは SwiftUI 側 で、
@ObservedObject は「このオブジェクトを監視対象にしてください」と SwiftUI に宣言している感じ

🟨@Published var recipes: [Recipe] と書くことで、
recipes が変わるたびに 「変わったよ！」という通知の波 を出す
その波を受け取って SwiftUI が body を描き直す

🟨RecipeEditView は Binding<Recipe> を受け取る
編集画面で recipe.title を書き換えると
その変更は 直接 store.recipes[index] に反映される
すると @Published が「変わったよ」と通知
RecipeListView 側のリストも自動で最新に更新されて見える


実際のパターンを一行で整理すると

List / 一覧側のプレビュー　➡️ RecipeListView(store: .preview) みたいに「束（Store）」を渡す

Edit / 編集側のプレビュー　指定レコード一本だけ見れればいいので　➡️ RecipeEditView(recipe: .constant(Recipe.sample)) みたいに「1本だけ渡す」

🟨マイグレーション
