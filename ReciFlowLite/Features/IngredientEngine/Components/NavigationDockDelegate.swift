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

    // MARK: - Toolbar

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

    // MARK: - Long press repeat

    private var repeatTimer: Timer?
    private var repeatingAction: (() -> Void)?

    private let repeatInterval: TimeInterval = 0.10
    private var repeatStepCount: Int = 0
    private let maxRepeatSteps: Int = 300

    private let longPressFeedback = UIImpactFeedbackGenerator(style: .rigid)

    // MARK: - Init / Lifecycle safety

    private override init() {
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func appWillResignActive() {
        stopRepeat()
    }

    @objc private func appDidEnterBackground() {
        stopRepeat()
    }

    // MARK: - Tap action store（透明タップ用）

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

    // MARK: - Tap actions

    @objc private func tapDone() {
        stopRepeat()
        delegate?.navDone()
    }

    @objc private func tapUp()    { delegate?.navUp() }
    @objc private func tapDown()  { delegate?.navDown() }
    @objc private func tapLeft()  { delegate?.navLeft() }
    @objc private func tapRight() { delegate?.navRight() }

    // MARK: - Repeat control（共通停止）

    private func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        repeatingAction = nil
        repeatStepCount = 0
    }

    // MARK: - Long press handler（短気耐性版）

    @objc private func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        guard let view = gr.view,
              let key = view.accessibilityHint else { return }

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

            // delegate をローカルに固定（開始瞬間の不安定さ回避）
            guard let delegate = self.delegate else { return }

            longPressFeedback.prepare()
            longPressFeedback.impactOccurred(intensity: 0.9)
            delegate.navRepeatBegan(direction: key)

            let closure = actionClosure()
            repeatingAction = closure

            let timer = Timer(timeInterval: repeatInterval, repeats: true) { [weak self] _ in
                guard let self else { return }

                // delegate が消えたら即停止（遷移・短気対策）
                guard self.delegate != nil else {
                    self.stopRepeat()
                    return
                }

                self.repeatStepCount += 1
                if self.repeatStepCount >= self.maxRepeatSteps {
                    self.delegate?.navRepeatEnded()
                    self.stopRepeat()
                    return
                }

                self.repeatingAction?()
            }

            timer.tolerance = repeatInterval * 0.25
            repeatTimer = timer
            RunLoop.main.add(timer, forMode: .common)

        case .ended, .cancelled, .failed:
            delegate?.navRepeatEnded()
            stopRepeat()

        default:
            break
        }
    }

    // MARK: - Build toolbar items

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

    // MARK: - Glass button builder

    private func makeGlassItem(
        symbol: String,
        tap: @escaping () -> Void,
        longPressKey: String? = nil
    ) -> UIBarButtonItem {

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

        let container = UIView(frame: CGRect(x: 0, y: 0, width: visualSize, height: visualSize))
        container.backgroundColor = .clear
        container.clipsToBounds = false

        host.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            host.view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            host.view.widthAnchor.constraint(equalToConstant: visualSize),
            host.view.heightAnchor.constraint(equalToConstant: visualSize),
        ])

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

        if let key = longPressKey {
            touch.accessibilityHint = key
            let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            lp.minimumPressDuration = 0.35
            lp.cancelsTouchesInView = true
            touch.addGestureRecognizer(lp)
        }

        let item = UIBarButtonItem(customView: container)

        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: visualSize),
            container.heightAnchor.constraint(equalToConstant: visualSize)
        ])

        return item
    }
}
