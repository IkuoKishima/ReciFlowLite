/// MARK: - PaperPickerSheet.swift

import SwiftUI

struct PaperPickerSheet: View {
    @ObservedObject var themeStore: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            List {
                ForEach(PaperStyle.allCases) { style in
                    Button {
                        themeStore.paperStyle = style
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(style.paperColor(scheme: scheme))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))

                            Text(style.title)

                            Spacer()

                            if themeStore.paperStyle == style {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("紙色")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
