///  GlassIconButton.swift

import SwiftUI

struct GlassIconButton: View {
    let symbol: String
    let action: () -> Void

    private let size: CGFloat = 30
    private let ring: CGFloat = 1.4

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.primary)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background {
            // ✅ 中身は塗らない（円盤を作らない）
            Circle().fill(Color.clear)

            // ✅ ガラスは「縁」だけ
                .overlay {
                    Circle().strokeBorder(
                        // 外周ハイライト（上側が少し明るいと“曲率”が出る）
                        LinearGradient(
                            colors: [
                                .white.opacity(isPreview ? 0.22 : 0.14),
                                .white.opacity(isPreview ? 0.08 : 0.05),
                                .white.opacity(0.00)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: ring
                    )
                }

            // ✅ 外側の落ち影（ガラスが浮いて見える）
                .shadow(color: .black.opacity(isPreview ? 0.18 : 0.12),
                        radius: isPreview ? 10 : 8, y: isPreview ? 5 : 4)

            // ✅ もう一段だけ “薄い” エッジ（輪郭が安定する）
                .overlay {
                    Circle().strokeBorder(.white.opacity(isPreview ? 0.10 : 0.06), lineWidth: 0.8)
                }

                .compositingGroup()
        }
        .clipShape(Circle())
    }
}

////ビルドせずに試す場合の表示法
//#Preview("GlassIconButton – Quick") {
//    ZStack {
//        LinearGradient(colors: [.black, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
//            .ignoresSafeArea()
//
//        HStack(spacing: 18) {
//            GlassIconButton(symbol: "keyboard.chevron.compact.down") {}
//            GlassIconButton(symbol: "chevron.up") {}
//            GlassIconButton(symbol: "chevron.left") {}
//            GlassIconButton(symbol: "chevron.right") {}
//            GlassIconButton(symbol: "chevron.down") {}
//        }
//    }
//}



#Preview("GlassIconButton – Variations") {
    GlassIconButtonPreviewGallery()
}

/// Preview専用：背景を変えて“透過感”を比較する
private struct GlassIconButtonPreviewGallery: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {

                previewRow(title: "Light (plain)") {
                    Color.white
                }

                previewRow(title: "Light (pattern)") {
                    LinearGradient(
                        colors: [.white, .gray.opacity(0.25), .white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Stripes()
                            .opacity(0.08)
                    )
                }

                previewRow(title: "Dark") {
                    LinearGradient(
                        colors: [.black, .black.opacity(0.7), .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

                previewRow(title: "Mid (beige like your app)") {
                    Color(red: 0.93, green: 0.87, blue: 0.80)
                }
            }
            .padding(18)
        }
    }

    @ViewBuilder
    private func previewRow(title: String, background: @escaping () -> some View) -> some View {
        ZStack {
            background()
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 18) {
                GlassIconButton(symbol: "keyboard.chevron.compact.down") {}
                GlassIconButton(symbol: "chevron.up") {}
                GlassIconButton(symbol: "chevron.left") {}
                GlassIconButton(symbol: "chevron.right") {}
                GlassIconButton(symbol: "chevron.down") {}
            }
        }
        .overlay(alignment: .topLeading) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(10)
        }
    }
}

/// 斜線パターン（Preview用）
private struct Stripes: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { p in
                let step: CGFloat = 14
                var x: CGFloat = -h
                while x < w + h {
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x + h, y: h))
                    x += step
                }
            }
            .stroke(.black.opacity(0.5), lineWidth: 1)
        }
    }
}
