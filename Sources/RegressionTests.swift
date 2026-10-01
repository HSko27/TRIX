import Foundation

@MainActor
enum RegressionTests {
    static func live() async {
        let assistant = Assistant()
        let backend = Assistant()
        assistant.ready = true
        var requests = 0
        var opens = 0
        assistant.chatProvider = { messages, allowTools in
            requests += 1
            return try await backend.chat(messages, allowTools: allowTools)
        }
        assistant.toolProvider = { name, args in
            guard name == "open_url", let value = args["url"] as? String, URL(string: value)?.host == "example.com" else {
                throw TrixError.message("Neočekávaný nástroj ve zkoušce.")
            }
            opens += 1
            // No browser is launched by this diagnostic; only the app's decision loop is exercised.
            return "Předáno prohlížeči: \(value)"
        }
        assistant.input = "Otevři webovou stránku https://example.com."
        assistant.submit()
        for _ in 0..<480 {
            if !assistant.busy { break }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        guard !assistant.busy, opens == 1, requests == 1 else {
            assistant.stop()
            fputs("FAIL: živý Qwen, calls=\(requests), opens=\(opens)\n", stderr)
            for line in assistant.lines { print(line.role, line.text) }
            exit(1)
        }
        print("PASS: živý Qwen přes skutečnou smyčku aplikace — jedna žádost modelu, jedno předání akce, okamžitý konec úkolu.")
    }
    static func run() async {
        do {
            func check(_ value: Bool, _ message: String) throws {
                if !value { throw TrixError.message("Regrese: " + message) }
            }
            var visibility = PanelVisibility()
            try check(!visibility.visible, "Panel musí začínat skrytý.")
            visibility.hover(notch: false, panel: false, now: 1)
            try check(!visibility.visible, "Pohyb mimo notch nesmí zobrazit panel.")
            visibility.hover(notch: true, panel: false, now: 2)
            try check(visibility.visible, "Najetí na notch musí zobrazit panel.")
            visibility.hover(notch: false, panel: true, now: 2.1)
            try check(visibility.visible, "Panel nesmí zmizet při přechodu na ovládání.")
            visibility.hover(notch: false, panel: false, now: 3)
            try check(!visibility.visible, "Opuštění musí skrýt panel.")
            visibility.hover(notch: true, panel: false, now: 4)
            visibility.hide()
            visibility.hover(notch: true, panel: false, now: 4.1)
            try check(!visibility.visible, "Sbalení se nesmí okamžitě samo zrušit.")
            visibility.hover(notch: false, panel: false, now: 5)
            visibility.hover(notch: true, panel: false, now: 6)
            try check(visibility.visible, "Další najetí musí fungovat.")

            var ledger = ActionLedger()
            ledger.record("open_url", ["url": "https://EXAMPLE.com"], result: "Otevřeno", success: true)
            try check(ledger.previous("open_url", ["url": "https://example.com/"]) != nil, "Ekvivalentní URL se nesmí provádět znovu.")
            ledger.record("read_file", ["path": "x.py"], result: "původní", success: true)
            ledger.record("run_command", ["command": "test"], result: "původní", success: true)
            ledger.record("write_file", ["path": "x.py", "content": "nový"], result: "zapsáno", success: true)
            try check(ledger.previous("read_file", ["path": "x.py"]) == nil, "Po opravě lze soubor znovu přečíst.")
            try check(ledger.previous("run_command", ["command": "test"]) == nil, "Po opravě lze zopakovat test.")

            let automatic = Assistant()
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("trix-auto-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            automatic.tools.root = folder
            _ = try await automatic.execute("write_file", ["path": "hello.txt", "content": "hotovo"])
            try check(try automatic.tools.read("hello.txt") == "hotovo", "Zápis musí fungovat bez potvrzovacího okna.")
            let commandResult = try await automatic.execute("run_command", ["command": "printf trix-auto"])
            try check(commandResult.contains("trix-auto"), "Příkaz musí fungovat bez potvrzovacího okna.")

            let assistant = Assistant()
            assistant.ready = true
            var executions = 0
            var requests = 0
            var completionWithoutTools = false
            assistant.toolProvider = { _, _ in executions += 1; return "Předáno prohlížeči: https://example.com" }
            assistant.chatProvider = { _, allowTools in
                requests += 1
                if !allowTools { completionWithoutTools = true; return ["role": "assistant", "content": "Hotovo, stránka je otevřená."] }
                // Deliberately broken model asks for the same side effect twice in one response.
                let call: [String: Any] = ["function": ["name": "open_url", "arguments": ["url": "https://example.com"]]]
                return ["role": "assistant", "content": "", "tool_calls": [call, call]]
            }
            assistant.input = "Otevři example.com"
            assistant.submit()
            for _ in 0..<200 { if !assistant.busy { break }; try await Task.sleep(nanoseconds: 10_000_000) }
            try check(!assistant.busy && assistant.task == nil, "Úkol musí přejít do klidu.")
            try check(executions == 1, "Stránka musí být otevřena právě jednou.")
            try check(assistant.lines.contains { $0.role == "assistant" && $0.text.contains("otevřela") }, "Potvrzení akce musí být v ženském rodě.")
            try check(requests == 1 && !completionWithoutTools, "Úspěšné otevření musí skončit bez dalšího dotazu modelu.")

            let denied = Assistant()
            denied.ready = true
            var deniedAttempts = 0
            denied.toolProvider = { _, _ in deniedAttempts += 1; return "Uživatel otevření odmítl." }
            denied.chatProvider = { _, allow in
                if !allow { return ["role": "assistant", "content": "Otevření bylo zrušeno."] }
                let call: [String: Any] = ["function": ["name": "open_url", "arguments": ["url": "https://example.com"]]]
                return ["role": "assistant", "tool_calls": [call]]
            }
            denied.input = "Otevři stránku"
            denied.submit()
            for _ in 0..<200 { if !denied.busy { break }; try await Task.sleep(nanoseconds: 10_000_000) }
            try check(!denied.busy && deniedAttempts == 1, "Odmítnutá akce nesmí opakovaně žádat potvrzení.")

            let cancelled = Assistant()
            cancelled.ready = true
            cancelled.chatProvider = { _, _ in try await Task.sleep(nanoseconds: 1_000_000_000); return ["role": "assistant", "content": "opožděná odpověď"] }
            cancelled.input = "Test"
            cancelled.submit()
            try await Task.sleep(nanoseconds: 20_000_000)
            cancelled.stop()
            try check(!cancelled.busy && !cancelled.voiceProcessing && cancelled.task == nil, "Zastavení musí ihned uvolnit rozhraní.")
            try await Task.sleep(nanoseconds: 40_000_000)
            try check(!cancelled.lines.contains { $0.text == "opožděná odpověď" }, "Zrušený úkol nesmí dodat opožděnou odpověď.")
            let clean = SpeechText.prepare("**Hotovo.** [Stránka](https://example.com)\n```python\nprint('x')\n```")
            try check(!clean.contains("print") && !clean.contains("https") && !clean.contains("*"), "Hlas nesmí číst kód a značky formátování.")
            print("PASS: automatický zápis a příkaz bez dialogu, skrytý panel, hover, sbalení bez znovuotevření, právě jedno otevření URL, konec úkolu, odmítnutí, zastavení, opakované testy po opravě a příprava řeči.")
        } catch { fputs("FAIL: \(error.localizedDescription)\n", stderr); exit(1) }
    }
}
