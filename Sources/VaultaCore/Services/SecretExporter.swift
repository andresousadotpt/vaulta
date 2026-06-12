import Foundation

/// Renders a project's secrets into developer-friendly text formats.
public enum SecretExporter {

    public enum Format: String, CaseIterable, Identifiable, Sendable {
        case dotenv          // .env  -> KEY=value
        case direnv          // .envrc -> export KEY=value
        case shell           // export KEY="value"
        case json            // { "KEY": "value" }
        case yaml            // KEY: value
        case dockerEnv       // KEY=value (no quotes, docker --env-file)

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .dotenv: return ".env (dotenv)"
            case .direnv: return ".envrc (direnv)"
            case .shell: return "Shell (export)"
            case .json: return "JSON"
            case .yaml: return "YAML"
            case .dockerEnv: return "Docker env file"
            }
        }

        public var suggestedFileName: String {
            switch self {
            case .dotenv: return ".env"
            case .direnv: return ".envrc"
            case .shell: return "secrets.sh"
            case .json: return "secrets.json"
            case .yaml: return "secrets.yaml"
            case .dockerEnv: return "secrets.env"
            }
        }
    }

    public static func export(_ project: Project, as format: Format) -> String {
        let secrets = project.secrets.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
        switch format {
        case .dotenv:
            return secrets.map { "\(envKey($0.key))=\(dotenvValue($0.value))" }.joined(separator: "\n") + "\n"
        case .dockerEnv:
            return secrets.map { "\(envKey($0.key))=\($0.value)" }.joined(separator: "\n") + "\n"
        case .direnv:
            return secrets.map { "export \(envKey($0.key))=\(dotenvValue($0.value))" }.joined(separator: "\n") + "\n"
        case .shell:
            return secrets.map { "export \(envKey($0.key))=\(shellQuote($0.value))" }.joined(separator: "\n") + "\n"
        case .json:
            var dict = [String: String]()
            for s in secrets { dict[s.key] = s.value }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = (try? encoder.encode(dict)) ?? Data()
            return (String(data: data, encoding: .utf8) ?? "{}") + "\n"
        case .yaml:
            return secrets.map { "\(envKey($0.key)): \(yamlValue($0.value))" }.joined(separator: "\n") + "\n"
        }
    }

    // MARK: - Value escaping

    /// Normalize a secret name into a valid env var key (UPPER_SNAKE_CASE).
    private static func envKey(_ key: String) -> String {
        let upper = key.uppercased()
        let mapped = upper.map { ch -> Character in
            (ch.isLetter || ch.isNumber) ? ch : "_"
        }
        var result = String(mapped)
        if let first = result.first, first.isNumber {
            result = "_" + result
        }
        return result
    }

    /// Quote a value for .env/.envrc when it contains characters that need it.
    private static func dotenvValue(_ value: String) -> String {
        let needsQuoting = value.contains(where: { " \t\"'#$\\\n".contains($0) }) || value.isEmpty
        if !needsQuoting { return value }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private static func shellQuote(_ value: String) -> String {
        // Single-quote and escape embedded single quotes the POSIX way.
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private static func yamlValue(_ value: String) -> String {
        let indicators: Set<Character> = ["!", "&", "*", "?", "|", ">", "%", "@", "`", "\"", "'", "#", ",", "[", "]", "{", "}", ":"]
        let needsQuoting = value.isEmpty ||
            value.contains("\n") ||
            value.contains(": ") ||
            value.hasSuffix(":") ||
            value.contains(" #") ||
            (value.first.map { indicators.contains($0) } ?? false) ||
            value.first == " " || value.last == " "
        if !needsQuoting { return value }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
