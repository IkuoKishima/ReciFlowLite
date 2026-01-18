/// MARK: - NavigationDockDelegate.swift

import UIKit
import SwiftUI

protocol NavigationDockDelegate: AnyObject {
    func navDone()
    func navUp()
    func navDown()
    func navLeft()
    func navRight()

    func navRepeatBegan(direction: String)
    func navRepeatEnded()
}


final class NavigationDockController: NSObject {

    static let shared = NavigationDockController()

    weak var delegate: NavigationDockDelegate?

    private(set) lazy var toolbar: UIToolbar = {
        let tb = UIToolbar()
        tb.isTranslucent = true
        tb.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        tb.setShadowImage(UIImage(), forToolbarPosition: .any)
        tb.clipsToBounds = false
        tb.frame.size.height = 50
        tb.backgroundColor = .clear
        tb.items = makeItems()
        return tb
    }()

    // MARK: - Long press repeat (v15 quality)
    // 長押し連打用
    private var repeatTimer: Timer?
    private var repeatingAction: (() -> Void)?

    // ✅ 速度（v15は 0.10 / Liteは 0.08 だったので好みで）
    private let repeatInterval: TimeInterval = 0.10 //let minInterval: CFTimeInterval = 0.10と揃える

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
            stopRepeat()
            repeatStepCount = 0

            longPressFeedback.prepare()
            longPressFeedback.impactOccurred(intensity: 0.9)
            delegate?.navRepeatBegan(direction: key) // 追加：repeat開始通知

            let closure = actionClosure()
            repeatingAction = closure

            // （好み）最初の1発を入れるならここで1回
            // closure()

            repeatTimer = Timer.scheduledTimer(withTimeInterval: repeatInterval, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.repeatStepCount += 1
                if self.repeatStepCount >= self.maxRepeatSteps {
                    self.delegate?.navRepeatEnded()   // 追加：終了通知
                    self.stopRepeat()
                    return
                }
                self.repeatingAction?()
            }

        case .ended, .cancelled, .failed:
            delegate?.navRepeatEnded() // 追加：repeat終了通知
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
            down, spacer, spacer,
            left, spacer,
            right,
            rightInset
        ]
    }

    

    private func makeGlassItem(
        symbol: String,
        tap: @escaping () -> Void,
        longPressKey: String? = nil
    ) -> UIBarButtonItem {

        // MARK: - ボタンサイズと初期化
        let visualSize: CGFloat = 34
        let hitSize: CGFloat = 44

        let visual = GlassIconButton(
            symbol: symbol,
            action: { },
            hitSize: hitSize,
            visualDiameter: visualSize
        )


        let host = UIHostingController(rootView: visual)
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false

        // ② 見た目コンテナ
        let container = UIView(frame: CGRect(x: 0, y: 0, width: visualSize, height: visualSize))
        container.backgroundColor = .clear
        container.clipsToBounds = false // ← 透明タップ(44)をはみ出させる

        host.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            host.view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            host.view.widthAnchor.constraint(equalToConstant: visualSize),
            host.view.heightAnchor.constraint(equalToConstant: visualSize),
        ])

        // “UIControl(透明板)” に変える（見えない）
        let touch = UIControl()
        touch.backgroundColor = .clear
        touch.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(touch)

        NSLayoutConstraint.activate([
            touch.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            touch.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            touch.widthAnchor.constraint(equalToConstant: hitSize),
            touch.heightAnchor.constraint(equalToConstant: hitSize),
        ])

        touch.addTarget(self, action: #selector(handleTapOverlay(_:)), for: .touchUpInside)
        TapActionStore.shared.register(action: tap, for: touch)

        // 長押し
        if let key = longPressKey {
            touch.accessibilityHint = key
            let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            lp.minimumPressDuration = 0.35
            lp.cancelsTouchesInView = true
            touch.addGestureRecognizer(lp)
        }

        let item = UIBarButtonItem(customView: container)

        // 見た目サイズ固定（30）
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: visualSize),
            container.heightAnchor.constraint(equalToConstant: visualSize)
        ])

        return item
    }
}
