/// MARK: - BracketPartView.swift

// 🟨 罫線の線種　最低デフォルト値一元管理シート、表示で追加分は調整

// MARK: - 共通カッコ部品ビュー

import SwiftUI

struct BracketPartView: View {
    enum PartType {
        case top, line, bottom
    }

    enum BracketStyle {
        case square               // 鉤括弧
        case rounded              // 丸括弧
    }

    enum LineStyle {
        case solid                // 実線
        case dashed               // 破線
        case dotted               // 点線
    }

    var type: PartType
    var style: BracketStyle = .square
    var lineStyle: LineStyle = .solid

    var color: Color = .black
    var lineWidth: CGFloat = 0

    var baseLength: CGFloat = 12             // カッコのサイズ
    var addLength: CGFloat = 0
    var extraHorizontalLength: CGFloat = 0  // カッコの長さ
    var curveRadius: CGFloat = 5             // カーブの強さ
    
    

    var body: some View {
        let totalLength = baseLength + addLength
        let resolvedDashPattern: [CGFloat] = {
            switch lineStyle {
            case .solid: return [1, 0]        // 実線１＋余白０
            case .dashed: return [8, 3]       // 実線８＋余白２
            case .dotted: return [2, 2]       // 実線２＋余白２
            }
        }()

        Group {
            switch type {
            case .top:
                BracketPathView(isTop: true, isBottom: false, style: style, color: color, lineWidth: lineWidth, length: totalLength, extraHorizontalLength: extraHorizontalLength, curveRadius: curveRadius, dashPattern: resolvedDashPattern)
            case .line:
                VerticalLinePathView(color: color, lineWidth: lineWidth, length: totalLength, dashPattern: resolvedDashPattern)
            case .bottom:
                BracketPathView(isTop: false, isBottom: true, style: style, color: color, lineWidth: lineWidth, length: totalLength, extraHorizontalLength: extraHorizontalLength, curveRadius: curveRadius, dashPattern: resolvedDashPattern)
            }
        }
    }
}

// MARK: - 共通パスベースビューモジュール

struct BracketPathView: View {
    var isTop: Bool
    var isBottom: Bool
    var style: BracketPartView.BracketStyle
    var color: Color
    var lineWidth: CGFloat
    var length: CGFloat
    var extraHorizontalLength: CGFloat
    var curveRadius: CGFloat
    var dashPattern: [CGFloat]

    var body: some View {
        Path { path in
            if style == .rounded {
                if isTop {
                    path.move(to: CGPoint(x: curveRadius, y: 0))
                    path.addLine(to: CGPoint(x: length + extraHorizontalLength, y: 0))
                    path.move(to: CGPoint(x: curveRadius, y: 0))
                    path.addArc(center: CGPoint(x: curveRadius, y: curveRadius), radius: curveRadius, startAngle: .degrees(-90), endAngle: .degrees(180), clockwise: true)
                    path.addLine(to: CGPoint(x: 0, y: length))
                } else if isBottom {
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: length - curveRadius))
                    path.addArc(center: CGPoint(x: curveRadius, y: length - curveRadius), radius: curveRadius, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
                    path.addLine(to: CGPoint(x: length + extraHorizontalLength, y: length))
                }
            } else {
                if isTop {
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: length + extraHorizontalLength, y: 0))
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: length))
                } else if isBottom {
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: length))
                    path.move(to: CGPoint(x: 0, y: length))
                    path.addLine(to: CGPoint(x: length + extraHorizontalLength, y: length))
                }
            }
        }
        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, dash: dashPattern))
        .foregroundColor(color)
        .frame(width: length + extraHorizontalLength, height: length)
    }
}

struct VerticalLinePathView: View {
    var color: Color
    var lineWidth: CGFloat
    var length: CGFloat
    var dashPattern: [CGFloat]

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: length))
        }
        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, dash: dashPattern))
        .foregroundColor(color)
        .frame(width: lineWidth, height: length)
//        .offset(x: -5.0)  // ✅ 直線をカッコのある左へ線の半分動かす（例：-2pt）
    }
}

// MARK: - 🟨バランス確認用プレビュー

struct BracketPartView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {        // 3つの部品の行間
// solid dashed roundの３パターン線種がある
            BracketPartView(
                type: .top,          // 部品の位置
                style: .rounded,    // 線の形
                lineStyle: .solid, // 線の種類
                color: .red,         // 線の色
                lineWidth: 3,        // 線の太さ
                addLength: -3         // カッコのサイズ
            )
            BracketPartView(
                type: .line,         // 部品の位置
                lineStyle: .solid, // 線のタイプ
                color: .blue,        // 線の色
                lineWidth: 3,        // 線の太さ
                addLength: 24        // 線の幅 破線や転線は高さに注意
            )
            BracketPartView(
                type: .bottom,       // 部品の位置
                style: .rounded,     // 線の形
                lineStyle: .solid,  // 線の種類
                color: .green,        // 線の色
                lineWidth: 3,         // 線の太さ
                addLength: -3          // カッコのサイズ
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
