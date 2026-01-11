/// MARK: -  FocusRouter.swift

import Foundation
import Combine

@MainActor
final class FocusRouter: ObservableObject {
    
    @Published private(set) var current: FocusCoordinate? = nil  // 現在地（レール上のフォーカス）
    private(set) var railRowIds: [UUID] = [] // レール本体（blockHeader は含めない。single と blockItem のみ）
    private var isInternalUpdate = false // 内部更新ガード（becomeFirstResponder → didBegin のループ回避）
    
    
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
        
        guard let c = current else { return }
        
        // ✅ 追加：headerTitle は “レール外でもOK”。存在していれば保持する
        if c.field == .headerTitle {
            let headerStillExists = rows.contains(where: { row in
                if case .blockHeader(let b) = row { return b.id == c.rowId }
                return false
            })
            if headerStillExists { return }

            // header が消えてたら fallback
            internally { current = fallbackAfterRebuild() }
            return
        }
        // ✅ それ以外は従来どおり「レールに居なければ fallback」
        if !railRowIds.contains(c.rowId) {
            internally { current = fallbackAfterRebuild() }
        }
    }

    private func fallbackAfterRebuild() -> FocusCoordinate? {
        guard let first = railRowIds.first else { return nil }
        return .init(rowId: first, field: .name)
    }
    
    private func firstItemId(inBlock headerId: UUID, rows: [IngredientRow]) -> UUID? {
        // headerId == block.id を想定
        var foundHeader = false
        for row in rows {
            if case .blockHeader(let b) = row, b.id == headerId {
                foundHeader = true
                continue
            }
            if foundHeader, case .blockItem(let it) = row, it.parentBlockId == headerId {
                return it.id
            }
            if foundHeader {
                // headerの直後が blockItem じゃなくなったら終了（別ブロック/単体に移った）
                if case .blockHeader = row { break }
                if case .single = row { break }
            }
        }
        return nil
    }

    // MARK: - Sync (UIKit -> Router)

    /// UITextFieldDidBeginEditing から「実フォーカス」を報告する（※外部setとは別）
    func reportFocused(rowId: UUID, field: FocusCoordinate.Field) {
        guard !isInternalUpdate else { return }
        guard current != .init(rowId: rowId, field: field) else { return } // ✅ 同値抑制
        current = .init(rowId: rowId, field: field)
    }
    
    // MARK: - External control (SwiftUI -> Router)
    
    /// フォーカス解除
    func clear() {
        set(nil)
    }

    /// 初期フォーカスを入れたい場面だけ、明示的に呼ぶ
    func focusFirstIfNeeded() {
        guard current == nil, let first = railRowIds.first else { return }
        set(.init(rowId: first, field: .name))
    }
    
    private func mergeHeaderToRail() {
        guard let first = railRowIds.first else { return }
        current = .init(rowId: first, field: .name)
    }

    
    private func internally(_ body: () -> Void) {
        beginInternalFocusUpdate()
        body()
        endInternalFocusUpdate()
    }

    /// 外部からフォーカス座標を指示する（nil で解除もできる）
    func set(_ newValue: FocusCoordinate?) {
        guard current != newValue else { return }
        internally {
            current = newValue
        }
    }

    // MARK: - Commands (Dock / Enter)
    
    private func railIndex(of rowId: UUID) -> Int? {
        railRowIds.firstIndex(of: rowId)
    }
    
 

    func moveLeft() {
        guard let c = current else { return }
        guard !railRowIds.isEmpty else { return }

        beginInternalFocusUpdate()
        defer { endInternalFocusUpdate() }

        switch c.field {
        case .headerTitle:
            mergeHeaderToRail()

        case .unit:
            current = .init(rowId: c.rowId, field: .amount)

        case .amount:
            current = .init(rowId: c.rowId, field: .name)

        case .name:
            guard let r = railIndex(of: c.rowId) else { return }
            let prevR = (r - 1 + railRowIds.count) % railRowIds.count
            current = .init(rowId: railRowIds[prevR], field: .unit)
        }
    }


    func moveRight() {
        guard let c = current else { return }
        guard !railRowIds.isEmpty else { return }

        beginInternalFocusUpdate()
        defer { endInternalFocusUpdate() }

        switch c.field {
        case .headerTitle:
            mergeHeaderToRail()

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



    func moveUp() {
        guard let c = current else { return }
        guard !railRowIds.isEmpty else { return }

        // ✅ headerTitle はレールへ合流してから終わり（これが最小で安全）
        if c.field == .headerTitle {
            internally { mergeHeaderToRail() }
            return
        }

        guard let r = railIndex(of: c.rowId) else { return }
        let nextR = (r - 1 + railRowIds.count) % railRowIds.count

        internally {
            current = .init(rowId: railRowIds[nextR], field: c.field)
        }
    }

    func moveDown() {
        guard let c = current else { return }
        guard !railRowIds.isEmpty else { return }

        if c.field == .headerTitle {
            internally { mergeHeaderToRail() }
            return
        }

        guard let r = railIndex(of: c.rowId) else { return }
        let nextR = (r + 1) % railRowIds.count

        internally {
            current = .init(rowId: railRowIds[nextR], field: c.field)
        }
    }

  
    func enterNext() {
        guard let c = current else { return }
        guard !railRowIds.isEmpty else { return }

        beginInternalFocusUpdate()
        defer { endInternalFocusUpdate() }

        switch c.field {
        case .headerTitle:
            mergeHeaderToRail()

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



    // MARK: - Internal Focus Update Guard

    private func beginInternalFocusUpdate() { isInternalUpdate = true }
    private func endInternalFocusUpdate()   { isInternalUpdate = false }

}
