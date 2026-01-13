import SwiftUI

struct IngredientBlockHeaderRowView: View {
    @ObservedObject var store: IngredientEngineStore
    let block: IngredientBlock
    let onInserted: (Int) -> Void
    // 黒背景での文字色適用
    @EnvironmentObject private var themeStore: ThemeStore
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var router: FocusRouter // フォーカス一本化のため Router を注入

    var perform: (EngineCommand) -> Void = { _ in }
    let nav: SelectAllTextField.Config.Nav //nav常態を持たせないようEngineの共通関数を渡す

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
                        inkColor: UIColor(themeStore.paperStyle.inkColor(scheme: colorScheme)),
                        placeholderColor: UIColor(themeStore.paperStyle.inkColor(scheme: colorScheme)).withAlphaComponent(0.1), //透かし文字
                        config: .init(
                            onCommit: { perform(.enterNext) }, // Enter の扱いは方針次第（とりあえず既存へ）
                            focus: .init(
                                rowId: block.id,
                                field: .headerTitle,
                                onReport: { id, field in
                                    router.reportFocused(rowId: id, field: field)
                                }
                            ),
                            nav: nav // Engine共通関数を設置
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

    // ✅ Preview用のダミーNav（何もしないでOK）
    let previewNav = SelectAllTextField.Config.Nav(
        done: nil,
        up: nil,
        down: nil,
        left: nil,
        right: nil,
        repeatBegan: nil,
        repeatEnded: nil
    )

    return IngredientBlockHeaderRowView(
        store: store,
        block: block,
        onInserted: { _ in },
        router: router,
        perform: { _ in },
        nav: previewNav
    )
    .environmentObject(ThemeStore())
    .padding()
    .background(Color.yellow.opacity(0.1))
}
#endif
