/// MARK: - Route.swift

import Foundation

enum Route: Hashable {
    case edit(UUID)        // recipeId
    case engine(UUID)      // recipeId
}
