/// MARK: - RecipeEditView.swift

import SwiftUI

struct RecipeEditView: View {
    @ObservedObject var store: RecipeStore
    let recipeId: UUID
    @Binding var path: [Route]

    @State private var title: String = ""
    @State private var memo: String = ""

#if DEBUG
    private static func _debugBodyTick() -> Bool {
        print("[DEBUG] Edit body tick")
        return true
    }
#endif

    @MainActor
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
    

    var body: some View {
#if DEBUG
        let _ = Self._debugBodyTick()
#endif
        let recipe = store.recipe(for: recipeId)

        ZStack {
            // ✅ うっすら“紙”背景（真っ白回避）
            PaperBackground()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {

                // ✅ タイトル：四角枠を廃止してノート見出しっぽく
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Title", text: $title)
                        .font(.title2.weight(.semibold))
                        .textFieldStyle(.plain)
                        .padding(.vertical, 6)

                    // 下線（ノート感）
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.secondary.opacity(0.35))
                }
                .padding(.horizontal, 2)

                if let r = recipe {
                    RecipeMetaStrip(createdAt: r.createdAt, updatedAt: r.updatedAt)
                }

                // ✅ 作り方：紙カード + 罫線で“白いだけ”を消す
                ZStack(alignment: .topLeading) {
                    LinedPaperBackground(lineSpacing: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    TextEditor(text: $memo)
                        .font(.body)
                        .scrollContentBackground(.hidden) // TextEditor の白背景を消す
                        .padding(12)

                    if memo.isEmpty {
                        Text("作りかた")
                            .foregroundStyle(.secondary)
                            .padding(.top, 20)
                            .padding(.leading, 18)
                    }
                }
                .frame(minHeight: 220)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.secondary.opacity(0.18), lineWidth: 1)
                }

                Spacer()
            }
            .padding(16)
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("RecipeName")

        .onAppear {
#if DEBUG
            print("[DEBUG] Edit onAppear start")
#endif
            if let r = recipe {
                title = r.title
                memo  = r.memo
            }
        }
        .onChange(of: title) { _, newValue in
            store.updateRecipeMeta(recipeId: recipeId, title: newValue, memo: memo)
        }
        .onChange(of: memo) { _, newValue in
            store.updateRecipeMeta(recipeId: recipeId, title: title, memo: newValue)
        }
        

        // 右ドックはそのまま
        .overlay(alignment: .topTrailing) {
                    
            UIKitRightDock(
                mode: .forward,
                showsDelete: false,
                showsAdd: false,
                showsKeyboardDismiss: true,
                isDeleteMode: false,
                onToggleDelete: { },
                onHome: {
                    dismissKeyboard()
                    path = []
                },
                onPrimary: {
                    dismissKeyboard()
                    path.append(.engine(recipeId))
                },
                onAddBlock: { },
                onAddSingle: { },

                onSwipeLeft: {
                    dismissKeyboard()
                    path.append(.engine(recipeId))
                },
                onSwipeRight: { },

                //UIKit配置パラメータ
                railWidth: 38,
                buttonSize: 38,
                trailingPadding: 11,
                verticalSpacing: 16,
                centerYRatio: 0.26,
                minBottomPadding: 6,

                showsPrimary: true,
                showsHome: true
            )
            .frame(width: 44)//⚠️背面干渉回避
            .ignoresSafeArea(.keyboard, edges: .bottom)//SafeArea管理
        }
    }
  
    
    // MARK: - 書式デザイン
    private struct PaperBackground: View {
        var body: some View {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.92),
                    Color(.secondarySystemBackground).opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay {
                // うっすらビネット（端が少し締まる）
                RadialGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(0.06)
                    ],
                    center: .center,
                    startRadius: 80,
                    endRadius: 520
                )
                .blendMode(.multiply)
            }
        }
    }
    
    
    private struct LinedPaperBackground: View {
        var lineSpacing: CGFloat = 26

        var body: some View {
            GeometryReader { geo in
                ZStack {
                    // 紙面
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial.opacity(0.65))

                    // 罫線
                    Path { path in
                        var y: CGFloat = 18
                        while y < geo.size.height {
                            path.move(to: CGPoint(x: 12, y: y))
                            path.addLine(to: CGPoint(x: geo.size.width - 12, y: y))
                            y += lineSpacing
                        }
                    }
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }
            }
        }
    }
}
