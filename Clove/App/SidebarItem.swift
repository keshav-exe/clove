import Foundation

/// A row in the main window sidebar.
enum SidebarItem: Hashable, Sendable {
    case home
    case discover
    case library(LibraryFilter)
    case cleanup
    case resources(ResourceKind)
    case secrets
    case running
}
