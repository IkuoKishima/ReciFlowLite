/// MARK: -  FocusRouter.swift

import Foundation
import Combine

@MainActor
final class FocusRouter: ObservableObject {

    // 現在地（レール上のフォーカス）
    @Published private(set) var current: FocusCoordinate? = nil

    // レール本体（blockHeader は含めない。single と blockItem のみ）
    private(set) var railRowIds: [UUID] = []

    // 内部更新ガード（becomeFirstResponder → didBegin のループ回避）
    private var isInternalUpdate = false

    // MARK: - Build / Rebuild

    /// rows から「フォーカス可能 rowId レール」を作る
    func rebuild(rows: [IngredientRow]) {
        let newRail: [UUID] = rows.compactMap { row in
            switch row {
            case .single(let item): return item.id
            case .blockItem(let item): return item.id
            case .blockHeader: return nil
            }
        }
        railRowIds = newRail

        // current がレールから消えたら、近い場所へ退避
        if let c = current, !railRowIds.contains(c.rowId) {
            current = fallbackAfterRebuild()
        } else if current == nil {
            current = fallbackAfterRebuild()
        }
    }

    private func fallbackAfterRebuild() -> FocusCoordinate? {
        guard let first = railRowIds.first else { return nil }
        return FocusCoordinate(rowId: first, field: .name)
    }

    // MARK: - Sync (UIKit -> Router)

    /// UITextFieldDidBeginEditing から「実フォーカス」を報告する
    func reportFocused(rowId: UUID, field: FocusCoordinate.Field) {
        guard !isInternalUpdate else { return }
        current = .init(rowId: rowId, field: field)
    }

    // MARK: - Commands (Dock / Enter)

    func moveLeft() {
        guard let c = current else { return }
        guard !railRowIds.isEmpty else { return }

        switch c.field {
        case .unit:
            current = .init(rowId: c.rowId, field: .amount)

        case .amount:
            current = .init(rowId: c.rowId, field: .name)

        case .name:
            // ✅ name で左＝前行の unit（先頭なら最終行へループ）
            guard let r = railIndex(of: c.rowId) else { return }
            let prevR = (r - 1 + railRowIds.count) % railRowIds.count
            current = .init(rowId: railRowIds[prevR], field: .unit)
        }
    }

    func moveRight() {
        guard let c = current else { return }
        guard !railRowIds.isEmpty else { return }

        switch c.field {
        case .name:
            current = .init(rowId: c.rowId, field: .amount)

        case .amount:
            current = .init(rowId: c.rowId, field: .unit)

        case .unit:
            // ✅ unit で右＝次行の name（最終なら先頭へループ）
            guard let r = railIndex(of: c.rowId) else { return }
            let nextR = (r + 1) % railRowIds.count
            current = .init(rowId: railRowIds[nextR], field: .name)
        }
    }


    /// ↑↓ は「3刻み」＝同列移動＋上下のループ化（name: 0, amount:1, unit:2 を維持）
    func moveUp() {
        guard let c = current else { return }
        guard let r = railIndex(of: c.rowId), !railRowIds.isEmpty else { return }
        let nextR = (r - 1 + railRowIds.count) % railRowIds.count   // ✅ wrap
        current = .init(rowId: railRowIds[nextR], field: c.field)
    }

    func moveDown() {
        guard let c = current else { return }
        guard let r = railIndex(of: c.rowId), !railRowIds.isEmpty else { return }
        let nextR = (r + 1) % railRowIds.count                      // ✅ wrap
        current = .init(rowId: railRowIds[nextR], field: c.field)
    }


    /// Enter = 次へ（name→amount→unit→次行name）をループ化
    func enterNext() {
        guard let c = current else { return }
        guard !railRowIds.isEmpty else { return }

        switch c.field {
        case .name:
            current = .init(rowId: c.rowId, field: .amount)
        case .amount:
            current = .init(rowId: c.rowId, field: .unit)
        case .unit:
            guard let r = railIndex(of: c.rowId) else { return }
            let nextR = (r + 1) % railRowIds.count
            current = .init(rowId: railRowIds[nextR], field: .name)
        }
    }



    private func railIndex(of rowId: UUID) -> Int? {
        railRowIds.firstIndex(of: rowId)
    }

    // MARK: - SwiftUI -> UIKit focus request helper

    /// becomeFirstResponder を指示する直前に呼ぶ（didBeginのreportでループしないように）
    func beginInternalFocusUpdate() { isInternalUpdate = true }
    func endInternalFocusUpdate()   { isInternalUpdate = false }
}
