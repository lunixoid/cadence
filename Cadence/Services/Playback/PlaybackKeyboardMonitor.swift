import AppKit
import SwiftUI

final class PlaybackKeyboardMonitorService {
    static let shared = PlaybackKeyboardMonitorService()

    private weak var controller: PlaybackController?
    private var eventMonitor: Any?

    private init() {}

    func install(controller: PlaybackController) {
        self.controller = controller
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .systemDefined]) { [weak self] event in
            guard let self else { return event }
            return self.process(event)
        }
    }

    private func process(_ event: NSEvent) -> NSEvent? {
        guard shouldHandle(event) else { return event }
        return handle(event) ? nil : event
    }

    private func shouldHandle(_ event: NSEvent) -> Bool {
        guard event.window?.isKeyWindow == true else { return false }
        return !isTextInputFocused(in: event.window)
    }

    private func handle(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown:
            guard event.keyCode == 49, !event.isARepeat else { return false }
            event.window?.makeFirstResponder(nil)
            perform(.playPause)
            return true

        case .systemDefined:
            guard let action = Self.mediaKeyAction(from: event) else { return false }
            perform(action)
            return true

        default:
            return false
        }
    }

    private func perform(_ action: MediaKeyAction) {
        Task { @MainActor [weak self] in
            guard let controller = self?.controller else { return }
            switch action {
            case .playPause:
                controller.togglePlayPause()
            case .next:
                controller.next()
            case .previous:
                controller.previous()
            }
        }
    }

    private func isTextInputFocused(in window: NSWindow?) -> Bool {
        guard let responder = window?.firstResponder else { return false }

        if let textView = responder as? NSTextView, textView.isFieldEditor {
            return true
        }

        if let textField = responder as? NSTextField,
           textField.isEditable,
           textField.currentEditor() != nil {
            return true
        }

        return false
    }

    private enum MediaKeyAction {
        case playPause
        case next
        case previous
    }

    private static func mediaKeyAction(from event: NSEvent) -> MediaKeyAction? {
        guard event.subtype.rawValue == 8 else { return nil }

        let keyCode = Int((event.data1 & 0xFFFF_0000) >> 16)
        let keyState = Int(event.data1 & 0x0000_00FF)
        guard keyState == 0x0A else { return nil }

        switch keyCode {
        case 16:
            return .playPause
        case 17:
            return .next
        case 18:
            return .previous
        default:
            return nil
        }
    }
}

struct PlaybackKeyboardMonitor: NSViewRepresentable {
    let controller: PlaybackController

    func makeNSView(context: Context) -> NSView {
        PlaybackKeyboardMonitorService.shared.install(controller: controller)
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        PlaybackKeyboardMonitorService.shared.install(controller: controller)
    }
}
