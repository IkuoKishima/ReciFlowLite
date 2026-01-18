/// MARK: - SelectAllTextField.swift

import SwiftUI
import UIKit

struct SelectAllTextField: UIViewRepresentable {

    // MARK: - Config
    struct Config {
        struct Focus {
            var rowId: UUID
            var field: FocusCoordinate.Field
            var onReport: (UUID, FocusCoordinate.Field) -> Void
        }

        struct InternalFocus {
            var begin: (() -> Void)?
            var end: (() -> Void)?
        }

        struct Nav {
            var done: (() -> Void)?
            var up: (() -> Void)?
            var down: (() -> Void)?
            var left: (() -> Void)?
            var right: (() -> Void)?
            var repeatBegan: ((String) -> Void)?
            var repeatEnded: (() -> Void)?
        }

        var onDidBecomeFirstResponder: (() -> Void)?
        var onCommit: (() -> Void)?
        var internalFocus: InternalFocus = .init(begin: nil, end: nil)
        var focus: Focus?
        var nav: Nav = .init(done: nil, up: nil, down: nil, left: nil, right: nil)

        static let empty = Config()
    }

    // MARK: - Inputs (minimal)

    @Binding var text: String
    var placeholder: String = ""
    var shouldBecomeFirstResponder: Bool = false
    var textAlignment: NSTextAlignment = .left
    var keyboardType: UIKeyboardType = .default

    // ✅ 追加：色（SwiftUI → UIKit）
    var inkColor: UIColor = .label
    
    var placeholderColor: UIColor = UIColor.secondaryLabel.withAlphaComponent(0.30)

    var config: Config = .empty

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UITextField {
        let tf = KeyCommandTextField()

        // ✅ 文字色/カーソル色
        tf.textColor = inkColor
        tf.tintColor = inkColor

        // ✅ placeholder 色
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: placeholderColor
            ]
        )

        tf.delegate = context.coordinator
        tf.textAlignment = textAlignment
        tf.keyboardType = keyboardType

        tf.addTarget(context.coordinator, action: #selector(Coordinator.editChanged(_:)), for: .editingChanged)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editDidBegin(_:)), for: .editingDidBegin)

    #if DEBUG
    let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    if !isPreview {
        tf.inputAccessoryView = NavigationDockController.shared.toolbar
    }
    #else
    tf.inputAccessoryView = NavigationDockController.shared.toolbar
    #endif

    return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }

        // ✅ 色は毎回同期（テーマ変更/ダーク切替に追従）
        if uiView.textColor != inkColor { uiView.textColor = inkColor }
        if uiView.tintColor != inkColor { uiView.tintColor = inkColor }

        // placeholder は毎回上書きしてOK（軽い）
        uiView.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: placeholderColor]
        )

        // ✅ nav は毎回更新（一本道化）
        context.coordinator.updateNavHandlers(nav: config.nav)

        // ✅ フォーカス指示：毎回なれるように（多重だけ防ぐ）
        if shouldBecomeFirstResponder,
           !uiView.isFirstResponder,
           !context.coordinator.isBecoming {

            let coordinator = context.coordinator
            coordinator.isBecoming = true

            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                uiView.selectAll(nil)
                coordinator.isBecoming = false
            }
        }

        if let tf = uiView as? KeyCommandTextField {
            tf.onTab = { context.coordinator.navRightByTab() }
            tf.onShiftTab = { context.coordinator.navLeftByShiftTab() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator
    final class Coordinator: NSObject, UITextFieldDelegate, NavigationDockDelegate {

        var parent: SelectAllTextField
        fileprivate var isBecoming = false

        private weak var activeTextField: UITextField?
        private var nav: Config.Nav = .init(done: nil, up: nil, down: nil, left: nil, right: nil)

        private(set) var isActive = false

        private var isPreview: Bool {
            ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        }

        init(_ parent: SelectAllTextField) {
            self.parent = parent
            super.init()
        }

        func updateNavHandlers(nav: Config.Nav) { self.nav = nav }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isActive = true
            isBecoming = false
            activeTextField = textField

            // ✅ Preview中は Dock シングルトンを触らない
            if !isPreview {
                NavigationDockController.shared.delegate = self
            }

            parent.config.onDidBecomeFirstResponder?()

            if let focus = parent.config.focus {
                focus.onReport(focus.rowId, focus.field)
            }
        }

        func navRightByTab()     { nav.right?() }
        func navLeftByShiftTab() { nav.left?()  }

        func navDone()  { activeTextField?.resignFirstResponder(); nav.done?() }
        func navUp()    { nav.up?() }
        func navDown()  { nav.down?() }
        func navLeft()  { nav.left?() }
        func navRight() { nav.right?() }
        func navRepeatBegan(direction: String) { nav.repeatBegan?(direction) }
        func navRepeatEnded() { nav.repeatEnded?() }

        @objc func editChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        @objc func editDidBegin(_ sender: UITextField) {
            DispatchQueue.main.async {
                if !(sender.text ?? "").isEmpty { sender.selectAll(nil) }
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.config.onCommit?()
            return false
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isActive = false
            isBecoming = false

            // ✅ Preview中は shared を触らない
            if !isPreview, NavigationDockController.shared.delegate === self {
                NavigationDockController.shared.delegate = nil
            }
        }
    }


    // MARK: - Tab Shift+Tab対応ロジック
    private final class KeyCommandTextField: UITextField {
        var onTab: (() -> Void)?
        var onShiftTab: (() -> Void)?

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if let key = presses.first?.key, key.keyCode == .keyboardTab {
                if key.modifierFlags.contains(.shift) { onShiftTab?() }
                else { onTab?() }
                return
            }
            super.pressesBegan(presses, with: event)
        }
    }
}
