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

    // MARK: - External control (SwiftUI -> Router)

    /// 外部からフォーカス座標を指示する（nil で解除もできる）
    func set(_ newValue: FocusCoordinate?) {
        // 変化がないなら何もしない（ログ爆発・無駄スクロールを抑える）
        guard current != newValue else { return }
        beginInternalFocusUpdate()
        current = newValue
        endInternalFocusUpdate()
    }

    /// フォーカス解除
    func clear() {
        set(nil)
    }

    /// 初期フォーカスを入れたい場面だけ、明示的に呼ぶ
    func focusFirstIfNeeded() {
        guard current == nil, let first = railRowIds.first else { return }
        set(.init(rowId: first, field: .name))
    }

    // MARK: - Build / Rebuild

    /// rows から「フォーカス可能 rowId レール」を作る
    func rebuild(rows: [IngredientRow]) {
        railRowIds = rows.compactMap { row in
            switch row {
            case .single(let item): return item.id
            case .blockItem(let item): return item.id
            case .blockHeader: return nil
            }
        }

        // ✅ current が消えたときだけ退避（削除対策）
        if let c = current, !railRowIds.contains(c.rowId) {
            current = fallbackAfterRebuild()
        }
        // current == nil のときは何もしない（初期フォーカスは外から入れる）
    }

    private func fallbackAfterRebuild() -> FocusCoordinate? {
        guard let first = railRowIds.first else { return nil }
        return FocusCoordinate(rowId: first, field: .name)
    }

    // MARK: - Sync (UIKit -> Router)

    /// UITextFieldDidBeginEditing から「実フォーカス」を報告する（※外部setとは別）
    func reportFocused(rowId: UUID, field: FocusCoordinate.Field) {
        guard !isInternalUpdate else { return }
        guard current != .init(rowId: rowId, field: field) else { return } // ✅ 同値抑制
        current = .init(rowId: rowId, field: field)
    }

    // MARK: - Commands (Dock / Enter)

    func moveLeft() {
        guard let c = current else { return }
        guard !railRowIds.isEmpty else { return }

        switch c.field {
        case .unit:   current = .init(rowId: c.rowId, field: .amount)
        case .amount: current = .init(rowId: c.rowId, field: .name)
        case .name:
            guard let r = railIndex(of: c.rowId) else { return }
            let prevR = (r - 1 + railRowIds.count) % railRowIds.count
            current = .init(rowId: railRowIds[prevR], field: .unit)
        }
    }

    func moveRight() {
        guard let c = current else { return }
        guard !railRowIds.isEmpty else { return }

        switch c.field {
        case .name:   current = .init(rowId: c.rowId, field: .amount)
        case .amount: current = .init(rowId: c.rowId, field: .unit)
        case .unit:
            guard let r = railIndex(of: c.rowId) else { return }
            let nextR = (r + 1) % railRowIds.count
            current = .init(rowId: railRowIds[nextR], field: .name)
        }
    }

    func moveUp() {
        guard let c = current else { return }
        guard let r = railIndex(of: c.rowId), !railRowIds.isEmpty else { return }
        let nextR = (r - 1 + railRowIds.count) % railRowIds.count
        current = .init(rowId: railRowIds[nextR], field: c.field)
    }

    func moveDown() {
        guard let c = current else { return }
        guard let r = railIndex(of: c.rowId), !railRowIds.isEmpty else { return }
        let nextR = (r + 1) % railRowIds.count
        current = .init(rowId: railRowIds[nextR], field: c.field)
    }

    func enterNext() {
        guard let c = current else { return }
        guard !railRowIds.isEmpty else { return }

        switch c.field {
        case .name:   current = .init(rowId: c.rowId, field: .amount)
        case .amount: current = .init(rowId: c.rowId, field: .unit)
        case .unit:
            guard let r = railIndex(of: c.rowId) else { return }
            let nextR = (r + 1) % railRowIds.count
            current = .init(rowId: railRowIds[nextR], field: .name)
        }
    }

    private func railIndex(of rowId: UUID) -> Int? {
        railRowIds.firstIndex(of: rowId)
    }

    // MARK: - Internal Focus Update Guard

    func beginInternalFocusUpdate() { isInternalUpdate = true }
    func endInternalFocusUpdate()   { isInternalUpdate = false }
}
