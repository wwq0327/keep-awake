import AppKit
import SwiftUI

/// Capture through AppKit so native controls and ScrollView contents are
/// included. ImageRenderer alone omits some AppKit-backed SwiftUI content.
@MainActor
enum PanelSnapshot {
    static func png(model: AppState, appearance: NSAppearance.Name = .aqua,
                    showDetails: Bool = false) throws -> Data {
        _ = NSApplication.shared
        let panel = PanelView(model: model)
        let size = showDetails ? panel.detailsSize : PanelView.size
        let view = NSHostingView(rootView: Group {
            if showDetails { panel.details } else { panel }
        }
            .background(Color(nsColor: .windowBackgroundColor)))
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: .borderless, backing: .buffered, defer: false
        )
        window.appearance = NSAppearance(named: appearance)
        window.contentView = view
        view.frame = NSRect(origin: .zero, size: size)
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
