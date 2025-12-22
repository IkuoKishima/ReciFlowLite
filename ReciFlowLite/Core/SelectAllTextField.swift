
import SwiftUI
import UIKit

struct SelectAllTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var shouldBecomeFirstResponder: Bool = false
    var onDidBecomeFirstResponder: (() -> Void)? = nil
    var textAlignment: NSTextAlignment = .left
    var keyboardType: UIKeyboardType = .default
    var onCommit: (() -> Void)? = nil

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor.secondaryLabel.withAlphaComponent(0.09)
            ]
        )

//        tf.textAlignment = .right
        tf.delegate = context.coordinator
        tf.textAlignment = textAlignment
        tf.keyboardType = keyboardType
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editChanged(_:)), for: .editingChanged)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editDidBegin(_:)), for: .editingDidBegin)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        if shouldBecomeFirstResponder && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                uiView.selectAll(nil)
                onDidBecomeFirstResponder?()
            }
        }
    }


    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectAllTextField
        init(_ parent: SelectAllTextField) { self.parent = parent }

        @objc func editChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }

        @objc func editDidBegin(_ sender: UITextField) {
            // ✅ ここが「全選択」
            DispatchQueue.main.async {
                if !(sender.text ?? "").isEmpty {
                    sender.selectAll(nil)
                }
            }
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit?()
            return true
        }
    }
}
