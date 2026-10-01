import Foundation
import AppKit

enum TrixError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

struct Change {
    let url: URL
    let before: Data?
    let after: Data
}

final class ProjectTools {
    var root: URL?
    var changes: [Change] = []
    var process: Process?

    func resolve(_ path: String) throws -> URL {
        guard let root else { throw TrixError.message("Nejdřív vyber pracovní složku.") }
        guard !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
            throw TrixError.message("Použij relativní cestu uvnitř projektu.")
        }
        let base = try canonical(root)
        let url = try canonical(base.appendingPathComponent(path))
        guard url.path == base.path || url.path.hasPrefix(base.path + "/") else {
            throw TrixError.message("Cesta vede mimo vybraný projekt.")
        }
        let components = url.path.dropFirst(base.path.count).split(separator: "/")
        guard !components.contains(where: { [".git", ".ssh", ".aws", ".env", ".trix"].contains(String($0)) || $0.hasPrefix(".env.") }) else {
            throw TrixError.message("Tento soubor není nástroji zpřístupněn.")
        }
        return url
    }

    private func canonical(_ url: URL, depth: Int = 0) throws -> URL {
        guard depth < 40 else { throw TrixError.message("Příliš mnoho symbolických odkazů.") }
        var parts: [String] = []
        for part in url.pathComponents where part != "/" && part != "." {
            if part == ".." { if !parts.isEmpty { parts.removeLast() } }
            else { parts.append(part) }
        }
        var current = URL(fileURLWithPath: "/")
        for (index, part) in parts.enumerated() {
            let candidate = current.appendingPathComponent(part)
            if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: candidate.path) {
                var resolved = target.hasPrefix("/") ? URL(fileURLWithPath: target) : current.appendingPathComponent(target)
                for rest in parts.dropFirst(index + 1) { resolved.appendPathComponent(rest) }
                return try canonical(resolved, depth: depth + 1)
            }
            current = candidate
        }
        return current
    }

    func list(_ path: String) throws -> String {
        let url = try resolve(path)
        let entries = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        return try entries.sorted { $0.lastPathComponent < $1.lastPathComponent }.prefix(150).map {
            let dir = try $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            return $0.lastPathComponent + (dir ? "/" : "")
        }.joined(separator: "\n")
    }

    func read(_ path: String) throws -> String {
        let url = try resolve(path)
        let size = (try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0
        guard size <= 100_000 else { throw TrixError.message("Soubor je příliš velký; limit je 100 kB.") }
        return try String(contentsOf: url, encoding: .utf8)
    }

    func write(_ path: String, content: String) throws -> String {
        guard !path.isEmpty, content.utf8.count <= 200_000 else { throw TrixError.message("Neplatná cesta nebo příliš velký obsah.") }
        let url = try resolve(path)
        let before = FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
        guard (before?.count ?? 0) <= 1_000_000 else { throw TrixError.message("Původní soubor je příliš velký pro bezpečné vrácení.") }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let after = Data(content.utf8)
        try after.write(to: url, options: .atomic)
        changes.append(Change(url: url, before: before, after: after))
        return "Zapsáno: \(path), \(after.count) bajtů. Změnu lze vrátit v panelu."
    }

    func undo() throws -> String {
        guard let change = changes.last else { return "Žádná změna k vrácení." }
        guard try Data(contentsOf: change.url) == change.after else {
            throw TrixError.message("Soubor se od té doby změnil. Vrácení by přepsalo nové úpravy.")
        }
        if let before = change.before { try before.write(to: change.url, options: .atomic) }
        else { try FileManager.default.trashItem(at: change.url, resultingItemURL: nil) }
        changes.removeLast()
        return "Vráceno: \(change.url.lastPathComponent)"
    }

    func run(_ command: String) async throws -> String {
        guard let root else { throw TrixError.message("Nejdřív vyber pracovní složku.") }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-c", command]
        proc.currentDirectoryURL = root
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("trix-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let handle = try FileHandle(forWritingTo: output)
        proc.standardOutput = handle
        proc.standardError = handle
        process = proc
        defer { process = nil; try? handle.close(); try? FileManager.default.removeItem(at: output) }
        try proc.run()
        var ticks = 0
        do {
            while proc.isRunning {
                try await Task.sleep(nanoseconds: 200_000_000)
                ticks += 1
                if ticks >= 300 { proc.terminate(); throw TrixError.message("Příkaz překročil limit 60 sekund.") }
                let bytes = (try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                if bytes > 2_000_000 { proc.terminate(); throw TrixError.message("Příkaz vytvořil příliš mnoho výstupu.") }
            }
            try Task.checkCancellation()
        } catch { if proc.isRunning { proc.terminate() }; throw error }
        let data = try Data(contentsOf: output)
        return "Exit: \(proc.terminationStatus)\n" + String(decoding: data.prefix(24_000), as: UTF8.self)
    }

    static func definition(_ name: String, _ description: String, _ properties: [String: Any], _ required: [String]) -> [String: Any] {
        ["type": "function", "function": ["name": name, "description": description, "parameters": ["type": "object", "properties": properties, "required": required]]]
    }
    static let string: [String: Any] = ["type": "string"]
    static let definitions: [[String: Any]] = [
        definition("list_files", "Vypíše soubory ve vybrané pracovní složce; path je relativní, pro kořen použij prázdný řetězec.", ["path": string], ["path"]),
        definition("read_file", "Přečte textový soubor uvnitř pracovního projektu.", ["path": string], ["path"]),
        definition("write_file", "Vytvoří nebo přepíše textový soubor v projektu. Nejdříve přečti existující soubor. Vždy pošli kompletní obsah.", ["path": string, "content": string], ["path", "content"]),
        definition("run_command", "Spustí příkaz v pracovní složce na základě zadání uživatele. Používej k testování; nesmí odesílat data ani měnit systém.", ["command": string], ["command"]),
        definition("open_url", "Otevře http nebo https stránku ve výchozím prohlížeči.", ["url": string], ["url"]),
        definition("open_app", "Otevře uživatelem požadovanou aplikaci pomocí bundle ID, například com.apple.Safari.", ["bundle_id": string], ["bundle_id"])
    ]
}
