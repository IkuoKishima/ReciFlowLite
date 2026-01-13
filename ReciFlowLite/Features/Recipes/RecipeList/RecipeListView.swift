/// MARK: - RecipeListView.swift

import SwiftUI

struct RecipeListView: View {
    @ObservedObject var store: RecipeStore
    @Binding var path: [Route]
    
    // エクスポート状態
    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var isExporting = false

    var body: some View {
        ZStack(alignment: .top) {

            // MARK: - リスト表示部分 -
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
                .onDelete { offsets in
                    Task { @MainActor in
                        store.requestDelete(at: offsets)
                    }
                }
            }
            .disabled(store.isLoading)

        }
        .sheet(isPresented: $showShare) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }

        // ✅ 起動ロード中オーバーレイ（全体を覆う）
        .overlay {
            if store.isLoading {
                ZStack {
                    Color.black.opacity(0.08)
                        .ignoresSafeArea()
                        .allowsHitTesting(true)
                    ProgressView("Loading…")
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .transition(.opacity)
            }
        }

        // ✅ 空状態
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
        // ✅ データドック（Export / Import）
        .overlay(alignment: .bottomLeading) {
            DataDockView(
                isLoading: store.isLoading,
                isExporting: isExporting,
                onExport: {
                    Task {
                        isExporting = true
                        defer { isExporting = false }

                        guard let data = await DatabaseManager.shared.makeExportJSONData() else { return }
                        do {
                            let url = try ExportFileWriter.writeTempExportFile(data: data)
                            exportURL = url
                            showShare = true
                        } catch {
                            DBLOG("❌ writeTempExportFile failed: \(error.localizedDescription)")
                        }
                    }
                },
                onImport: {
                    // 今は未実装：将来ここにインポート導線を足す
                }
            )
            .padding(.leading, 18)
            .padding(.bottom, (store.pendingUndo != nil) ? 74 : 18)
            .animation(.easeInOut(duration: 0.18), value: store.pendingUndo != nil)
        }
        // ✅ Undoトースト
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
            GlassIconButton(
                symbol: "square.and.pencil",
                action: {
                    Task {
                        let newId = await store.addNewRecipeAndPersist()
                        await MainActor.run { path.append(.edit(newId)) }
                    }
                },
                hitSize: 46,
                visualDiameter: 46
            )
            .disabled(store.isLoading)
            .opacity(store.isLoading ? 0.3 : 1.0)
            .padding(.trailing, 18)
            .padding(.bottom, (store.pendingUndo != nil) ? 74 : 18)
            .animation(.easeInOut(duration: 0.18), value: store.pendingUndo != nil)
        }
    }
    // バックアップボタン表示部分の追加
    private struct DataDockView: View {
        let isLoading: Bool
        let isExporting: Bool
        let onExport: () -> Void
        let onImport: () -> Void

        var body: some View {
            HStack(spacing: 10) {
                // Export
                GlassIconButton(
                    symbol: isExporting ? "arrow.up.doc.fill" : "arrow.up.doc",
                    action: onExport,
                    hitSize: 44,
                    visualDiameter: 44
                )
                .disabled(isLoading || isExporting)
                .opacity((isLoading || isExporting) ? 0.35 : 1.0)

                // Import（次回予定を “UIで示す”）
                GlassIconButton(
                    symbol: "arrow.down.doc",
                    action: onImport,
                    hitSize: 44,
                    visualDiameter: 44
                )
                .disabled(true)
                .opacity(0.22)
                .overlay(alignment: .topTrailing) {
                    Text("Soon")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        }
                        .offset(x: 6, y: -6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            }
            // 誤タップ防止：土台がヒット領域の境界になる
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(radius: 6, y: 2)
            .accessibilityElement(children: .contain)
        }
    }
}
