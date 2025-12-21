/// MARK: - RightRailControls.swift

//ドックの代わりを担う共通部品📝ここは秘密にはならない箇所

import SwiftUI

struct RightRailControls: View {
    enum Mode {
        case forward   // > で進む（Edit側）
        case back      // < で戻る（Engine側）
    }

    let mode: Mode

    // ボタンアクション
    
    var showsDelete: Bool = false// ✅ Deleteは「使う画面だけ」ON
    var showsAdd: Bool = true

    
    let isDeleteMode: Bool // ✅ 追加：削除モード
    let onToggleDelete: () -> Void // 🗑️
    
    // ✅ 追加
    let onAddSingle: () -> Void   // ＋
    let onAddBlock: () -> Void    // 2x2
    let onPrimary: () -> Void   // > or <
    let onHome: () -> Void      // 🔳

    // レールスワイプ
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void
    

    private let railWidth: CGFloat = 38 // 28数字を減らすと右のスワイプレールが狭くなるが反応が鈍る
    private let buttonSize: CGFloat = 30

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {

                // ───────── 透明スワイプレール（右端） ─────────
                Rectangle()
                    .fill(Color.red.opacity(0.02))//(.clear)✅着色して領域を見えるようにしている、変更はクリアに差し替えること
                    .frame(width: railWidth)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 4)//🟩値を減らす事でスワイプ反応を機敏にできる
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
                VStack(spacing: 16) {
                    
                    // 🗑 削除モード切替
                    if showsDelete {
                        Button(action: onToggleDelete) {
                            Image(systemName: isDeleteMode ? "minus.circle.fill" : "minus.circle")
                                .font(.title3.weight(.semibold))
                                .frame(width: buttonSize, height: buttonSize)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    
                    // ✅ ＋ single追加
                    if showsAdd {
                        Button(action: onAddSingle) {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .frame(width: buttonSize, height: buttonSize)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        // ✅ 2x2 blockHeader追加
                        Button(action: onAddBlock) {
                            Image(systemName: "square.grid.2x2")
                                .font(.title3.weight(.semibold))
                                .frame(width: buttonSize, height: buttonSize)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    //このボタン押したよーだけを知っている、ボタンデザインの記述
                    Button(action: onPrimary) {
                        Image(systemName: primarySymbol)
                            .font(.title3.weight(.semibold))
                            .frame(width: buttonSize, height: buttonSize)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    //こっちもボタン押されたよーを伝えるボタンデザインの記述
                    Button(action: onHome) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.title3.weight(.semibold))
                            .frame(width: buttonSize, height: buttonSize)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .position(
                    x: geo.size.width - 18,
                    y: geo.size.height * 0.58   // ボタンの配置を決める上から58%（=下から42%）
                )
            }
        }
        .allowsHitTesting(true)
    }
    
    

    //移動先に遷移する処理
    private var primarySymbol: String {
        switch mode {
        case .forward: return "chevron.right"      //Editからエンジンに
        case .back:    return "chevron.left"        //エンジンから前のページに
        }
    }
}
