import SwiftUI

struct IngredientBlockHeaderRowView: View {
    @ObservedObject var store: IngredientEngineStore
    let block: IngredientBlock
    let onInserted: (Int) -> Void

    // ✅ 追加：フォーカス一本化のため Router を注入
    @ObservedObject var router: FocusRouter

    var perform: (EngineCommand) -> Void = { _ in }


    private let plusXRatio: CGFloat = 0.60

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
                    Spacer()

                    // ✅ TextField → SelectAllTextField に置き換え
                    SelectAllTextField(
                        text: titleBinding,
                        placeholder: "GroupTitle",
                        shouldBecomeFirstResponder:
                            router.current?.rowId == block.id &&
                            router.current?.field == .headerTitle,
                        config: .init(
                            onCommit: { perform(.enterNext) }, // Enter の扱いは方針次第（とりあえず既存へ）
                            focus: .init(
                                rowId: block.id,
                                field: .headerTitle,
                                onReport: { id, field in
                                    router.reportFocused(rowId: id, field: field)
                                }
                            ),
                            nav: .init(
                                done:  { perform(.dismissKeyboard) },
                                up:    { perform(.moveUp) },
                                down:  { perform(.moveDown) },
                                left:  { perform(.moveLeft) },
                                right: { perform(.moveRight) }
                            )
                        )
                    )
                    .font(.subheadline.weight(.semibold))           // ※ SelectAllTextField は UITextField なので font は効かない
                    // ↑ もし見た目を揃えたいなら SelectAllTextField に font を渡せる拡張を後でやる（今は一本化優先）
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .baselineOffset(-1.5)

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
                            .padding(1.0)
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial.opacity(0.25))
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
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
        title: ""
    )
    store.rows = [.blockHeader(block)]

    let router = FocusRouter()

    return IngredientBlockHeaderRowView(
        store: store,
        block: block,
        onInserted: { _ in },
        router: router,
        perform: { _ in }
    )
    .padding()
    .background(Color.yellow.opacity(0.1))
}
#endif
