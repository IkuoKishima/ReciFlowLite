import SwiftUI

struct ContentView: View {
    @StateObject private var store = RecipeStore()
    
    var body: some View {
        NavigationStack {
            RecipeListView(store: store)
        }
    }
}

#Preview {
    ContentView()
}
