/// MARK: - IngredientBlockHeaderRowView.swift

import SwiftUI

struct IngredientBlockHeaderRowView: View {
    @ObservedObject var store: IngredientEngineStore
    let block: IngredientBlock
    let onInserted: (Int) -> Void   // ＋ボタンを押してからアイテムが追加されたようにする為、通知を受け取れる形にする

    var body: some View {
        HStack(spacing: 8) {

            // タイトル（今は表示だけ。次段で TextField 化してOK）
            Text(block.title.isEmpty ? "合わせ調味料" : block.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            // ✅ blockItem追加（ヘッダー起点）
            Button {
                // ✅ v15方式：block rail を使って「このブロックの＋」を安定させる
                let inserted = store.addBlockItemAtBlockRail(blockId: block.id)
                // ✅ UI側の選択（selectedIndex）を追従させる
                onInserted(inserted)

                #if DEBUG
                print("✅ header plus tapped blockId=\(block.id) inserted=\(inserted)")
                #endif
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 26, height: 26)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0) // ✅ 左寄せに固定する
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())

    }
}
