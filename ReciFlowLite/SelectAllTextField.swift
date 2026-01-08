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

    var config: Config = .empty

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UITextField {
        let tf = KeyCommandTextField()

        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor.secondaryLabel.withAlphaComponent(0.09)
            ]
        )

        tf.delegate = context.coordinator
        tf.textAlignment = textAlignment
        tf.keyboardType = keyboardType

        tf.addTarget(context.coordinator, action: #selector(Coordinator.editChanged(_:)), for: .editingChanged)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editDidBegin(_:)), for: .editingDidBegin)

        tf.inputAccessoryView = NavigationDockController.shared.toolbar
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        if shouldBecomeFirstResponder && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                self.config.internalFocus.begin?()
                uiView.becomeFirstResponder()
                uiView.selectAll(nil)
                self.config.internalFocus.end?()
            }
        }

        // “今アクティブなTextField”に対して Dock の命令先を更新
        context.coordinator.updateNavHandlers(nav: config.nav)
        
        // ✅ Tab / Shift+Tab を “今のアクティブ設定” に追従させる
        if let tf = uiView as? KeyCommandTextField {
            tf.onTab = { context.coordinator.navRightByTab() }
            tf.onShiftTab = { context.coordinator.navLeftByShiftTab() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextFieldDelegate, NavigationDockDelegate {
        var parent: SelectAllTextField
        private weak var activeTextField: UITextField?

        private var nav: Config.Nav = .init(done: nil, up: nil, down: nil, left: nil, right: nil)

        init(_ parent: SelectAllTextField) {
            self.parent = parent
            super.init()
        }

        func updateNavHandlers(nav: Config.Nav) {
            self.nav = nav
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            activeTextField = textField
            NavigationDockController.shared.delegate = self

            parent.config.onDidBecomeFirstResponder?()

            if let focus = parent.config.focus {
                focus.onReport(focus.rowId, focus.field)
            }
        }
        
//        func navRightByTab() { nav.right?() }
//        func navLeftByShiftTab() { nav.left?() }
        func navRightByTab() {
            parent.config.internalFocus.begin?()   // ✅ beginInternalFocusUpdate に繋がってる前提
            nav.right?()
            parent.config.internalFocus.end?()
        }

        func navLeftByShiftTab() {
            parent.config.internalFocus.begin?()
            nav.left?()
            parent.config.internalFocus.end?()
        }


        // NavigationDockDelegate
        func navDone()  { activeTextField?.resignFirstResponder(); nav.done?() }
        
        func navUp()    { nav.up?() }
        func navDown()  { nav.down?() }
        func navLeft()  { nav.left?() }
        func navRight() { nav.right?() }

        @objc func editChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        @objc func editDidBegin(_ sender: UITextField) {
            DispatchQueue.main.async {
                if !(sender.text ?? "").isEmpty {
                    sender.selectAll(nil)
                }
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.config.onCommit?()
            return false
        }
    }
    
    // MARK: - Tab Shift+Tab対応ロジック
    private final class KeyCommandTextField: UITextField {
        var onTab: (() -> Void)?
        var onShiftTab: (() -> Void)?

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            if let key = presses.first?.key, key.keyCode == .keyboardTab {
                if key.modifierFlags.contains(.shift) {
                    onShiftTab?()
                } else {
                    onTab?()
                }
                return // ✅ ここで標準のフォーカス移動を“食う”
            }
            super.pressesBegan(presses, with: event)
        }
    }

}
