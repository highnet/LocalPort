import SwiftUI
import AppKit

/// Publishes the scroll state of an `HScrollView` so SwiftUI can drive the
/// edge fades and arrow buttons, and can page the strip programmatically.
@MainActor
final class HScrollController: ObservableObject {
    @Published var contentWidth: CGFloat = 0
    @Published var viewportWidth: CGFloat = 0
    @Published var offsetX: CGFloat = 0

    fileprivate weak var scrollView: NSScrollView?

    var canScrollLeading: Bool { offsetX > 1 }
    var canScrollTrailing: Bool { contentWidth - offsetX > viewportWidth + 1 }

    /// Scroll by ~80% of a page. direction < 0 = left, > 0 = right.
    func page(_ direction: CGFloat) {
        guard let scroll = scrollView else { return }
        let clip = scroll.contentView
        let maxX = max(0, contentWidth - viewportWidth)
        let target = min(maxX, max(0, offsetX + direction * viewportWidth * 0.8))
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.allowsImplicitAnimation = true
            clip.animator().setBoundsOrigin(NSPoint(x: target, y: clip.bounds.origin.y))
        }
        scroll.reflectScrolledClipView(clip)
    }
}

/// An NSScrollView that scrolls horizontally from a vertical mouse wheel.
private final class WheelHorizontalScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        // A trackpad horizontal swipe already produces deltaX; let it through.
        // A plain mouse wheel only produces deltaY, so redirect it horizontally.
        if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
            let clip = contentView
            let maxX = max(0, (documentView?.frame.width ?? 0) - clip.bounds.width)
            var delta = event.scrollingDeltaY
            if !event.hasPreciseScrollingDeltas { delta *= 10 } // line-based wheel
            let newX = min(maxX, max(0, clip.bounds.origin.x - delta))
            clip.setBoundsOrigin(NSPoint(x: newX, y: clip.bounds.origin.y))
            reflectScrolledClipView(clip)
        } else {
            super.scrollWheel(with: event)
        }
    }
}

/// A horizontally scrollable area backed by AppKit, hosting SwiftUI content.
struct HScrollView<Content: View>: NSViewRepresentable {
    @ObservedObject var controller: HScrollController
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = WheelHorizontalScrollView()
        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.horizontalScrollElasticity = .allowed
        scroll.verticalScrollElasticity = .none
        scroll.automaticallyAdjustsContentInsets = false

        let host = NSHostingView(rootView: AnyView(content()))
        host.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = host

        let clip = scroll.contentView
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            host.topAnchor.constraint(equalTo: clip.topAnchor),
            host.bottomAnchor.constraint(equalTo: clip.bottomAnchor),
        ])

        controller.scrollView = scroll
        context.coordinator.attach(scroll)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        if let host = scroll.documentView as? NSHostingView<AnyView> {
            host.rootView = AnyView(content())
        }
        DispatchQueue.main.async { context.coordinator.report() }
    }

    @MainActor
    final class Coordinator {
        let controller: HScrollController
        private weak var scroll: NSScrollView?
        nonisolated(unsafe) private var tokens: [NSObjectProtocol] = []

        init(controller: HScrollController) { self.controller = controller }

        func attach(_ scroll: NSScrollView) {
            self.scroll = scroll
            let nc = NotificationCenter.default
            let clip = scroll.contentView
            clip.postsBoundsChangedNotifications = true
            scroll.documentView?.postsFrameChangedNotifications = true
            scroll.postsFrameChangedNotifications = true

            let report: (Notification) -> Void = { [weak self] _ in
                MainActor.assumeIsolated { self?.report() }
            }
            tokens.append(nc.addObserver(forName: NSView.boundsDidChangeNotification,
                                         object: clip, queue: .main, using: report))
            if let doc = scroll.documentView {
                tokens.append(nc.addObserver(forName: NSView.frameDidChangeNotification,
                                             object: doc, queue: .main, using: report))
            }
            tokens.append(nc.addObserver(forName: NSView.frameDidChangeNotification,
                                         object: scroll, queue: .main, using: report))
            DispatchQueue.main.async { [weak self] in self?.report() }
        }

        func report() {
            guard let scroll = scroll, let doc = scroll.documentView else { return }
            let clip = scroll.contentView
            controller.contentWidth = doc.frame.width
            controller.viewportWidth = clip.bounds.width
            controller.offsetX = clip.bounds.origin.x
        }

        deinit { tokens.forEach { NotificationCenter.default.removeObserver($0) } }
    }
}
