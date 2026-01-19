/// MARK: - UIKitRightDock.swift
/// 重要⚠️責務分離：色はここで決定する

import SwiftUI
import UIKit

/// 右端ドック（UIKit）
/// - swipe rail + buttons を UIKit で完結させる
/// - キーボード収納は endEditing(true) で確実に閉じる
struct UIKitRightDock: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    let isDarkBackground: Bool // PaperStyle.black / nightInk の時 true


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

    // MARK: - 色決定ロジックの追加（色の司令塔）
    private func resolvedSymbolColor(
        isDelete: Bool
    ) -> Color {

        if isDelete {
            return .red
        }

        // ダークモード or 黒背景 → 白
        if colorScheme == .dark || isDarkBackground {
            return .white
        }

        // それ以外（ライト＋明るい背景）
        return .black
    }


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


        func makeDeleteButton(symbol: String, selector: Selector) -> UIButton {
            let b = UIButton(type: .system)
            b.translatesAutoresizingMaskIntoConstraints = false
            b.setImage(UIImage(systemName: symbol), for: .normal)
            b.tintColor = .label
            b.addTarget(context.coordinator, action: selector, for: .touchUpInside)

            // Deleteは見た目だけ “軽くガラス風” でもOK（今のままでもOK）
            b.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.35)
            b.layer.cornerRadius = buttonSize / 2
            b.layer.masksToBounds = true

            NSLayoutConstraint.activate([
                b.widthAnchor.constraint(equalToConstant: buttonSize),
                b.heightAnchor.constraint(equalToConstant: buttonSize)
            ])
            return b
        }

        func makeGlassButton(symbol: String, selector: Selector, symbolColor: Color) -> UIView {

            let hitSize: CGFloat = 44                // ✅当たり判定
            let visualSize: CGFloat = buttonSize     // ✅見た目（今の38をそのまま使う）

            // ① 見た目：SwiftUI の GlassIconButton（tapは空でOK）
            let visual = GlassIconButton(
                symbol: symbol,
                action: { },
                hitSize: hitSize,
                visualDiameter: visualSize,
                symbolColor: symbolColor
            )
            .environment(\.colorScheme, colorScheme)   // ✅ SwiftUI側に注入

            let host = UIHostingController(rootView: visual)
            host.view.backgroundColor = .clear
            host.view.isUserInteractionEnabled = false
            host.overrideUserInterfaceStyle = (colorScheme == .dark ? .dark : .light)  // ✅ UIKit側も強制


            // ② コンテナ（stackに積む実体）
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.backgroundColor = .clear
            container.clipsToBounds = false

            container.addSubview(host.view)
            host.view.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                host.view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                host.view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                host.view.widthAnchor.constraint(equalToConstant: visualSize),
                host.view.heightAnchor.constraint(equalToConstant: visualSize),
            ])

            // ③ 透明タップ（44x44）
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

            // selectorを叩く（あなたのCoordinator構造を崩さない）
            touch.addTarget(context.coordinator, action: selector, for: .touchUpInside)

            // stackでの見た目サイズは “visualSize” に揃える（間隔が変わらない）
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: visualSize),
                container.heightAnchor.constraint(equalToConstant: visualSize),
            ])

            return container
        }


        // MARK: - buttons
        
        if showsDelete {
            let v = GlassHostedButton(
                symbol: isDeleteMode ? "minus.circle.fill" : "minus.circle",
                visualSize: buttonSize,
                colorScheme: colorScheme,
                symbolColor: resolvedSymbolColor(isDelete: true),
                target: context.coordinator,
                action: #selector(Coordinator.tapDelete)
            )
            stack.addArrangedSubview(v)
            context.coordinator.deleteGlassButton = v
        }

        if showsHome {
            let v = GlassHostedButton(
                symbol: "list.bullet.rectangle",
                visualSize: buttonSize,
                colorScheme: colorScheme,
                symbolColor: resolvedSymbolColor(isDelete: false),
                target: context.coordinator,
                action: #selector(Coordinator.tapHome)
            )
            stack.addArrangedSubview(v)
            context.coordinator.homeButton = v
        }


        if showsPrimary {
            let v = GlassHostedButton(
                symbol: primarySymbol,
                visualSize: buttonSize,
                colorScheme: colorScheme,
                symbolColor: resolvedSymbolColor(isDelete: false),
                target: context.coordinator,
                action: #selector(Coordinator.tapPrimary)
            )
            stack.addArrangedSubview(v)
            context.coordinator.primaryButton = v
        }

        if showsAdd {
            let block = GlassHostedButton(
                symbol: "square.grid.2x2",
                visualSize: buttonSize,
                colorScheme: colorScheme,
                symbolColor: resolvedSymbolColor(isDelete: false),
                target: context.coordinator,
                action: #selector(Coordinator.tapAddBlock)
            )
            stack.addArrangedSubview(block)
            context.coordinator.addBlockButton = block

            let single = GlassHostedButton(
                symbol: "plus",
                visualSize: buttonSize,
                colorScheme: colorScheme,
                symbolColor: resolvedSymbolColor(isDelete: false),
                target: context.coordinator,
                action: #selector(Coordinator.tapAddSingle)
            )
            stack.addArrangedSubview(single)
            context.coordinator.addSingleButton = single
        }


        if showsKeyboardDismiss {
            let v = GlassHostedButton(
                symbol: "keyboard.chevron.compact.down",
                visualSize: buttonSize,
                colorScheme: colorScheme,
                symbolColor: resolvedSymbolColor(isDelete: false),
                target: context.coordinator,
                action: #selector(Coordinator.tapKeyboardDismiss)
            )
            stack.addArrangedSubview(v)
            context.coordinator.keyboardButton = v
        }


        return root
    }

    // MARK: - 色追従の本体
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.deleteGlassButton?.update(
            symbol: isDeleteMode ? "minus.circle.fill" : "minus.circle",
            colorScheme: colorScheme,
            symbolColor: resolvedSymbolColor(isDelete: true)
        )

        context.coordinator.homeButton?.update(
            symbol: "list.bullet.rectangle",
            colorScheme: colorScheme,
            symbolColor: resolvedSymbolColor(isDelete: false)
        )

        context.coordinator.primaryButton?.update(
            symbol: primarySymbol,
            colorScheme: colorScheme,
            symbolColor: resolvedSymbolColor(isDelete: false)
        )

        context.coordinator.addBlockButton?.update(
            symbol: "square.grid.2x2",
            colorScheme: colorScheme,
            symbolColor: resolvedSymbolColor(isDelete: false)
        )

        context.coordinator.addSingleButton?.update(
            symbol: "plus",
            colorScheme: colorScheme,
            symbolColor: resolvedSymbolColor(isDelete: false)
        )

        context.coordinator.keyboardButton?.update(
            symbol: "keyboard.chevron.compact.down",
            colorScheme: colorScheme,
            symbolColor: resolvedSymbolColor(isDelete: false)
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
        weak var deleteGlassButton: GlassHostedButton?
        weak var homeButton: GlassHostedButton?
        weak var primaryButton: GlassHostedButton?
        weak var addBlockButton: GlassHostedButton?
        weak var addSingleButton: GlassHostedButton?
        weak var keyboardButton: GlassHostedButton?

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

// MARK: - GlassHostedButton（UIKit部品）
final class GlassHostedButton: UIView {

    private var host: UIHostingController<AnyView>?
    private let touch = UIControl()

    private let hitSize: CGFloat = 44
    private let visualSize: CGFloat

    // ここは「固定」じゃなく、更新可能にする
    private var colorScheme: ColorScheme
    private var symbolColor: Color

    init(
        symbol: String,
        visualSize: CGFloat,
        colorScheme: ColorScheme,
        symbolColor: Color = .primary,
        target: Any?,
        action: Selector
    ) {
        self.visualSize = visualSize
        self.colorScheme = colorScheme
        self.symbolColor = symbolColor
        super.init(frame: .zero)

        backgroundColor = .clear
        clipsToBounds = false
        translatesAutoresizingMaskIntoConstraints = false

        let host = UIHostingController(rootView: Self.makeView(
            symbol: symbol,
            hitSize: hitSize,
            visualSize: visualSize,
            colorScheme: colorScheme,
            symbolColor: symbolColor
        ))
        self.host = host
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(host.view)

        host.overrideUserInterfaceStyle = (colorScheme == .dark ? .dark : .light)

        NSLayoutConstraint.activate([
            host.view.centerXAnchor.constraint(equalTo: centerXAnchor),
            host.view.centerYAnchor.constraint(equalTo: centerYAnchor),
            host.view.widthAnchor.constraint(equalToConstant: visualSize),
            host.view.heightAnchor.constraint(equalToConstant: visualSize),
        ])

        touch.backgroundColor = .clear
        touch.translatesAutoresizingMaskIntoConstraints = false
        addSubview(touch)

        NSLayoutConstraint.activate([
            touch.centerXAnchor.constraint(equalTo: centerXAnchor),
            touch.centerYAnchor.constraint(equalTo: centerYAnchor),
            touch.widthAnchor.constraint(equalToConstant: hitSize),
            touch.heightAnchor.constraint(equalToConstant: hitSize),
        ])

        touch.addTarget(target, action: action, for: .touchUpInside)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: visualSize),
            heightAnchor.constraint(equalToConstant: visualSize),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// ✅ これが要：symbol / scheme / color をまとめて更新
    func update(symbol: String, colorScheme: ColorScheme, symbolColor: Color) {
        self.colorScheme = colorScheme
        self.symbolColor = symbolColor

        host?.rootView = Self.makeView(
            symbol: symbol,
            hitSize: hitSize,
            visualSize: visualSize,
            colorScheme: colorScheme,
            symbolColor: symbolColor
        )
        host?.overrideUserInterfaceStyle = (colorScheme == .dark ? .dark : .light)
    }

    private static func makeView(
        symbol: String,
        hitSize: CGFloat,
        visualSize: CGFloat,
        colorScheme: ColorScheme,
        symbolColor: Color
    ) -> AnyView {
        AnyView(
            GlassIconButton(
                symbol: symbol,
                action: { },
                hitSize: hitSize,
                visualDiameter: visualSize,
                symbolColor: symbolColor
            )
            .environment(\.colorScheme, colorScheme) // ✅ SwiftUI側も固定注入
        )
    }
}
