//ドックの代わりを担う共通部品
import SwiftUI

struct RightRailControls: View {
    enum Mode {
        case forward   // > で進む（Edit側）
        case back      // < で戻る（Engine側）
    }

    let mode: Mode

    // ボタンアクション
    let onPrimary: () -> Void   // > or <
    let onHome: () -> Void      // 🔳

    // レールスワイプ
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    private let railWidth: CGFloat = 56 // 28数字を減らすと右のスワイプレールが狭くなるが反応が鈍る
    private let buttonSize: CGFloat = 54

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {

                // ───────── 透明スワイプレール（右端） ─────────
                Rectangle()
                    .fill(.clear)
                    .frame(width: railWidth)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 4)//値を減らす事でスワイプ反応を機敏にできる
                            .onEnded { value in
                                let dx = value.predictedEndTranslation.width
                                if dx < -30 {      // 右→左
                                    onSwipeLeft()
                                } else if dx > 18 { // 左→右
                                    onSwipeRight()
                                }
                            }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                // ───────── 右端55〜60%：縦2段ボタン ─────────
                VStack(spacing: 10) {
                    Button(action: onPrimary) {
                        Image(systemName: primarySymbol)
                            .font(.title3.weight(.semibold))
                            .frame(width: buttonSize, height: buttonSize)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Button(action: onHome) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.title3.weight(.semibold))
                            .frame(width: buttonSize, height: buttonSize)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .position(
                    x: geo.size.width - 28,
                    y: geo.size.height * 0.58   // 上から58%（=下から42%）
                )
            }
        }
        .allowsHitTesting(true)
    }

    private var primarySymbol: String {
        switch mode {
        case .forward: return "chevron.right"
        case .back:    return "chevron.left"
        }
    }
}
