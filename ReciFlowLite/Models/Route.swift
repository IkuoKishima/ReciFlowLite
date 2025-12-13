//ナビゲーション用のルーター　List → Edit → Engine みたいな ページ移動

import Foundation

enum Route: Hashable {
    case edit(UUID)        // recipeId
    case engine(UUID)      // recipeId
}
