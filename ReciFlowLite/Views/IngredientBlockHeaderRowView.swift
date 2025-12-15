import SwiftUI

struct IngredientBlockHeaderRowView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(height: 36)                 // ← single と同じ
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)             // ← single より少しだけ内側
    }
}
