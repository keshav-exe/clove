import Foundation
import Testing
@testable import Clove

struct ContainerScannerTests {
    @Test func readsHostPortsOnce() {
        #expect(ContainerScanner.hostPorts("0.0.0.0:5432->5432/tcp, :::5432->5432/tcp") == [5432])
        #expect(ContainerScanner.hostPorts("0.0.0.0:3000->3000/tcp, 0.0.0.0:9229->9229/tcp") == [3000, 9229])
        #expect(ContainerScanner.hostPorts("6379/tcp").isEmpty, "an unpublished port isn't reachable from this Mac")
        #expect(ContainerScanner.hostPorts("").isEmpty)
    }

    @Test func readsADockerPsRow() throws {
        let row: [String: Any] = [
            "ID": "abc123",
            "Names": "postgres,db-alias",
            "Image": "postgres:16",
            "State": "running",
            "Status": "Up 3 hours",
            "Ports": "0.0.0.0:5432->5432/tcp",
        ]
        let container = try #require(ContainerScanner.container(from: row))
        #expect(container.name == "postgres")
        #expect(container.state == .running)
        #expect(container.localURL == URL(string: "http://localhost:5432"))
    }

    @Test func unknownStatesCountAsStopped() throws {
        let container = try #require(ContainerScanner.container(from: ["ID": "x", "State": "weird"]))
        #expect(container.state == .exited)
        #expect(!container.state.isRunning)
    }
}
