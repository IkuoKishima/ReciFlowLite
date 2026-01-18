/// MARK: - RecipeListView.swift

import SwiftUI

struct RecipeListView: View {
    @ObservedObject var store: RecipeStore
    @Binding var path: [Route]
    
    // エクスポート状態
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var showExportPicker = false
    @State private var exportErrorMessage: String?
    @State private var showExportError = false
    @State private var exportPreviewText: String = ""
    @State private var showExportPreview = false
    @State private var pendingExportURL: URL?
    @State private var exportJustCreatedAt: Date?
    @State private var exportAlertTitle: String = "エクスポート"



    private let baseBottomPadding: CGFloat = 18
    // トーストの見た目サイズ（概算）
    // Text + padding(12) + corner + shadow を含めて少し多めに確保
    private let undoToastLift: CGFloat = 80   // ← ここを調整ポイント（80〜96くらい）

    
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
        .sheet(isPresented: $showExportPicker) {
            if let url = exportURL {
                ExportDocumentPicker(fileURL: url) { saved in
                    Task { @MainActor in
                        showExportPicker = false
                        exportAlertTitle = saved ? "エクスポート完了" : "エクスポート"
                        exportErrorMessage = saved ? "保存しました ✅" : "キャンセルしました"
                        showExportError = true
                        exportURL = nil
                        pendingExportURL = nil
                    }
                }
            }
        }

        .alert(exportAlertTitle, isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "不明なエラー")
        }
        
        .alert("エクスポート確認", isPresented: $showExportPreview) {
            Button("キャンセル", role: .cancel) {
                pendingExportURL = nil
                exportJustCreatedAt = nil
            }
            Button("保存先を選ぶ") {
                guard let p = pendingExportURL else {
                    showExportPreview = false
                    exportAlertTitle = "エクスポート失敗"
                    exportErrorMessage = "保存ファイルの準備に失敗しました（URLなし）"
                    showExportError = true
                    return
                }
                exportURL = p
                showExportPicker = true
            }
        } message: {
            Text(exportPreviewText)
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

                        guard let data = await DatabaseManager.shared.makeExportJSONData() else {
                            await MainActor.run {
                                exportAlertTitle = "エクスポート失敗"
                                exportErrorMessage = "エクスポートに失敗しました（データ生成）"
                                showExportError = true
                            }
                            return
                        }

                        do {
                            // ① まずファイルを作る（現状の互換名でOK）
                            let url = try ExportFileWriter.writeTempExportFile(data: data)

                            // ② summary を decode してプレビュー文を作る
                            let decoder = JSONDecoder()

                            let fmt = ISO8601DateFormatter()
                            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            fmt.timeZone = TimeZone(secondsFromGMT: 0)

                            decoder.dateDecodingStrategy = .custom { decoder in
                                let c = try decoder.singleValueContainer()
                                let s = try c.decode(String.self)
                                guard let d = fmt.date(from: s) else {
                                    throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date: \(s)")
                                }
                                return d
                            }

                            let pkg = try decoder.decode(RFExportPackage.self, from: data)

                            await MainActor.run {
                                pendingExportURL = url
                                exportJustCreatedAt = Date()

                                exportPreviewText =
                """
                保存内容（要約）
                ・レシピ総数: \(pkg.summary.recipesTotal)
                ・削除済み: \(pkg.summary.recipesDeleted)
                ・材料行総数: \(pkg.summary.ingredientRowsTotal)
                ・警告: \(pkg.summary.warnings)

                この内容をファイルとして保存します。
                保存先を選びますか？
                """
                                showExportPreview = true
                            }

                        } catch {
                            DBLOG("❌ export preview/decode/write failed: \(error.localizedDescription)")
                            await MainActor.run {
                                exportAlertTitle = "エクスポート失敗"
                                exportErrorMessage = "書き出しに失敗しました: \(error.localizedDescription)"
                                showExportError = true
                            }
                        }
                    }
                },

                onImport: {
                    // 今は未実装：将来ここにインポート導線を足す
                }
            )
            .padding(.leading, 18)
            .padding(.bottom, (store.pendingUndo != nil) ? undoToastLift : baseBottomPadding)
            .animation(.easeInOut(duration: 0.18), value: store.pendingUndo != nil)
        }
        // ✅ Undoトースト
        .overlay(alignment: .bottom) {
            if store.pendingUndo != nil {
                HStack(spacing: 10) {

                    // 確定（Deleted）
                    Button {
                        Task { @MainActor in store.finalizeDelete() }
                    } label: {
                        Label("Deleted", systemImage: "trash")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary) // 青リンク化を防ぐ（見た目を中立に）

                    Spacer()

                    // Undo（強調）
                    Button {
                        Task { @MainActor in store.undoDelete() }
                    } label: {
                        Text("Undo")
                            .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary) // ガラス世界観に寄せる（青を消したいならこれ）
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            .padding(.bottom, (store.pendingUndo != nil) ? undoToastLift : baseBottomPadding)
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
