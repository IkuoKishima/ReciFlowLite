import SwiftUI

struct IngredientBlockHeaderRowView: View {
    @ObservedObject var store: IngredientEngineStore
    let block: IngredientBlock

    var body: some View {
        HStack(spacing: 10) {

            // タイトル（今は表示だけ。次段で TextField 化してOK）
            Text(block.title.isEmpty ? "合わせ調味料" : block.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // ✅ blockItem追加（ヘッダー起点）
            Button {
                store.addBlockItem(blockId: block.id)
            } label: {
                Image(systemName: "plus")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle()) // 行全体の当たりを安定
    }
}
