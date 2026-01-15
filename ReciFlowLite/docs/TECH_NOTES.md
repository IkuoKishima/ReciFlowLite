# Tech Notes: release-1.1.0

## Navigation / Dock
- 目的：入力の流れを止めずに、素早く移動できる導線を確保する
- 方針：Dockは「使わなくても良い」補助UI。主要導線を邪魔しない
- 安定化：フォーカス更新のループ防止、遷移前のフォーカス解除、キーボードdismissの統一
- 影響範囲：IngredientEngine（縦遷移/横遷移/レール）
