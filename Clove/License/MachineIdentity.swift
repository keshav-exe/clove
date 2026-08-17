import Foundation

enum MachineIdentity {
    static var instanceName: String {
        Host.current().localizedName ?? "Mac"
    }
}
