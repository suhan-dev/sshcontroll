import AppKit
import SwiftUI

struct KeyHandlingView: NSViewRepresentable {
    @EnvironmentObject private var model: AppModel

    func makeNSView(context: Context) -> NSView {
        let view = KeyCatcherView()
        view.onKeyDown = { event in
            if model.isCodeWorkspaceInlineActive,
               event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "[" {
                model.closeCodeWorkspaceInline()
                return nil
            }
            if event.keyCode == 53 {
                if event.modifierFlags.contains(.shift) {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                    return nil
                }
                if model.isCodeWorkspaceInlineActive {
                    model.closeCodeWorkspaceInline()
                    return nil
                }
                if model.selectedSurface == .codex {
                    Task { await model.codexKey("esc") }
                    return nil
                }
                if model.selectedSurface == .claude {
                    Task { await model.claudeKey("esc") }
                    return nil
                }
            }
            return event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class KeyCatcherView: NSView {
    var monitor: Any?
    var onKeyDown: ((NSEvent) -> NSEvent?)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupMonitor()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupMonitor()
    }

    private func setupMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.onKeyDown?(event) ?? event
        }
    }
}
