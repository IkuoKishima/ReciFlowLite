//ここではストアが新規レコード追加をどうおこなっているかを書いている


✅レコード追加が、上の状態にすると末尾追加になり、下の記述にすると先頭追加になる
recipes.append(new)

recipes.insert(new, at: 0)



    func addNewRecipeAndPersist() -> UUID {
        let now = Date()
        let title = "New \(now.formatted(date: .numeric, time: .shortened))" //足されるものに日付と時間を追加している

        let new = Recipe(
            id: UUID(),
            title: title,
            memo: "",
            createdAt: now,
            updatedAt: now
        )
        ✅recipes.insert(new, at: 0) // ここの書き換えで先頭追加から末尾追加に変わる、リストの性質上上から下表示なので、ここで変更せずクエリで抽出にする
        ❌recipes.append(new) // ここの書き換えで先頭追加から末尾追加に変わる

        DatabaseManager.shared.insert(recipe: new)
        return new.id
    }



✅ 最初に設計した時のタイムスタンプ、更新時間が、「閲覧した時」になっていた問題　ー　で囲った箇所は、下の元あった記述は
開いた時にその日を返す書き方から、下の内容に「変更が加わった時だけ」タイムスタンプを返す分岐を追加した

recipes[idx].title = title.isEmpty ? "New Recipe" : title
recipes[idx].memo = memo
recipes[idx].updatedAt = Date()
DatabaseManager.shared.update(recipe: recipes[idx])
　　　　　　　　　　　　　↓

    func updateRecipeMeta(recipeId: UUID, title: String, memo: String) {
        guard let idx = recipes.firstIndex(where: { $0.id == recipeId }) else { return }
        ---------------------------------------------------------------------
        let newTitle = title.isEmpty ? "New Recipe" : title
        let newMemo  = memo

        let hasChanged =
            recipes[idx].title != newTitle ||　⬅️ ✅　この「比較演算子　!=」が、状態変化を検知している、それによって「オートセーブ」できている
            recipes[idx].memo  != newMemo

        guard hasChanged else { return }   // 内容が変わった時だけタイムスタンプ更新

        recipes[idx].title = newTitle
        recipes[idx].memo  = newMemo
        recipes[idx].updatedAt = Date()

        DatabaseManager.shared.update(recipe: recipes[idx])
        -----------------------------------------------------------------------

    }

✅　Storeに保持されたoldデータと、操作入力newデータの比較(!=)をし　hasChanged = true そして更新
✅　AまたはB （ A || B )
