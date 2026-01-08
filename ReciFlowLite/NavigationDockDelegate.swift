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

    // MARK: - Long press repeat (v15 quality)
    // 長押し連打用
    private var repeatTimer: Timer?
    private var repeatingAction: (() -> Void)?

    // ✅ 速度（v15は 0.10 / Liteは 0.08 だったので好みで）
    private let repeatInterval: TimeInterval = 0.08

    // ✅ 安全装置（無限連打防止）
    private var repeatStepCount: Int = 0
    private let maxRepeatSteps: Int = 300

    // ✅ 触感（開始時だけ）
    private let longPressFeedback = UIImpactFeedbackGenerator(style: .rigid)

    private override init() {}
    
    private final class TapActionStore {
        static let shared = TapActionStore()
        private init() {}

        private var actions: [ObjectIdentifier: () -> Void] = [:]

        func register(action: @escaping () -> Void, for control: UIControl) {
            actions[ObjectIdentifier(control)] = action
        }

        func perform(for control: UIControl) {
            actions[ObjectIdentifier(control)]?()
        }
    }

    @objc private func handleTapOverlay(_ sender: UIControl) {
        TapActionStore.shared.perform(for: sender)
    }


    // MARK: - Actions

    @objc private func tapDone() {
        stopRepeat() // ✅ done でも必ず止める
        delegate?.navDone()
    }

    @objc private func tapUp()    { delegate?.navUp() }
    @objc private func tapDown()  { delegate?.navDown() }
    @objc private func tapLeft()  { delegate?.navLeft() }
    @objc private func tapRight() { delegate?.navRight() }

    // ✅ 必ず停止できる共通関数
    private func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        repeatingAction = nil
        repeatStepCount = 0
    }

    // Long press: 連打（v15相当の安全設計）
    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard let view = gr.view else { return }
        guard let key = view.accessibilityHint else { return }

        func actionClosure() -> (() -> Void) {
            switch key {
            case "up":    return { [weak self] in self?.delegate?.navUp() }
            case "down":  return { [weak self] in self?.delegate?.navDown() }
            case "left":  return { [weak self] in self?.delegate?.navLeft() }
            case "right": return { [weak self] in self?.delegate?.navRight() }
            default:      return { }
            }
        }

        switch gr.state {

        case .began:
            // ✅ 多重起動防止
            stopRepeat()
            repeatStepCount = 0

            // ✅ 長押し開始時だけ触感
            longPressFeedback.prepare()
            longPressFeedback.impactOccurred(intensity: 0.9)

            let closure = actionClosure()
            repeatingAction = closure

            // （好み）最初の1発を即時に入れるならここで1回
            closure()

            // ✅ 連打開始
            repeatTimer = Timer.scheduledTimer(withTimeInterval: repeatInterval, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.repeatStepCount += 1
                if self.repeatStepCount >= self.maxRepeatSteps {
                    self.stopRepeat()
                    return
                }
                self.repeatingAction?()
            }

        case .ended, .cancelled, .failed:
            stopRepeat()

        default:
            break
        }
    }

    // MARK: - Build Items (SwiftUI視覚 + UIKit命令)

    private func makeItems() -> [UIBarButtonItem] {
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let spacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        spacer.width = 6

        let done  = makeGlassItem(symbol: "keyboard.chevron.compact.down", tap: { [weak self] in self?.tapDone() })
        let up    = makeGlassItem(symbol: "chevron.up",    tap: { [weak self] in self?.tapUp() },    longPressKey: "up")
        let left  = makeGlassItem(symbol: "chevron.left",  tap: { [weak self] in self?.tapLeft() },  longPressKey: "left")
        let right = makeGlassItem(symbol: "chevron.right", tap: { [weak self] in self?.tapRight() }, longPressKey: "right")
        let down  = makeGlassItem(symbol: "chevron.down",  tap: { [weak self] in self?.tapDown() },  longPressKey: "down")

        let rightInset = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        rightInset.width = 30
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

    

    private func makeGlassItem(
        symbol: String,
        tap: @escaping () -> Void,
        longPressKey: String? = nil
    ) -> UIBarButtonItem {

        let buttonSize: CGFloat = 30
        let containerSize: CGFloat = 30

        // ① SwiftUI（見た目だけ）
        let host = UIHostingController(rootView: GlassIconButton(symbol: symbol) { })
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false   // ✅ 超重要：見た目だけにする

        // ② コンテナ（サイズ確定）
        let container = UIView(frame: CGRect(x: 0, y: 0, width: containerSize, height: containerSize))
        container.backgroundColor = .clear

        host.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            host.view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            host.view.widthAnchor.constraint(equalToConstant: buttonSize),
            host.view.heightAnchor.constraint(equalToConstant: buttonSize),
        ])

        // ③ 透明ボタン（UIKitがタッチを受ける）
        let touch = UIButton(type: .custom)
        touch.backgroundColor = .clear
        touch.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(touch)

        NSLayoutConstraint.activate([
            touch.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            touch.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            touch.topAnchor.constraint(equalTo: container.topAnchor),
            touch.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // 単発タップ
        touch.addTarget(self, action: #selector(handleTapOverlay(_:)), for: .touchUpInside)
        TapActionStore.shared.register(action: tap, for: touch)

        // 長押し（必要な場合のみ）
        if let key = longPressKey {
            touch.accessibilityHint = key

            let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            lp.minimumPressDuration = 0.35
            lp.cancelsTouchesInView = true
            touch.addGestureRecognizer(lp)
        }

        let item = UIBarButtonItem(customView: container)

        // サイズ固定（崩れ防止）
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: containerSize),
            container.heightAnchor.constraint(equalToConstant: containerSize)
        ])

        return item
    }

}
