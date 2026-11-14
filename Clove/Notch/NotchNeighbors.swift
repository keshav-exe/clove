import AppKit

/// Other apps that live in the notch. Two islands over one notch fight for
/// the same spot, so Clove asks before taking it when one is installed.
struct NotchNeighbor: Identifiable, Hashable, Sendable {
    let name: String
    let url: URL
    /// Shares the notch with Clove (see `NotchHandshake`), so it's no reason
    /// to move to the menu bar.
    let playsAlong: Bool

    var id: URL { url }
}

enum NotchNeighbors {
    /// Apps known to draw over the notch, by the name they install under.
    static let knownNames: Set<String> = [
        "NotchNook", "Droppy", "Alcove", "boringNotch", "Boring Notch", "DynamicLake",
        "MediaMate", "NotchDrop", "Notchy", "NotchBay", "Atoll",
    ]

    /// Ours, and taught to share.
    static let partners: Set<String> = ["Shotput"]

    /// What's installed in the usual places, partners included.
    static let folders = [
        URL(filePath: "/Applications"),
        URL(filePath: "/Applications/Setapp"),
        URL.homeDirectory.appending(path: "Applications"),
    ]

    static func installed(in folders: [URL] = folders, fileManager: FileManager = .default) -> [NotchNeighbor] {
        var found: [NotchNeighbor] = []
        for folder in folders {
            let items = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for item in items where item.pathExtension == "app" {
                let name = item.deletingPathExtension().lastPathComponent
                if partners.contains(name) {
                    found.append(NotchNeighbor(name: name, url: item, playsAlong: true))
                } else if knownNames.contains(name) {
                    found.append(NotchNeighbor(name: name, url: item, playsAlong: false))
                }
            }
        }
        var seen: Set<String> = []
        return found.filter { seen.insert($0.name).inserted }.sorted { $0.name < $1.name }
    }

    /// Installed apps that would fight Clove for the notch.
    static func rivals() -> [NotchNeighbor] {
        installed().filter { !$0.playsAlong }
    }

    /// The mode to suggest: the menu bar when another notch app is here.
    @MainActor
    static var suggestedMode: AccessMode {
        rivals().isEmpty ? .notch : .menuBar
    }

    /// "NotchNook", "NotchNook and Droppy", "NotchNook, Droppy and Alcove".
    static func list(_ neighbors: [NotchNeighbor]) -> String {
        neighbors.map(\.name).formatted(.list(type: .and))
    }
}
