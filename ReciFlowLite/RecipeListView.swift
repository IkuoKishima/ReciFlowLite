/// MARK: - RecipeListView.swift

import SwiftUI

struct RecipeListView: View {
    @ObservedObject var store: RecipeStore
    @Binding var path: [Route]

    var body: some View {
        List {
            ForEach(store.recipes) { recipe in
                Button {
#if DEBUG
                    let t0 = CFAbsoluteTimeGetCurrent()
                    print("[DEBUG] tap row start", recipe.id)
#endif
                    path.append(.edit(recipe.id))
#if DEBUG
                    print("[DEBUG] tap row end", CFAbsoluteTimeGetCurrent() - t0)
#endif
                } label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.title.isEmpty ? "New Recipe" : recipe.title)
                                .font(.headline)
                            Text("Updated: \(recipe.updatedAt.formatted(date: .numeric, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
            }
            // ✅ 削除
            .onDelete { offsets in
                Task { @MainActor in
                    store.requestDelete(at: offsets)
                }
            }
        }
        // 👇 List 自体を無効化
        .disabled(store.isLoading)

        // ✅ 起動ロード中オーバーレイ（List全体を覆う）
        .overlay {
            if store.isLoading {
                ZStack {
                    Color.black.opacity(0.08)
                        .ignoresSafeArea()
                        .allowsHitTesting(true) // うっかり指を触れた感も消しておく
                    ProgressView("Loading…")
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .transition(.opacity)
            }
        }
        
        
        // ✅ 空状態（初回ユーザー対策）
        .overlay {
            if !store.isLoading && store.recipes.isEmpty {
                ContentUnavailableView {
                    Label("レシピを記録しましょう", systemImage: "pencil.and.outline")
                } description: {
                    Text("Carve the recipe into memory")
                } actions: {
                    Button {
                        Task {
                            let newId = await store.addNewRecipeAndPersist()
                            await MainActor.run { path.append(.edit(newId)) }
                        }
                    } label: {
                        Label("最初のレシピを作る", systemImage: "square.and.pencil")
                    }
                }
                .padding(.horizontal, 24)
                .transition(.opacity)
            }
        }


        // ✅ Undoトースト（下部）
        .overlay(alignment: .bottom) {
            if store.pendingUndo != nil {
                HStack {
                    Text("Deleted")
                        .font(.callout)

                    Spacer()

                    Button("Undo") {
                        Task { @MainActor in
                            store.undoDelete()
                        }
                    }
                    .font(.callout.weight(.semibold))
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }

        // ✅ 追加ボタン
        .overlay(alignment: .bottomTrailing) {
            Button {
                Task {
                    let newId = await store.addNewRecipeAndPersist()
                    await MainActor.run { path.append(.edit(newId)) }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                    Circle()
                        .strokeBorder(.black.opacity(0.10), lineWidth: 0.5)

                    Image(systemName: "square.and.pencil")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 46, height: 46)
            }

            .disabled(store.isLoading)
            .opacity(store.isLoading ? 0.3 : 1.0)
            .padding(.trailing, 18)
            // ✅ Undoが出ている間だけボタンを上へ逃がす
            .padding(.bottom, (store.pendingUndo != nil) ? 74 : 18)
            .animation(.easeInOut(duration: 0.18), value: store.pendingUndo != nil)

        }

    }
}
