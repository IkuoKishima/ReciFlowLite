///  GlassIconButton.swift
///  重要⚠️責務分離：ここでは色を決めない

import SwiftUI

struct GlassIconButton: View {
    let symbol: String
    let action: () -> Void

    /// 当たり判定（固定で44など）
    var hitSize: CGFloat = 44

    /// 見た目のガラス球（ここを34にすると“小さく見える”）
    var visualDiameter: CGFloat = 44

    /// アイコン色
    var symbolColor: Color = .primary   // ← デフォルトを付けるのが肝

    /// アイコン枠（visualに連動させる：30固定ではなく比率）
    private var iconBox: CGFloat { visualDiameter * (30.0 / 44.0) }

    /// リング線幅（これも比率で縮む）
    private var ringWidth: CGFloat { visualDiameter * (3.4 / 44.0) }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(symbolColor)   // ここが本体
                .font(.system(size: visualDiameter * (22.0 / 44.0), weight: .semibold))
                .frame(width: iconBox, height: iconBox)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(width: hitSize, height: hitSize)
        .background {
            glassBody(d: visualDiameter)
                .frame(width: visualDiameter, height: visualDiameter)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func glassBody(d: CGFloat) -> some View {
        let rw = ringWidth
        let ringInset = d * (0.4 / 44.0)
        let ringOutset = d * (1.2 / 44.0)
        let cut = rw * 2.2

        ZStack {
            Circle().fill(Color.clear)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(isPreview ? 0.01 : 0.06),
                            .white.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: d * 0.20,
                        endRadius: d * 0.52
                    )
                )
                .blendMode(.plusLighter)
                .opacity(0.9)
                .overlay {
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .white.opacity(0.0), location: 0.00),
                                    .init(color: .white.opacity(isPreview ? 0.40 : 0.26), location: 0.07),
                                    .init(color: .white.opacity(0.0), location: 0.30),
                                    .init(color: .white.opacity(0.0), location: 0.54),
                                    .init(color: .white.opacity(isPreview ? 0.32 : 0.22), location: 0.62),
                                    .init(color: .white.opacity(0.0), location: 0.86),
                                ]),
                                center: .center,
                                angle: .degrees(-35)
                            ),
                            lineWidth: rw
                        )
                        .blendMode(.screen)
                        .frame(
                            width: d - ringInset + ringOutset,
                            height: d - ringInset + ringOutset
                        )
                        .mask {
                            ZStack {
                                Circle().frame(width: d, height: d)
                                Circle()
                                    .frame(width: d - cut, height: d - cut)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                        }
                }
                .blendMode(.screen)
        }
        .compositingGroup()
        .clipShape(Circle())
    }
}

// MARK: - プレビュー

#Preview("GlassIconButton – Variations") {
    GlassIconButtonPreviewGallery()
}

/// Preview専用：背景を変えて“透過感”を比較する
private struct GlassIconButtonPreviewGallery: View {

    // 見た目の外径（ガラス球の直径）
    private let diameter: CGFloat = 44

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
                GlassIconButton(
                    symbol: "keyboard.chevron.compact.down",
                    action: { /* ... */ },
                    hitSize: 44,
                    visualDiameter: 34
                )
                GlassIconButton(
                    symbol: "chevron.up",
                    action: { /* ... */ },
                    hitSize: 44,
                    visualDiameter: 34
                )
                GlassIconButton(
                    symbol: "chevron.left",
                    action: { /* ... */ },
                    hitSize: 44,
                    visualDiameter: 34
                )
                GlassIconButton(
                    symbol: "chevron.right",
                    action: { /* ... */ },
                    hitSize: 44,
                    visualDiameter: 34
                )
                GlassIconButton(
                    symbol: "chevron.down",
                    action: { /* ... */ },
                    hitSize: 44,
                    visualDiameter: 34
                )
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
