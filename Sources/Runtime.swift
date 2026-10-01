import Foundation

@MainActor
final class LocalRuntime {
    var server: Process?
    var log: FileHandle?
    static var project: URL { Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent() }
    static var resources: URL { Bundle.main.resourceURL ?? project }
    static var packaged: Bool { FileManager.default.isExecutableFile(atPath: resources.appendingPathComponent("runtime/python/bin/python3.10").path) }
    static var voiceDirectory: URL { packaged ? resources.appendingPathComponent("Voice") : project.appendingPathComponent("outputs/TRIX-AI") }
    static var whisperDirectory: URL { packaged ? resources.appendingPathComponent("runtime/whisper") : project.appendingPathComponent("work/runtime") }
    static func speechPython(nativeCzech: Bool) -> URL {
        packaged ? resources.appendingPathComponent("runtime/python/bin/python3.10") : project.appendingPathComponent(nativeCzech ? "work/pocket-env/bin/python" : "work/voice-env/bin/python")
    }
    static var dataDirectory: URL {
        packaged ? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TRIX AI") : project.appendingPathComponent("work")
    }
    func ensureServer() async throws {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:11434/api/version")!)
        request.timeoutInterval = 2
        if let (_, response) = try? await URLSession.shared.data(for: request), (response as? HTTPURLResponse)?.statusCode == 200 { return }
        let bundled = Self.resources.appendingPathComponent("runtime/ollama/ollama")
        let embedded = Self.project.appendingPathComponent("work/runtime/Ollama.app/Contents/Resources/ollama")
        let installed = URL(fileURLWithPath: "/Applications/Ollama.app/Contents/Resources/ollama")
        let binary = Self.packaged ? bundled : FileManager.default.isExecutableFile(atPath: embedded.path) ? embedded : installed
        guard FileManager.default.isExecutableFile(atPath: binary.path) else { throw TrixError.message("Chybí lokální runtime Ollama.") }
        try FileManager.default.createDirectory(at: Self.dataDirectory, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = binary
        process.arguments = ["serve"]
        var environment = ProcessInfo.processInfo.environment
        environment["OLLAMA_MODELS"] = Self.dataDirectory.appendingPathComponent("models").path
        environment["OLLAMA_HOST"] = "127.0.0.1:11434"
        environment["OLLAMA_NO_CLOUD"] = "1"
        environment["OLLAMA_NUM_PARALLEL"] = "1"
        environment["OLLAMA_MAX_LOADED_MODELS"] = "1"
        process.environment = environment
        let logURL = Self.dataDirectory.appendingPathComponent("ollama-server.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        log = try FileHandle(forWritingTo: logURL)
        process.standardOutput = log
        process.standardError = log
        try process.run()
        server = process
        for _ in 0..<50 {
            try await Task.sleep(nanoseconds: 200_000_000)
            if let (_, response) = try? await URLSession.shared.data(for: request), (response as? HTTPURLResponse)?.statusCode == 200 { return }
            if !process.isRunning { throw TrixError.message("Ollama se nepodařilo spustit. Podrobnosti jsou v " + logURL.path) }
        }
        throw TrixError.message("Ollama zatím neodpovídá.")
    }
}
