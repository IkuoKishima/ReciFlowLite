// Day7内容🟨当たり判定・右レールドック干渉調整・編集時操作可不可分岐・ブラケット判定入り口全てで扱いやすくする

enum RowRole {
    case single
    case blockHeader
    case blockItem
}
extension IngredientRow {
    var role: RowRole {
        switch self {
        case .single:      return .single
        case .blockHeader: return .blockHeader
        case .blockItem:   return .blockItem
        }
    }
}
ここで同じ箇所の表示を一括りにすることで、
        //🎯当たり制御＋当たり判定
        .allowsHitTesting(row.role != .blockHeader)
        .onTapGesture {
            print("Tapped:", row.role)
書式を担当する箇所で、「その行を触れた時の挙動」を制御できる
ジェスチャー反応をデバッグ通知モニタリングできるようプリントコメントを出せばわかりやすい
ヒットテスティングで「何が触れないか？」を決定づけられる
.allowsHitTesting は、その行に対する 操作（ジェスチャー）の受け渡し自体を止めるスイッチ。
表示は残したまま、挙動だけを role ベースで制御できる。







Engineの視認性：絶対に削れないポイント
1) ✅左右は“限界まで”使う
　・行のコンテンツは maxWidth .infinity
　・行インセット（Listの左右余白）は 最小（またはゼロに近づける）
　・余白のせいで「紙面が狭い」瞬間が出たら、その時点で負け

2) ✅“1枚のノート”を壊すUIを置かない
　・ヘッダー帯・名札帯・余計なツールバーは Engine内に入れない
　・情報は必要なら末尾に静かに（あなたの“静寂”ルール）

3) ✅操作UIは“紙面の外側”へ逃がす
　・右レール（RightRailControls）に集約
　・紙面（材料エリア）を侵食しない→ ドックを入れるとしても 紙面にかぶせない/削らないが前提

4) ✅体感速度＝哲学（広告ゼロ思想）
　・Gesture / ボタン反応は最短距離
　・もたつきは「機能不足」ではなく「思想違反」

あなたが言うザッカーバーグの話、まさにこれで、
“邪魔がないこと”が機能そのものになってる。

⚠️実装面での「落とし穴」だけ先に共有
Engineを「1枚ノート」にする時、敵はだいたいこの2つです。
　⚠️・List のデフォルト余白（左右インセット）
　⚠️・Safe Area + overlay の取り方で “紙面が削れる”

ここを潰せば、v15の思想に寄せられます。
