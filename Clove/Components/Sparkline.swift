import SwiftUI

/// A small trend line, scaled to its own minimum and maximum.
struct Sparkline: Shape {
    let values: [Int]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1, let low = values.min(), let high = values.max() else { return path }
        let range = Double(max(high - low, 1))
        let step = rect.width / Double(values.count - 1)

        for (index, value) in values.enumerated() {
            let point = CGPoint(
                x: rect.minX + Double(index) * step,
                y: rect.maxY - (Double(value - low) / range) * rect.height
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path.strokedPath(StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
    }
}
