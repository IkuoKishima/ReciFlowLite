## Recipe 状態定義（暫定）
- draft　(草案)
  - title が空 or "New Recipe"
  - ingredients が空
  - 作成直後・未完成

- editing　(編集)
  - Edit / Engine に滞在中
  - 入力途中（完成とは限らない）

- completed (完成)
  - title が空でない
  - ingredients が1つ以上


## 画面責務

### RecipeListView
- レコードの存在を俯瞰する
- 並び・状態を判断する
- 編集はしない

### RecipeEditView
- レシピのメタ情報を編集
  - title
  - memo
  - created / updated
- Engine への入口

### IngredientEngineView
- 内容入力に集中
- 速度最優先
- 画面遷移ロジックは持たない
