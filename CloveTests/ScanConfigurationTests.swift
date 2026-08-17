import Foundation
import Testing
@testable import Clove

struct ScanConfigurationTests {
    @Test func skipsFoldersMacOSProtects() {
        // Documents, Desktop, and Downloads are TCC protected, so they must never
        // be scanned without the user picking them.
        let protectedNames = ["Documents", "Desktop", "Downloads"]
        for name in protectedNames {
            #expect(!ScanConfiguration.conventionalProjectFolders.contains(name))
        }
    }

    @Test func keepsCustomRootsUnique() {
        let home = URL(filePath: "/tmp/clove-home-\(UUID().uuidString)")
        let custom = URL(filePath: "/tmp/clove-projects")
        let configuration = ScanConfiguration.make(
            customRoots: [custom, custom],
            home: home
        )
        #expect(configuration.projectRoots == [custom])
    }

    @Test func togglesPropagate() {
        let configuration = ScanConfiguration.make(
            includePlugins: false,
            includeProjects: false,
            home: URL(filePath: "/tmp/clove-home")
        )
        #expect(!configuration.includePlugins)
        #expect(!configuration.includeProjects)
    }
}
