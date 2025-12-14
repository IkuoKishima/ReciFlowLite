import Foundation

final class IngredientEngineStore: ObservableObject {
    @Published var rows: [IngredientRow] = []
    
    
    func seedIfNeeded() {
        if rows.isEmpty {
            rows = [
                .single(.init(name: "Salt", amount: "1", unit: "tsp"))
            ]
        }
    }

    
    
    
    
    
}

enum IngredientRow: Identifiable, Equatable {
    case single(IngredientItem)
    case blockHeader(IngredientBlock)
    case blockItem(IngredientItem)

    var id: UUID {
        switch self {
        case .single(let i): return i.id
        case .blockHeader(let b): return b.id
        case .blockItem(let i): return i.id
        }
    }
}

struct IngredientItem: Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var amount: String = ""
    var unit: String = ""
}

struct IngredientBlock: Identifiable, Equatable {
    var id: UUID = UUID()
    var title: String = ""
}




