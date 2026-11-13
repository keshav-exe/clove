import SwiftUI

/// What the disk holds, in the order the parts sit on the bar. What can be
/// cleared goes last, so clearing it only frees the end of the bar and the
/// rest stays where you were looking.
enum StorageKind: Int, CaseIterable, Identifiable, Sendable, Codable {
    case apps
    case developer
    case photos
    case movies
    case documents
    case music
    case system
    case caches
    case trash

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .apps: "Apps"
        case .developer: "Developer"
        case .photos: "Photos"
        case .movies: "Movies"
        case .documents: "Documents"
        case .music: "Music"
        case .system: "System data"
        case .caches: "Caches"
        case .trash: "Trash"
        }
    }

    /// SF Symbols, drawn hierarchical so they read as two-tone like the rest of macOS.
    var symbol: String {
        switch self {
        case .apps: "macwindow.and.cursorarrow"
        case .developer: "shippingbox.fill"
        case .photos: "photo.fill"
        case .movies: "film.fill"
        case .documents: "doc.text.fill"
        case .music: "music.note"
        case .system: "gearshape.fill"
        case .caches: "square.stack.3d.up.fill"
        case .trash: "trash.fill"
        }
    }

    var hue: StorageHue {
        switch self {
        case .apps: .blue
        case .developer: .green
        case .photos: .pink
        case .movies: .violet
        case .documents: .cyan
        case .music: .yellow
        case .system: .neutral
        case .caches: .orange
        case .trash: .red
        }
    }

    /// The same hue on paper: a stop deeper, so an icon keeps its contrast
    /// outside the graphite instrument.
    var paperTint: Color {
        switch self {
        case .apps: Palette.Vivid.blue
        case .developer: Palette.Vivid.green
        case .photos: Palette.Vivid.pink
        case .movies: Palette.Vivid.violet
        case .documents: Palette.Vivid.cyan
        case .music: Palette.Vivid.yellow
        case .system: Palette.inkSecondary
        case .caches: Palette.Vivid.orange
        case .trash: Palette.Vivid.red
        }
    }

    /// Whether a row in this kind can go to the Trash from Clove. System data
    /// has no rows, and the Trash is emptied as a whole.
    var allowsMoveToTrash: Bool {
        switch self {
        case .system, .trash: false
        default: true
        }
    }

    /// Where this kind lives. System data is whatever's left once these are counted.
    var roots: [StorageRoot] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        func folder(_ path: String) -> StorageRoot {
            StorageRoot(url: home.appending(path: path, directoryHint: .isDirectory), listsChildren: true)
        }
        func whole(_ path: String) -> StorageRoot {
            StorageRoot(url: home.appending(path: path, directoryHint: .isDirectory), listsChildren: false)
        }
        switch self {
        case .apps:
            return [StorageRoot(url: URL(filePath: "/Applications", directoryHint: .isDirectory), listsChildren: true), folder("Applications")]
        case .developer:
            // Code folders list their projects; toolchains and agent folders count
            // as one thing each. ~/.cache stays here rather than in Caches: it's
            // mostly downloaded models, which apps don't rebuild on their own.
            return ["Library/Developer", "Developer", "Code", "Projects", "src", "GitHub"].map(folder)
                + [
                    ".npm", ".cargo", ".rustup", ".gradle", ".m2", ".pub-cache", "go", ".bun",
                    ".cache", ".ollama", ".docker", "Library/pnpm", "Library/Containers/com.docker.docker",
                    ".claude", ".cursor", ".codex", ".gemini", ".agents",
                ].map(whole)
        case .photos:
            return [folder("Pictures")]
        case .movies:
            return [folder("Movies")]
        case .documents:
            return [folder("Documents"), folder("Desktop"), folder("Downloads")]
        case .music:
            return [folder("Music")]
        case .system:
            return []
        case .caches:
            return [folder("Library/Caches")]
        case .trash:
            return [folder(".Trash")]
        }
    }
}

/// A folder a kind is measured from. Rows in the list are either the folder's
/// children (each project in ~/Developer) or the folder itself (~/.npm).
struct StorageRoot: Sendable, Hashable {
    let url: URL
    let listsChildren: Bool
}

/// The bar's colours, the sandbox's OKLCH hues expressed in Display P3.
struct StorageHue: Sendable, Equatable {
    let red: Double
    let green: Double
    let blue: Double

    static let blue = StorageHue(red: 0.349, green: 0.612, blue: 1.000)
    static let yellow = StorageHue(red: 0.969, green: 0.818, blue: 0.265)
    static let green = StorageHue(red: 0.436, green: 0.855, blue: 0.453)
    static let red = StorageHue(red: 0.941, green: 0.328, blue: 0.284)
    static let violet = StorageHue(red: 0.639, green: 0.449, blue: 1.000)
    static let orange = StorageHue(red: 0.982, green: 0.558, blue: 0.233)
    static let cyan = StorageHue(red: 0.332, green: 0.826, blue: 0.946)
    static let pink = StorageHue(red: 0.946, green: 0.404, blue: 0.691)
    /// System files get a cool grey, not a colour of their own.
    static let neutral = StorageHue(red: 178 / 255, green: 186 / 255, blue: 200 / 255)

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// From an sRGB hex, for the paper set.
    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension StorageKind {
    /// The bar's hue on paper: the web system's deeper vivid set, so cells keep
    /// their contrast on white. Matches `paperTint`.
    var lightHue: StorageHue {
        switch self {
        case .apps: StorageHue(hex: 0x0278E7)
        case .developer: StorageHue(hex: 0x00A33A)
        case .photos: StorageHue(hex: 0xE03694)
        case .movies: StorageHue(hex: 0x8848E1)
        case .documents: StorageHue(hex: 0x00A0BA)
        case .music: StorageHue(hex: 0xDBA000)
        case .system: StorageHue(hex: 0x8E8E93)
        case .caches: StorageHue(hex: 0xE86700)
        case .trash: StorageHue(hex: 0xE23532)
        }
    }
}

enum StorageFormat {
    /// Decimal gigabytes, like Finder, always with one decimal so numbers don't jump width.
    static func gb(_ bytes: Int64) -> String {
        gb(Double(bytes) / 1e9)
    }

    static func gb(_ gigabytes: Double) -> String {
        let value = max(0, gigabytes)
        if value >= 1000 {
            return String(format: "%.1f TB", value / 1000)
        }
        return String(format: "%.1f GB", value)
    }

    /// The disk's size reads as a round number: 494 GB, not 494.4 GB.
    static func capacity(_ bytes: Int64) -> String {
        let value = Double(bytes) / 1e9
        if value >= 1000 {
            return String(format: "%.0f TB", (value / 1000).rounded())
        }
        return String(format: "%.0f GB", value.rounded())
    }

    static func path(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        let path = url.path(percentEncoded: false)
        let trimmed = path.hasSuffix("/") && path.count > 1 ? String(path.dropLast()) : path
        if trimmed.hasPrefix(home) {
            return "~/" + trimmed.dropFirst(home.hasSuffix("/") ? home.count : home.count + 1)
        }
        return trimmed
    }
}
