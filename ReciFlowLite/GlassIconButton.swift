///  GlassIconButton.swift

import SwiftUI

struct GlassIconButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
