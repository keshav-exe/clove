import Foundation

/// Claude Code's `permissions` block: rules for what runs without asking.
enum PermissionsParser {
    static func permissions(inJSON data: Data, file: URL, scope: ResourceScope) -> [AgentResource] {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let permissions = root["permissions"] as? [String: Any]
        else { return [] }

        let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        var resources: [AgentResource] = []
        for (list, verdict) in [("allow", "Allowed"), ("ask", "Asks first"), ("deny", "Blocked")] {
            for rule in (permissions[list] as? [String]) ?? [] {
                resources.append(AgentResource(
                    id: "permission:" + file.path(percentEncoded: false) + "#" + list + "#" + rule,
                    kind: .permissions,
                    agent: .claudeCode,
                    scope: scope,
                    name: SecretRedactor.redact(rule),
                    summary: verdict,
                    fileURL: file,
                    configKey: list + "#" + rule,
                    details: [
                        ResourceDetail(label: "Rule", value: SecretRedactor.redact(rule), isCode: true),
                        ResourceDetail(label: "Effect", value: verdict),
                    ],
                    modifiedAt: modified ?? .distantPast
                ))
            }
        }
        return resources
    }
}
