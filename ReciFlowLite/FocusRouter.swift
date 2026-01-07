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
        let nextRaw = max(0, c.field.rawValue - 1)
        current = .init(rowId: c.rowId, field: FocusCoordinate.Field(rawValue: nextRaw) ?? .name)
    }

    func moveRight() {
        guard let c = current else { return }
        let nextRaw = min(2, c.field.rawValue + 1)
        current = .init(rowId: c.rowId, field: FocusCoordinate.Field(rawValue: nextRaw) ?? .unit)
    }

    /// ↑↓ は「3刻み」＝同列移動（name: 0, amount:1, unit:2 を維持）
    func moveUp() {
        guard let c = current else { return }
        guard let r = railIndex(of: c.rowId) else { return }
        let nextR = max(0, r - 1)
        current = .init(rowId: railRowIds[nextR], field: c.field)
    }

    func moveDown() {
        guard let c = current else { return }
        guard let r = railIndex(of: c.rowId) else { return }
        let nextR = min(railRowIds.count - 1, r + 1)
        current = .init(rowId: railRowIds[nextR], field: c.field)
    }

    /// Enter = 次へ（name→amount→unit→次行name）
    func enterNext() {
        guard let c = current else { return }

        switch c.field {
        case .name:
            current = .init(rowId: c.rowId, field: .amount)
        case .amount:
            current = .init(rowId: c.rowId, field: .unit)
        case .unit:
            guard let r = railIndex(of: c.rowId) else {
                current = .init(rowId: c.rowId, field: .name)
                return
            }
            let nextR = min(railRowIds.count - 1, r + 1)
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
