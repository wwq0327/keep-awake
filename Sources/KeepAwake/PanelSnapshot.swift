import AppKit
import SwiftUI

/// Capture through AppKit so native controls and ScrollView contents are
/// included. ImageRenderer alone omits some AppKit-backed SwiftUI content.
@MainActor
enum PanelSnapshot {
    static func png(model: AppState, appearance: NSAppearance.Name = .aqua) throws -> Data {
        _ = NSApplication.shared
        let view = NSHostingView(rootView: PanelView(model: model)
            .background(Color(nsColor: .windowBackgroundColor)))
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: PanelView.size),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.contentView = view
        view.frame = NSRect(origin: .zero, size: PanelView.size)
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw CocoaError(.fileWriteUnknown)
        }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return png
    }
}
