import SwiftUI

/// 入りきらない分を次の行へ送る横並び。
///
/// `HStack` は幅が足りないとき**子を縮める**。数が読めない可変長の並び（トピックなど）を
/// 入れると、1文字ずつ縦に折り返した「縦棒」になって読めなくなる。
/// **この崩れは実機で初めて見つかった** — 要素の有無しか見ない View テストでは拾えない
/// （docs/04-test-strategy.md §3-1）。
public struct AppFlowLayout: Layout {
    private let spacing: CGFloat
    private let lineSpacing: CGFloat

    public init(spacing: CGFloat = AppSpacing.sm, lineSpacing: CGFloat = AppSpacing.sm) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let lines = lines(for: subviews, maxWidth: proposal.width ?? .infinity)
        let width = lines.map(\.width).max() ?? 0
        let height = lines.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(lines.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        var originY = bounds.minY
        for line in lines(for: subviews, maxWidth: bounds.width) {
            var originX = bounds.minX
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: originX, y: originY), proposal: ProposedViewSize(size))
                originX += size.width + spacing
            }
            originY += line.height + lineSpacing
        }
    }

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// 子を「縮めずに置ける幅」で行へ切り分ける。
    /// 縮めないのが要点である — 縮めるのが `HStack` の振る舞いで、それが崩れの原因だった。
    private func lines(for subviews: Subviews, maxWidth: CGFloat) -> [Line] {
        var lines: [Line] = []
        var current = Line()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if !current.indices.isEmpty, needed > maxWidth {
                lines.append(current)
                current = Line(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { lines.append(current) }
        return lines
    }
}
