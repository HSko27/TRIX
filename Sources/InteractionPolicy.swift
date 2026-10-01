import Foundation

struct ActionLedger {
    private var results: [String: String] = [:]
    private var revision = 0
    private(set) var navigationCompleted = false

    static func key(_ name: String, _ args: [String: Any]) -> String {
        var normalized = args
        if name == "open_url", let value = args["url"] as? String, var parts = URLComponents(string: value) {
            parts.scheme = parts.scheme?.lowercased()
            parts.host = parts.host?.lowercased()
            if parts.path.isEmpty { parts.path = "/" }
            normalized["url"] = parts.string ?? value
        }
        let data = (try? JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys])) ?? Data()
        return name + ":" + String(decoding: data, as: UTF8.self)
    }
    private func lookupKey(_ name: String, _ args: [String: Any]) -> String {
        let key = Self.key(name, args)
        return ["read_file", "list_files", "run_command"].contains(name) ? key + ":revision=\(revision)" : key
    }
    func previous(_ name: String, _ args: [String: Any]) -> String? {
        if ["read_file", "list_files"].contains(name) { return nil }
        return results[lookupKey(name, args)]
    }
    mutating func record(_ name: String, _ args: [String: Any], result: String, success: Bool) {
        results[lookupKey(name, args)] = result
        if name == "write_file" && success { revision += 1 }
        if success && ["open_url", "open_app"].contains(name) { navigationCompleted = true }
    }
}

enum SpeechText {
    static func prepare(_ text: String) -> String {
        var clean = text.replacingOccurrences(of: "```[\\s\\S]*?```", with: "Kód najdeš v panelu.", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "(?m)^\\s*[#>*-]+\\s*", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "[*_`]", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "https?://\\S+", with: "odkaz v panelu", options: .regularExpression)
        return String(clean.prefix(1000)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PanelVisibility {
    var visible = false
    var engaged = false
    var suppressUntilExit = false
    var lastInside: TimeInterval = 0
    mutating func hide() { visible = false; engaged = false; suppressUntilExit = true }
    mutating func hover(notch: Bool, panel: Bool, now: TimeInterval) {
        if suppressUntilExit { if !notch && !panel { suppressUntilExit = false }; return }
        if notch || (visible && panel) { lastInside = now; visible = true }
        else if visible && !engaged && now - lastInside >= 0.5 { visible = false }
    }
}
