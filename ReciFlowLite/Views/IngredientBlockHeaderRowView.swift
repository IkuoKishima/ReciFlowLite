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
//                .frame(maxWidth: .infinity, alignment: .leading)

            // ✅ blockItem追加（ヘッダー起点）
            Button {
                let inserted = store.addBlockItem(blockId: block.id) // ✅ このブロック限定
                onInserted(inserted)                                 // ✅ 追加直後に選択更新
                #if DEBUG
                print("✅ header plus tapped blockId=\(block.id)")
                #endif
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 26, height: 26)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            Spacer(minLength: 0) // ✅ これで右端に押し出さない
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle()) // 行全体の当たりを安定
    }
}
