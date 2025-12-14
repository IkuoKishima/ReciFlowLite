1) overlay＝「上に1枚かぶせたパネル」で合ってる
　List {...}.overlay(...) は リスト全体の上に1枚のレイヤーを載せてるイメージでOK。
　「一つだけ」というのは overlay自体が1回という意味で、
　その中にボタンを2個でも3個でも置けます（VStackでもHStackでもOK）。

2) Toolbar提案の意味も合ってる
　overlayで実現できるなら overlayでOK
　toolbarは 安全域・既定のUI領域なので、衝突や誤爆が少なく実装も速い
　→「困ったら逃げられる手段」として提案した、で合ってます。


⚠️画面のタップ領域について
        List {
            ForEach(store.recipes) { recipe in
                Button { path.append(.edit(recipe.id)) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title.isEmpty ? "New Recipe" : recipe.title)
                            .font(.headline)
                        Text("Updated: \(recipe.updatedAt.formatted(date: .numeric, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)//ここで押せる領域を全体に広げるが、List内部余白で広がり切らないことがあるので
                    .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))//この行を追加し、もっと左右を押せるように拡げる
                    .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle()) // ✅ 行全体タップ
            }
        }
        
このようにして.listRowInsetsによって領域を押し広げようとしても、これ、Listの「行（row）」に対する修飾子なので、label の中の VStack に付けても効かない。
（= 行の幅やタップ領域の土台自体が変わってない）
結果として、
　・タップ領域が 文字や日付の“実サイズ（intrinsic size）” 付近に寄る
　・タイトルが短いほど「当たり判定が狭い」ように見える
　・日付行があると下側の“文字があるところ”だけ反応してるように感じる
　
なので、画面の左右８割どこでも押せるようにしたいなら、ラベルを確実に左右に広げる必要がある。

List {
    ForEach(store.recipes) { recipe in
        Button {
            path.append(.edit(recipe.id))
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title.isEmpty ? "New Recipe" : recipe.title)
                        .font(.headline)
                    Text("Updated: \(recipe.updatedAt.formatted(date: .numeric, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0) // ← これが「右側まで当たり判定」を作る決定打
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle()) // ← “行全体”を当たり判定に
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)) // ← ここに置く
    }
}

これで何が変わる？
　✅HStack が行の横幅を取りにいく
　✅Spacer が「空白部分」も行の一部にする
　✅contentShape が「見えない空白もタップ可能」にする
つまり、タイトルが短くても長くても、当たり判定は常に横いっぱいになる。
あと、先のコードのように .contentShape(Rectangle()) を Button に付けると、「ボタン自体のサイズ」が狭いままだと contentShape も狭いので
List内では label側に付けるのが安定する（上の例の位置）。
