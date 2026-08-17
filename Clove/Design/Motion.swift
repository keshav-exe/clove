import SwiftUI

enum Motion {
    static let easeOutCubic = Animation.timingCurve(0.215, 0.61, 0.355, 1, duration: 0.22)

    static func selection(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : easeOutCubic
    }
}
