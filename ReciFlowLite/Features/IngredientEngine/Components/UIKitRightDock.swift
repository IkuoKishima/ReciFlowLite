/// MARK: - UIKitRightDock.swift

import SwiftUI
import UIKit

/// 右端ドック（UIKit）
/// - swipe rail + buttons を UIKit で完結させる
/// - キーボード収納は endEditing(true) で確実に閉じる
struct UIKitRightDock: UIViewRepresentable {

    enum Mode {
        case back     // chevron.left
        case forward  // chevron.right
    }

    let mode: Mode

    // visibility
    var showsDelete: Bool = true
    var showsAdd: Bool = true
    var showsKeyboardDismiss: Bool = true

    // state (for active icons)
    let isDeleteMode: Bool

    // actions
    let onToggleDelete: () -> Void
    let onHome: () -> Void
    let onPrimary: () -> Void
    let onAddBlock: () -> Void
    let onAddSingle: () -> Void

    // swipe
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    // layout constants
    var railWidth: CGFloat = 38 //右端のタッチ可能エリア全体の幅
    var buttonSize: CGFloat = 38 //丸ボタンの大きさ
    var trailingPadding: CGFloat = 10 // 右からのパディング
    var verticalSpacing: CGFloat = 16 //垂直方向の間隔
    var centerYRatio: CGFloat = 0.38   // RightRailControls と同じ配置発想
    var minBottomPadding: CGFloat = 6 //キーボードとドックの干渉限界
    
    // EditView用のプロパティ
    var showsPrimary: Bool = true
    var showsHome: Bool = true



    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let root = UIView()
        root.backgroundColor = .clear
        root.isUserInteractionEnabled = true

        // --- swipe rail ---
        let rail = UIView()
        rail.translatesAutoresizingMaskIntoConstraints = false
//        rail.backgroundColor = UIColor.red.withAlphaComponent(0.92) // ✅debug。リリース前にclearへ
        root.addSubview(rail)

        NSLayoutConstraint.activate([
            rail.topAnchor.constraint(equalTo: root.topAnchor),
            rail.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            rail.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            rail.widthAnchor.constraint(equalToConstant: railWidth)
        ])

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        rail.addGestureRecognizer(pan)

        // --- button stack ---
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = verticalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        // 位置：topではなく centerY 比率で置く
        let centerY = NSLayoutConstraint(item: stack,
                                         attribute: .centerY,
                                         relatedBy: .equal,
                                         toItem: root,
                                         attribute: .bottom,
                                         multiplier: centerYRatio,
                                         constant: 0)

        NSLayoutConstraint.activate([
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -trailingPadding),
            centerY
        ])
        
        let bottomLimit = stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor,
                                                        constant: -minBottomPadding)
        // キーボード干渉限界位置
        bottomLimit.priority = .required
        bottomLimit.isActive = true


        func makeButton(symbol: String, selector: Selector) -> UIButton {
            let b = UIButton(type: .system)
            b.translatesAutoresizingMaskIntoConstraints = false
            b.setImage(UIImage(systemName: symbol), for: .normal)
            b.tintColor = .label
            b.addTarget(context.coordinator, action: selector, for: .touchUpInside)

            // “ガラスっぽさ”は今は最小でOK（挙動優先）
            b.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.35)
            b.layer.cornerRadius = buttonSize / 2
            b.layer.masksToBounds = true

            NSLayoutConstraint.activate([
                b.widthAnchor.constraint(equalToConstant: buttonSize),
                b.heightAnchor.constraint(equalToConstant: buttonSize)
            ])
            return b
        }

        // buttons
        if showsDelete {
            let deleteBtn = makeButton(
                symbol: isDeleteMode ? "minus.circle.fill" : "minus.circle",
                selector: #selector(Coordinator.tapDelete)
            )
            stack.addArrangedSubview(deleteBtn)
            context.coordinator.deleteButton = deleteBtn
        }
        if showsHome {
            stack.addArrangedSubview(makeButton(symbol: "list.bullet.rectangle", selector: #selector(Coordinator.tapHome)))
        }
        
        if showsPrimary {
            stack.addArrangedSubview(makeButton(symbol: primarySymbol, selector: #selector(Coordinator.tapPrimary)))
        }

        if showsAdd {
            stack.addArrangedSubview(makeButton(symbol: "square.grid.2x2", selector: #selector(Coordinator.tapAddBlock)))
            stack.addArrangedSubview(makeButton(symbol: "plus", selector: #selector(Coordinator.tapAddSingle)))
        }

        if showsKeyboardDismiss {
            stack.addArrangedSubview(makeButton(symbol: "keyboard.chevron.compact.down", selector: #selector(Coordinator.tapKeyboardDismiss)))
        }

        return root
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // delete icon state update
        context.coordinator.deleteButton?.setImage(
            UIImage(systemName: isDeleteMode ? "minus.circle.fill" : "minus.circle"),
            for: .normal
        )
    }

    private var primarySymbol: String {
        switch mode {
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        }
    }

    final class Coordinator: NSObject {
        let parent: UIKitRightDock
        weak var deleteButton: UIButton?

        init(_ parent: UIKitRightDock) {
            self.parent = parent
        }

        @objc func tapDelete() { parent.onToggleDelete() }
        @objc func tapAddSingle() { parent.onAddSingle() }
        @objc func tapAddBlock() { parent.onAddBlock() }
        @objc func tapPrimary() { parent.onPrimary() }
        @objc func tapHome() { parent.onHome() }

        /// ✅ ここが “安定の本丸”
        @objc func tapKeyboardDismiss() {
            // KeyWindow endEditing(true)
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .endEditing(true)
        }

        @objc func handlePan(_ gr: UIPanGestureRecognizer) {
            guard gr.state == .ended else { return }
            let v = gr.velocity(in: gr.view)

            // 速度ベースで誤反応を減らす
            if v.x < -300 { parent.onSwipeLeft() }
            else if v.x > 300 { parent.onSwipeRight() }
        }
    }
}
