１、 IngredientEngine_v15 が「破綻しない」理由（重要）
　　・鉄則１：横方向の責務が明確
　　　　　[ controlColumn ] [ bracketColumn ] [ content ]
　　　　　・削除・並び替え → controlColumn
　　　　　・ブラケット → bracketColumn
　　　　　・テキストフィールド → rowView / IngredientItemRowView
　　　　　　👉 1列 = 1責務
　　　　　　👉 同じ責務を別の HStack で二重に持たない　　
　　・鉄則2：rowWithControls が「唯一の横レイアウト」
　　　　　　v15 では、
　　　　　　　ScrollView
　　　　　　　VStack
　　　　　　　ForEach
　　　　　　の 中で直接 HStack を組まない、必ず
　　　　　　rowWithControls(for: row, at: index)
　　　　　　に集約されている
　　　　　　👉 これが 「箱の中に箱を作らない」最大の理由です。　

　　・鉄則3：rowView は「中身だけ」
　　　　v15 の rowView はこうです：
　　　　　・余白を作らない
　　　　　・ガターを作らない
　　　　　・高さ・横幅を決めない
　　　　　「その行が何か」だけを表現する View。
　　　


２、 Lite が迷子になる根本原因⚠️（ここが核心）⚠️
Lite では、v15 で 分離されていた責務が混ざっています。
現在 Lite で起きていること

| 場所                 | 本来の役割 | 実際                   |
| ------------------  | -----     | -------------------- |
| `ForEach` 内 HStack | 行の横構造  | ❌ ガターを作っている          |
| `rowView`           | 中身       | ❌ 高さ・余白・contentShape |
| `gutterView`        | 制御列     | ❌ rowView と並列        |
| `leftGutterWidth`   | 予約席     | ❌ gutterView と二重     |
👉 v15 では 1か所だった横構造が、Lite では 4か所に分散しています。

これが、「箱の中に箱を詰めてる感覚」の正体です。


３、 Lite を v15 と同じ見た目にするための「正しい進め方」
🔴 やってはいけないこと
　・Lite 独自のレイアウトを考える
　・spacing / padding を感覚でいじる
　・v15 と Lite を同時に調整する

４、 v15 / Lite 両方に入れるべき可視化の入れ方
