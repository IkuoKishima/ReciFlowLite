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
                TextField("調合", text: titleBinding)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
                

                Button {
                    let inserted = store.addBlockItemAtBlockRail(blockId: block.id)
                    onInserted(inserted)
#if DEBUG
                    print("✅ header plus tapped blockId=\(block.id) inserted=\(inserted)")
#endif
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 30, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial.opacity(0.25))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .position(x: geo.size.width * plusXRatio, y: geo.size.height / 2)
            }
            .frame(height: 30)
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
        title: "調合preview"
    )

    // ✅ Bindingがstore.rowsを参照するので、ここが必須
    store.rows = [.blockHeader(block)]

    return IngredientBlockHeaderRowView(
        store: store,
        block: block,
        onInserted: { _ in }
    )
    .padding()
    .background(Color.black.opacity(0.03))
    .overlay(Rectangle().stroke(.red.opacity(0.6), lineWidth: 1))
}
#endif
