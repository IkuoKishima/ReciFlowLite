RightRailControls.swift

画面遷移 RootMemo
【目的】
⚠️画面の「めくり元　x　戻り先ページの　右端」統一で
スワイプ領域を設置し、そのレールを撫でると
画面フォーカス取り合いで遷移のもたつきを軽減できる
この二つのページ遷移のロジックは、開くとき先のページを閉じない、重ねているだけ
だから、進むときは重ねているだけで、戻る時は削るで戻っているように見える
メモリ管理的たくさんのページめくりでは使えない簡易的な記述、実際たくさんのページの時にはonDisappear などで明示的に解放する設計を足せばいい。


１、レール幅を広げる（最優先）
いま railWidth = 28 なら、まず 44〜56 に上げてください。
Apple的にも「タップ領域44pt」は基本なので、これは正当化できます。
private let railWidth: CGFloat = 56   // 28 → 56


DragGesture(minimumDistance: 8)
    .onEnded { value in
        let dx = value.predictedEndTranslation.width
        if dx < -30 {          // 右→左（進む）
            onSwipeLeft()
        } else if dx > 18 {    // 左→右（戻る）※甘め
            onSwipeRight()
        }
    }
    



２、右スワイプ判定だけ “甘く” する
戻りは成立しにくいので、閾値を下げるのが合理的です。
進む：dx < -30（そのまま）
戻る：dx > 18 くらいに緩める


if dx < -30 {
    onSwipeLeft()
} else if dx > 18 {
    onSwipeRight()
}




３、minimumDistance を下げる（軽くすると反応が出やすい）

DragGesture(minimumDistance: 8)
    
    


⚠️レールを一瞬だけ可視化（開発中だけ）
Rectangle().fill(Color.red.opacity(0.05))
これで「タッチできてる領域」が見えるので原因が切り分けできます。
