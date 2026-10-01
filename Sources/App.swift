import SwiftUI
import AppKit
import QuartzCore

final class TrixPanel: NSPanel {
    var onDismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onDismiss?() }
}

final class NotchGlowView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let notch = bounds.insetBy(dx: 32, dy: 32)
        let radius: CGFloat = 10
        let outline = NSBezierPath()
        outline.move(to: NSPoint(x: notch.minX, y: bounds.maxY))
        outline.line(to: NSPoint(x: notch.minX, y: notch.minY + radius))
        outline.curve(to: NSPoint(x: notch.minX + radius, y: notch.minY), controlPoint1: NSPoint(x: notch.minX, y: notch.minY + 3), controlPoint2: NSPoint(x: notch.minX + 3, y: notch.minY))
        outline.line(to: NSPoint(x: notch.maxX - radius, y: notch.minY))
        outline.curve(to: NSPoint(x: notch.maxX, y: notch.minY + radius), controlPoint1: NSPoint(x: notch.maxX - 3, y: notch.minY), controlPoint2: NSPoint(x: notch.maxX, y: notch.minY + 3))
        outline.line(to: NSPoint(x: notch.maxX, y: bounds.maxY))
        NSGraphicsContext.saveGraphicsState()
        let purple = NSColor(calibratedRed: 0.68, green: 0.52, blue: 0.96, alpha: 1)
        let shadow = NSShadow()
        // Broad violet halo plus a soft lilac core; no hard contour.
        for (blur, width, opacity) in [(24.0, 8.0, 0.12), (13.0, 4.0, 0.24), (5.0, 1.8, 0.42)] {
            shadow.shadowColor = purple.withAlphaComponent(0.9)
            shadow.shadowBlurRadius = blur
            shadow.shadowOffset = .zero
            shadow.set()
            purple.withAlphaComponent(opacity).setStroke()
            outline.lineWidth = width
            outline.stroke()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let assistant = Assistant()
    let runtime = LocalRuntime()
    var panel: TrixPanel!
    var notchGlow: NSPanel!
    var timer: Timer?
    var visibility = PanelVisibility()
    var screenObserver: NSObjectProtocol?
    var modelTimer: Timer?
    var outsideMonitor: Any?
    var localMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if !UserDefaults.standard.bool(forKey: "nativeCzechVoiceV05") {
            UserDefaults.standard.set("pocket", forKey: "speechEngine")
            UserDefaults.standard.removeObject(forKey: "voiceIdentifier")
            UserDefaults.standard.set(true, forKey: "nativeCzechVoiceV05")
        }
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Ukončit TRIX AI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
        panel = TrixPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.onDismiss = { [weak self] in self?.hide() }
        assistant.prepareBackend = { [weak self] in try await self?.runtime.ensureServer() }
        assistant.showPanel = { [weak self] in self?.showChat() }
        assistant.confirmationWindow = panel
        assistant.speech.onSpeechError = { [weak self] text in self?.assistant.add(text, role: "error") }
        assistant.onTaskFinished = { [weak self] in
            guard let self else { return }
            self.visibility.engaged = false
            self.trackPointer()
        }
        // Keep one view alive: hiding never clears focus, a draft, or the conversation.
        panel.contentView = NSHostingView(rootView: PanelView(assistant: assistant, onChat: { [weak self] in self?.showChat() }, onVoice: { [weak self] in self?.showChat(); self?.assistant.toggleVoice() }, onClose: { [weak self] in self?.hide() }))
        notchGlow = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        notchGlow.isOpaque = false
        notchGlow.backgroundColor = .clear
        notchGlow.hasShadow = false
        notchGlow.ignoresMouseEvents = true
        notchGlow.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        notchGlow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        notchGlow.hidesOnDeactivate = false
        notchGlow.isReleasedWhenClosed = false
        let glowView = NotchGlowView()
        glowView.wantsLayer = true
        let breath = CABasicAnimation(keyPath: "opacity")
        breath.fromValue = 0.65
        breath.toValue = 1.0
        breath.duration = 2.8
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowView.layer?.add(breath, forKey: "softBreathing")
        notchGlow.contentView = glowView
        position()
        panel.orderOut(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.trackPointer() }
        }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.outsideClick() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window == self?.panel { self?.visibility.engaged = true }
            return event
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.position() }
        }
        Task {
            do { try await runtime.ensureServer(); await assistant.check() }
            catch { assistant.status = error.localizedDescription }
        }
        modelTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in guard let self, !self.assistant.busy else { return }; await self.assistant.check() }
        }
    }

    var screen: NSScreen? { NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first }
    var notchHeight: CGFloat { max(screen?.safeAreaInsets.top ?? 0, 12) }
    var hotspot: NSRect {
        guard let screen else { return .zero }
        let left = screen.auxiliaryTopLeftArea
        let right = screen.auxiliaryTopRightArea
        let width = left != nil && right != nil ? max(1, right!.minX - left!.maxX) : 180
        return NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - notchHeight, width: width, height: notchHeight)
    }

    func position() {
        guard let screen else { return }
        if let notchGlow {
            notchGlow.setFrame(hotspot.insetBy(dx: -32, dy: -32), display: true)
            notchGlow.contentView?.needsDisplay = true
            if screen.safeAreaInsets.top > 0 { notchGlow.orderFrontRegardless() }
            else { notchGlow.orderOut(nil) }
        }
        let width: CGFloat = min(500, screen.visibleFrame.width - 24)
        let height: CGFloat = min(590, screen.visibleFrame.height - 24)
        panel.setFrame(NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - notchHeight - height, width: width, height: height), display: true)
    }

    func reveal() {
        guard !panel.isVisible else { return }
        position()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard assistant.pendingAlert == nil else { return }
        visibility.hide()
        panel.orderOut(nil)
    }

    func showChat() {
        visibility.visible = true
        visibility.engaged = true
        visibility.suppressUntilExit = false
        reveal()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showChat()
        return false
    }

    func outsideClick() {
        if panel.isVisible && !panel.frame.contains(NSEvent.mouseLocation) && !hotspot.contains(NSEvent.mouseLocation) { hide() }
    }

    func trackPointer() {
        let point = NSEvent.mouseLocation
        visibility.hover(notch: hotspot.contains(point), panel: panel.isVisible && panel.frame.contains(point), now: Date.timeIntervalSinceReferenceDate)
        if visibility.visible { reveal() }
        else if panel.isVisible && assistant.pendingAlert == nil { panel.orderOut(nil) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        modelTimer?.invalidate()
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        assistant.stop()
    }
}

struct PanelView: View {
    @AppStorage("speechEngine") var voiceEngine = "pocket"
    @ObservedObject var assistant: Assistant
    let onChat: () -> Void
    let onVoice: () -> Void
    let onClose: () -> Void
    @FocusState var focused: Bool
    let accent = Color(red: 0.68, green: 0.52, blue: 0.96)

    var body: some View {
        VStack(spacing: 0) {
            header
            conversation
            composer
        }
        .foregroundStyle(.white.opacity(0.92))
        .background(Color(white: 0.065))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.09), lineWidth: 1))
        .preferredColorScheme(.dark)
        .onChange(of: voiceEngine) { assistant.speech.stopSpeaking() }
    }

    var header: some View {
        HStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: -0.8) {
                Text("tr")
                Text("ı").overlay(alignment: .top) {
                    Circle().fill(accent).frame(width: 3.5, height: 3.5).offset(y: 3)
                }
                Text("x")
            }.font(.system(size: 21, weight: .semibold)).accessibilityElement(children: .ignore).accessibilityLabel("trix")
            Spacer()
            Button(action: assistant.chooseProject) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text(assistant.tools.root == nil ? "Projekt" : assistant.projectName).lineLimit(1)
                }.font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.5))
            }.buttonStyle(.plain).disabled(assistant.busy).help("Vybrat pracovní složku")
            Menu {
                Toggle("Přehrávat odpovědi", isOn: $assistant.speakReplies)
                Picker("Hlas", selection: $voiceEngine) {
                    Text("Český ženský · Pocket").tag("pocket")
                    Text("Starší ženský · VITS").tag("coqui")
                    Text("Zuzana · macOS").tag("system")
                    Text("Jirka · Piper").tag("piper")
                }
                Button("Vyzkoušet hlas") { assistant.speech.say("Ahoj, jsem Trix. Jsem tady pro tebe. Co pro tebe můžu udělat?") }
                Divider()
                Button("Nová konverzace") { assistant.history = []; assistant.lines = [] }.disabled(assistant.busy)
                Button("Zkontrolovat připojení") { Task { await assistant.check() } }
                Button("Ukončit Trix") { NSApp.terminate(nil) }
            } label: { Image(systemName: "ellipsis").frame(width: 25, height: 25).foregroundStyle(.white.opacity(0.5)) }
            .menuStyle(.borderlessButton).fixedSize().help("Nastavení")
            Button(action: onClose) { Image(systemName: "chevron.up").font(.system(size: 11, weight: .medium)).frame(width: 25, height: 25).foregroundStyle(.white.opacity(0.4)) }.buttonStyle(.plain).help("Skrýt")
        }.padding(.horizontal, 24).padding(.top, 26).padding(.bottom, 18)
    }

    var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if !assistant.ready {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Připravíme Trix.").font(.system(size: 28, weight: .medium)).tracking(-0.8)
                            Text("Při prvním spuštění stáhneme model Qwen. Potřebuješ internet, přibližně 7 GB volného místa pro model a ideálně 24 GB paměti. Potom chat i hlas běží na tvém Macu.")
                                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.55)).lineSpacing(4)
                            Text(assistant.status).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                            if assistant.settingUp {
                                if let progress = assistant.downloadProgress { ProgressView(value: progress).tint(accent) }
                                else { ProgressView().controlSize(.small) }
                                Button("Zrušit stažení", action: assistant.stop).buttonStyle(.plain).foregroundStyle(accent)
                            } else {
                                Button("Stáhnout a připravit model", action: assistant.installModel).buttonStyle(.borderedProminent).tint(accent)
                            }
                        }.padding(.top, 40).padding(.bottom, 24)
                    } else if assistant.lines.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Jsem tady.").font(.system(size: 32, weight: .medium)).tracking(-1.0)
                            Text("Co potřebuješ?").font(.system(size: 15)).foregroundStyle(.white.opacity(0.4))
                        }.padding(.top, 90).padding(.bottom, 48)
                        VStack(alignment: .leading, spacing: 18) {
                            shortcut("Otevřít stránku", prompt: "Otevři stránku ", symbol: "arrow.up.right")
                            shortcut("Pracovat na projektu", prompt: "Prohlédni můj projekt a ", symbol: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                    ForEach(assistant.lines) { line in
                        HStack(alignment: .top, spacing: 0) {
                            if line.role == "user" { Spacer(minLength: 36) }
                            VStack(alignment: .leading, spacing: 6) {
                                if line.role == "info" || line.role == "error" {
                                    Label(line.role == "error" ? "Nepodařilo se" : "Průběh", systemImage: line.role == "error" ? "exclamationmark.circle" : "checkmark.circle")
                                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.4))
                                }
                                Text(line.text).font(.system(size: line.role == "info" ? 11 : 14)).lineSpacing(4)
                                    .foregroundStyle(line.role == "info" ? .white.opacity(0.5) : .white.opacity(0.9))
                                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(line.role == "user" ? 14 : 0)
                            .background {
                                if line.role == "user" { RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Color(white: 0.13)) }
                            }
                            if line.role != "user" { Spacer(minLength: 12) }
                        }.id(line.id)
                    }
                    Color.clear.frame(height: 1).id("end")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.bottom, 24)
            }.onChange(of: assistant.lines.count) { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("end", anchor: .bottom) } }
        }
    }

    var composer: some View {
        VStack(spacing: 10) {
            if assistant.busy || assistant.listening || assistant.voiceProcessing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    Text(assistant.listening ? "Poslouchám…" : assistant.voiceProcessing ? "Přepisuji…" : assistant.activity).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                    Spacer()
                    Button(assistant.listening ? "Dokončit" : "Zastavit", action: assistant.listening ? onVoice : assistant.stop).buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(accent)
                }.padding(.horizontal, 5)
            }
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Napiš mi…", text: $assistant.input, axis: .vertical)
                    .lineLimit(1...4).textFieldStyle(.plain).font(.system(size: 14)).focused($focused)
                    .onSubmit { assistant.submit() }.padding(.vertical, 6)
                Button(action: { onVoice() }) {
                    Image(systemName: assistant.listening ? "stop.fill" : "mic").font(.system(size: 15)).frame(width: 28, height: 32)
                        .foregroundStyle(assistant.listening ? accent : .white.opacity(0.5))
                }.buttonStyle(.plain).disabled(assistant.busy || assistant.voiceProcessing).help(assistant.listening ? "Dokončit nahrávání" : "Mluvit")
                Button(action: assistant.submit) {
                    Image(systemName: "arrow.up").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(accent.opacity(canSend ? 1 : 0.25)).clipShape(Circle())
                }.buttonStyle(.plain).disabled(!canSend).help("Odeslat")
            }.padding(12).padding(.leading, 3).background(Color(white: 0.115))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(focused ? accent.opacity(0.45) : .white.opacity(0.06), lineWidth: 1))
            if assistant.changeCount > 0 {
                HStack {
                    Button(action: assistant.undo) { Label("Vrátit poslední úpravu", systemImage: "arrow.uturn.backward") }.buttonStyle(.plain).disabled(assistant.busy)
                    Spacer()
                }.font(.system(size: 10)).foregroundStyle(.white.opacity(0.4)).padding(.horizontal, 5)
            }
        }.padding(.horizontal, 18).padding(.bottom, 18)
    }
    var canSend: Bool { assistant.ready && !assistant.settingUp && !assistant.busy && !assistant.listening && !assistant.voiceProcessing && !assistant.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func shortcut(_ label: String, prompt: String, symbol: String) -> some View {
        Button { assistant.input = prompt; onChat(); focused = true } label: {
            HStack(spacing: 10) { Image(systemName: symbol).frame(width: 17); Text(label); Spacer(); Image(systemName: "arrow.right").font(.system(size: 10)) }
                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
        }.buttonStyle(.plain)
    }
}

@main
struct TrixMain {
    @MainActor static func main() async {
        if CommandLine.arguments.contains("--self-test") { SelfTest.run(); await RegressionTests.run(); return }
        if CommandLine.arguments.contains("--live-test") { await RegressionTests.live(); return }
        if CommandLine.arguments.count == 4, CommandLine.arguments[1] == "--model-write-test" {
            SelfTest.modelWrite(URL(fileURLWithPath: CommandLine.arguments[2]), project: URL(fileURLWithPath: CommandLine.arguments[3])); return
        }
        launch()
    }
    @MainActor static func launch() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
