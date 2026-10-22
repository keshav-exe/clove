import Foundation

/// A row in the main window sidebar.
enum SidebarItem: Hashable, Sendable {
    case discover(DiscoverFeed)
    case library(LibraryFilter)
    case cleanup
    case resources(ResourceKind)
}
