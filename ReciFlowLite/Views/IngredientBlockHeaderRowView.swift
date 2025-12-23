/// MARK: - IngredientBlockHeaderRowView.swift
///
import SwiftUI

struct IngredientBlockHeaderRowView: View {
    @ObservedObject var store: IngredientEngineStore
    let block: IngredientBlock
    let onInserted: (Int) -> Void

    private let plusXRatio: CGFloat = 0.60 //ボタンの距離

    private var titleBinding: Binding<String> {
        Binding(
            get: { store.titleForBlock(block.id) },
            set: { store.updateBlockTitle(block.id, $0) }
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {

                VStack {
                    Spacer() // ← 上にスペースを押し込む

                    TextField("GroupTitle", text: titleBinding)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .baselineOffset(-1.5) // 下寄せの「沈み量」微調整はこれが最適

                Button {
                    let inserted = store.addBlockItemAtBlockRail(blockId: block.id)
                    onInserted(inserted)
            #if DEBUG
                    print("✅ header plus tapped blockId=\(block.id) inserted=\(inserted)")
            #endif
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(.secondary.opacity(0.40), lineWidth: 1.1)

                        Circle()
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                            .padding(1.0) // ほんの少し内側に

                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial.opacity(0.25))
                    .clipShape(Circle())
                }


                .buttonStyle(.plain)
                .contentShape(Circle()) // タップ判定を丸に合わせる（任意）
                .position(x: geo.size.width * plusXRatio,
                          y: geo.size.height / 2)
            }

            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .frame(height: 30)
        .padding(.vertical, 2)
    }
}

#if DEBUG
#Preview("BlockHeaderRow - Solo") {
    let store = IngredientEngineStore(parentRecipeId: UUID())
    let block = IngredientBlock(
        id: UUID(),
        parentRecipeId: store.parentRecipeId,
        orderIndex: 0,
        title: "" //実際の文字入力
    )

    // ✅ Bindingがstore.rowsを参照するので、ここが必須
    store.rows = [.blockHeader(block)]

    return IngredientBlockHeaderRowView(
        store: store,
        block: block,
        onInserted: { _ in }
    )
    .padding()
    .background(Color.yellow.opacity(0.1))
//    .overlay(Rectangle().stroke(.red.opacity(0.6), lineWidth: 1))
}
#endif
