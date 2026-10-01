import Foundation

enum SelfTest {
    static func modelWrite(_ responseURL: URL, project: URL) {
        do {
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: responseURL)) as? [String: Any]
            let message = json?["message"] as? [String: Any]
            let call = (message?["tool_calls"] as? [[String: Any]])?.first
            let fn = call?["function"] as? [String: Any]
            let args = fn?["arguments"] as? [String: Any]
            guard fn?["name"] as? String == "write_file", args?["path"] as? String == "calculator.py", let content = args?["content"] as? String else {
                throw TrixError.message("Model nevrátil očekávaný zápis.")
            }
            try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
            let tools = ProjectTools()
            tools.root = project
            print(try tools.write("calculator.py", content: content))
            guard try tools.read("calculator.py") == content else { throw TrixError.message("Ověření zápisu selhalo.") }
            print("PASS: skutečné volání nástroje modelem bylo provedeno nativním ProjectTools.")
        } catch { fputs("FAIL: \(error.localizedDescription)\n", stderr); exit(1) }
    }
    static func run() {
        do {
            let base = FileManager.default.temporaryDirectory.appendingPathComponent("trix-test-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: base) }
            let tools = ProjectTools()
            tools.root = base
            func rejected(_ path: String) throws {
                do { _ = try tools.resolve(path); throw TrixError.message("Očekáváno odmítnutí: \(path)") }
                catch let error as TrixError {
                    if error.localizedDescription.hasPrefix("Očekáváno") { throw error }
                }
            }
            try rejected("../escape.txt")
            try rejected("/tmp/escape.txt")
            try rejected(".git/config")
            try rejected(".env")
            try FileManager.default.createSymbolicLink(at: base.appendingPathComponent("outside"), withDestinationURL: base.deletingLastPathComponent())
            try rejected("outside/escape.txt")
            try FileManager.default.createSymbolicLink(at: base.appendingPathComponent("dangling"), withDestinationURL: base.deletingLastPathComponent().appendingPathComponent("nonexistent-\(UUID().uuidString)"))
            try rejected("dangling/new.txt")
            try FileManager.default.createSymbolicLink(at: base.appendingPathComponent("hidden"), withDestinationURL: base.appendingPathComponent(".git"))
            try rejected("hidden/config")
            _ = try tools.write("src/example.py", content: "print('ahoj')\n")
            guard try tools.read("src/example.py") == "print('ahoj')\n" else { throw TrixError.message("Zápis/čtení selhalo.") }
            _ = try tools.write("src/example.py", content: "print('TRIX')\n")
            _ = try tools.undo()
            guard try tools.read("src/example.py") == "print('ahoj')\n" else { throw TrixError.message("Vrácení selhalo.") }
            try Data("ruční změna".utf8).write(to: base.appendingPathComponent("src/example.py"))
            do { _ = try tools.undo(); throw TrixError.message("Očekávána ochrana ruční změny.") }
            catch let error as TrixError { if error.localizedDescription.hasPrefix("Očekávána") { throw error } }
            print("PASS: zápis, čtení, vrácení, ochrana ručních úprav, traversal, absolutní cesty, symlinky a citlivé soubory.")
        } catch { fputs("FAIL: \(error.localizedDescription)\n", stderr); exit(1) }
    }
}
