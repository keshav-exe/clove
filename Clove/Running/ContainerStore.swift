import Foundation
import Observation

/// A Docker container, from Docker Desktop, OrbStack, Colima, or anything else
/// the `docker` command talks to.
struct Container: Identifiable, Hashable, Sendable {
    enum State: String, Sendable {
        case running, paused, restarting, exited, created, dead, removing

        var isRunning: Bool { self == .running || self == .restarting }

        var title: String {
            switch self {
            case .running: "Running"
            case .paused: "Paused"
            case .restarting: "Restarting"
            case .exited: "Stopped"
            case .created: "Not started"
            case .dead: "Failed"
            case .removing: "Removing"
            }
        }
    }

    let id: String
    let name: String
    let image: String
    let state: State
    /// Docker's own wording, like "Up 3 hours" or "Exited (0) 2 days ago".
    let status: String
    /// Ports published on this Mac.
    let ports: [Int]

    var localURL: URL? {
        ports.first.flatMap { URL(string: "http://localhost:\($0)") }
    }
}

/// Finds the `docker` command and runs it. Nothing here needs Docker to be
/// installed: without it, Clove says so and offers nothing to click.
enum ContainerScanner {
    enum Failure: Error, Sendable {
        /// No `docker` command anywhere Clove looks.
        case notInstalled
        /// The command exists, but no engine is running to answer it.
        case notRunning
        case failed(String)
    }

    /// Where Docker Desktop, OrbStack, Colima (through Homebrew), and Rancher put it.
    static var executable: String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        let candidates = [
            "/opt/homebrew/bin/docker",
            "/usr/local/bin/docker",
            "\(home)/.orbstack/bin/docker",
            "\(home)/.docker/bin/docker",
            "\(home)/.rd/bin/docker",
            "/Applications/Docker.app/Contents/Resources/bin/docker",
            "/Applications/OrbStack.app/Contents/MacOS/xbin/docker",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    @concurrent
    static func list() async -> Result<[Container], Failure> {
        guard let docker = executable else { return .failure(.notInstalled) }
        let result = await run(docker, ["ps", "--all", "--no-trunc", "--format", "{{json .}}"])
        guard result.status == 0 else {
            let message = result.error.lowercased()
            if message.contains("cannot connect") || message.contains("is the docker daemon running") || message.contains("no such file") {
                return .failure(.notRunning)
            }
            return .failure(.failed(result.error.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        let containers = result.output
            .split(separator: "\n")
            .compactMap { line -> Container? in
                guard let data = line.data(using: .utf8),
                      let row = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return nil }
                return container(from: row)
            }
            .sorted { lhs, rhs in
                if lhs.state.isRunning != rhs.state.isRunning { return lhs.state.isRunning }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        return .success(containers)
    }

    /// `start`, `stop`, or `restart` one container.
    @concurrent
    static func perform(_ verb: String, on id: String) async -> Failure? {
        guard ["start", "stop", "restart"].contains(verb) else { return .failed("Unknown action") }
        guard let docker = executable else { return .notInstalled }
        let result = await run(docker, [verb, id])
        return result.status == 0 ? nil : .failed(result.error.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func container(from row: [String: Any]) -> Container? {
        guard let id = row["ID"] as? String else { return nil }
        let names = (row["Names"] as? String) ?? id
        let stateText = ((row["State"] as? String) ?? "").lowercased()
        return Container(
            id: id,
            name: names.split(separator: ",").first.map(String.init) ?? names,
            image: (row["Image"] as? String) ?? "",
            state: Container.State(rawValue: stateText) ?? .exited,
            status: (row["Status"] as? String) ?? "",
            ports: hostPorts((row["Ports"] as? String) ?? "")
        )
    }

    /// "0.0.0.0:5432->5432/tcp, :::5432->5432/tcp" → [5432]: the ports on this Mac.
    static func hostPorts(_ text: String) -> [Int] {
        var ports: [Int] = []
        for mapping in text.split(separator: ",") where mapping.contains("->") {
            let host = mapping.split(separator: "-").first ?? ""
            if let port = host.split(separator: ":").last.flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) }), !ports.contains(port) {
                ports.append(port)
            }
        }
        return ports
    }

    private struct Output: Sendable {
        let status: Int32
        let output: String
        let error: String
    }

    /// Runs off the main thread, and gives up after 10 seconds so a hung engine
    /// can't hold Clove up. Output is read while the command runs: a pipe holds
    /// only about 64 KB, and a long container list would otherwise stall it.
    @concurrent
    private static func run(_ executable: String, _ arguments: [String]) async -> Output {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
        } catch {
            return Output(status: -1, output: "", error: error.localizedDescription)
        }
        let outReader = Task.detached { out.fileHandleForReading.readDataToEndOfFile() }
        let errReader = Task.detached { err.fileHandleForReading.readDataToEndOfFile() }

        let deadline = Date().addingTimeInterval(10)
        while process.isRunning, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        let timedOut = process.isRunning
        if timedOut { process.terminate() }

        let output = String(data: await outReader.value, encoding: .utf8) ?? ""
        let error = String(data: await errReader.value, encoding: .utf8) ?? ""
        if timedOut {
            return Output(status: -1, output: "", error: "Docker didn't answer in time.")
        }
        return Output(status: process.terminationStatus, output: output, error: error)
    }
}

/// Containers, refreshed while someone is looking, with start, stop, and restart.
@MainActor
@Observable
final class ContainerStore {
    enum Availability: Equatable {
        case unknown
        case notInstalled
        case notRunning
        case ready
    }

    private(set) var containers: [Container] = []
    private(set) var availability: Availability = .unknown
    /// Containers with an action in flight.
    private(set) var busy: Set<Container.ID> = []
    var failure: ManagerFailure?

    var running: [Container] { containers.filter(\.state.isRunning) }

    func refresh() async {
        switch await ContainerScanner.list() {
        case .success(let found):
            containers = found
            availability = .ready
        case .failure(.notInstalled):
            containers = []
            availability = .notInstalled
        case .failure(.notRunning):
            containers = []
            availability = .notRunning
        case .failure(.failed(let message)):
            availability = .ready
            failure = ManagerFailure(title: "Couldn't list containers", message: message)
        }
    }

    /// Polls until the view goes away; the task is cancelled with it. Every 5
    /// seconds while there are containers to show, every 15 while Docker is off.
    func watch() async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(availability == .ready ? 5 : 15))
        }
    }

    func start(_ container: Container) async { await perform("start", container) }
    func stop(_ container: Container) async { await perform("stop", container) }
    func restart(_ container: Container) async { await perform("restart", container) }

    private func perform(_ verb: String, _ container: Container) async {
        guard !busy.contains(container.id) else { return }
        busy.insert(container.id)
        defer { busy.remove(container.id) }
        if case .failed(let message) = await ContainerScanner.perform(verb, on: container.id) {
            failure = ManagerFailure(title: "Couldn't \(verb) \(container.name)", message: message)
        }
        await refresh()
    }
}
