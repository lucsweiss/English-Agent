import AppKit
import SwiftUI

class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .white
        isOpaque = false
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

class FloatingPanelController: ObservableObject {
    static let shared = FloatingPanelController()

    private var panel: FloatingPanel?
    @Published var isLoading = false
    @Published var translatedText: String?
    @Published var errorMessage: String?

    private init() {}

    func showLoading(near point: NSPoint) {
        isLoading = true
        translatedText = nil
        errorMessage = nil
        showPanel(near: point)
    }

    func showTranslation(_ text: String) {
        isLoading = false
        translatedText = text
        errorMessage = nil
    }

    func showError(_ message: String) {
        isLoading = false
        translatedText = nil
        errorMessage = message
    }

    func close() {
        panel?.close()
        panel = nil
        isLoading = false
        translatedText = nil
        errorMessage = nil
    }

    private func showPanel(near point: NSPoint) {
        if panel == nil {
            let panelRect = NSRect(x: 0, y: 0, width: 400, height: 600)
            panel = FloatingPanel(contentRect: panelRect)

            let hostingView = NSHostingView(rootView: ResponseView(controller: self))
            panel?.contentView = hostingView
        }

        guard let panel = panel, let screen = NSScreen.main else { return }

        var origin = point
        origin.x = min(origin.x, screen.visibleFrame.maxX - (panel.frame.width + 20))
        origin.y = max(origin.y - (panel.frame.height + 20), screen.visibleFrame.minY)
        origin.x = max(origin.x, screen.visibleFrame.minX + 20)

        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)
    }
}
