/// MARK: - LoadingView.swift

import SwiftUI

/// 起動時ローディング（写真＋控えめProgress）
struct LoadingView: View {

    /// アセット名（Assets.xcassets に入れた画像名）
    let imageName: String

    /// 表示テキスト（不要なら空文字に）
    var title: String = "ReciFlow"

    /// ローディング中フラグ（trueの間表示）
    @Binding var isLoading: Bool

    var body: some View {
        ZStack {
            // 背景写真
            Image(imageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            // 読みやすさのための薄いベール（やりすぎない）
            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // UI（控えめ）
            VStack {
                Spacer()

                // タイトル（主張しすぎない）
                if !title.isEmpty {
                    Text(title)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(radius: 8, y: 2)
                        .padding(.bottom, 10)
                }

                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white.opacity(0.9))

                    Text("Loading…")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(radius: 10, y: 3)
                .padding(.bottom, 34)
            }
        }
        // ✅ ローディング中は誤タップ防止
        .allowsHitTesting(!isLoading)// or .allowsHitTesting(false)（ロード画面中は常に無効でいいなら）
        .accessibilityAddTraits(.isModal)
    }
}
