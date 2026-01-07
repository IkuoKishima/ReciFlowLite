/// MARK: - NavigationDockDelegate.swift

import UIKit
import SwiftUI

protocol NavigationDockDelegate: AnyObject {
    func navDone()
    func navUp()
    func navDown()
    func navLeft()
    func navRight()
}

final class NavigationDockController: NSObject {

    static let shared = NavigationDockController()

    weak var delegate: NavigationDockDelegate?

    private(set) lazy var toolbar: UIToolbar = {
        let tb = UIToolbar()
        tb.isTranslucent = true
        tb.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        tb.setShadowImage(UIImage(), forToolbarPosition: .any)
        tb.backgroundColor = .clear
        tb.clipsToBounds = false
        tb.frame.size.height = 44
        tb.items = makeItems()
        return tb
    }()

    // 長押し連打用
    private var repeatTimer: Timer?
    private var repeatingAction: (() -> Void)?

    private override init() {}

    // MARK: - Actions

    @objc private func tapDone() { delegate?.navDone() }
    @objc private func tapUp() { delegate?.navUp() }
    @objc private func tapDown() { delegate?.navDown() }
    @objc private func tapLeft() { delegate?.navLeft() }
    @objc private func tapRight() { delegate?.navRight() }

    // Long press: 連打
    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard let view = gr.view, let action = view.accessibilityHint else { return }

        func actionClosure() -> (() -> Void) {
            switch action {
            case "up": return { [weak self] in self?.delegate?.navUp() }
            case "down": return { [weak self] in self?.delegate?.navDown() }
            case "left": return { [weak self] in self?.delegate?.navLeft() }
            case "right": return { [weak self] in self?.delegate?.navRight() }
            default: return { }
            }
        }

        switch gr.state {
        case .began:
            let closure = actionClosure()
            repeatingAction = closure
            closure() // 最初の1発
            repeatTimer?.invalidate()
            repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                self?.repeatingAction?()
            }
        case .ended, .cancelled, .failed:
            repeatTimer?.invalidate()
            repeatTimer = nil
            repeatingAction = nil
        default:
            break
        }
    }

    // MARK: - Build Items (SwiftUI視覚 + UIKit命令)

    private func makeItems() -> [UIBarButtonItem] {
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = 12

        let done = makeGlassItem(symbol: "keyboard.chevron.compact.down", tap: #selector(tapDone))
        let up = makeGlassItem(symbol: "chevron.up", tap: #selector(tapUp), longPressKey: "up")
        let left = makeGlassItem(symbol: "chevron.left", tap: #selector(tapLeft), longPressKey: "left")
        let right = makeGlassItem(symbol: "chevron.right", tap: #selector(tapRight), longPressKey: "right")
        let down = makeGlassItem(symbol: "chevron.down", tap: #selector(tapDown), longPressKey: "down")

        let rightInset = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        rightInset.width = 40

        // ⌨️  ↑  ←  →  ↓
        return [
            flex,
            done, spacer,
            up, spacer,
            left, spacer,
            right, spacer,
            down,
            rightInset
        ]
    }

    private func makeGlassItem(symbol: String, tap: Selector, longPressKey: String? = nil) -> UIBarButtonItem {
        // SwiftUIボタンをUIKitに載せる
        let host = UIHostingController(rootView:
            GlassIconButton(symbol: symbol) { [weak self] in
                _ = self?.perform(tap)
            }
        )
        host.view.backgroundColor = .clear

        // 長押し（必要なものだけ）
        if let key = longPressKey {
            host.view.isUserInteractionEnabled = true
            host.view.accessibilityHint = key
            let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            host.view.addGestureRecognizer(lp)
        }

        let item = UIBarButtonItem(customView: host.view)

        // サイズ固定（崩れ防止）
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.view.widthAnchor.constraint(equalToConstant: 34),
            host.view.heightAnchor.constraint(equalToConstant: 34)
        ])

        return item
    }
}
