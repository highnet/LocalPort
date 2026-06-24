import SwiftUI
import AppKit

/// Live geometry of the tab strip, used to decide which edges can scroll.
struct TabScrollMetrics: Equatable {
    var content: CGFloat = 0
    var viewport: CGFloat = 0
    var offset: CGFloat = 0

    var canLeading: Bool { offset > 1 }
    var canTrailing: Bool { content - offset > viewport + 1 }
}

/// Lets SwiftUI ask the underlying scroll view to scroll by a delta (chevrons).
final class TabScrollProxy: ObservableObject {
    var scrollBy: ((CGFloat) -> Void)?
    func scroll(by dx: CGFloat) { scrollBy?(dx) }
}

/// A horizontal scroller backed by NSScrollView so a plain mouse wheel works
/// (vertical wheel deltas are translated to horizontal movement), alongside
/// trackpad swipes. Reports scroll metrics back to SwiftUI for edge fades.
struct HorizontalTabScroller<Content: View>: NSViewRepresentable {
    @Binding var metrics: TabScrollMetrics
    var proxy: TabScrollProxy
    @ViewBuilder var content: Content

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = WheelScrollView()
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.verticalScrollElasticity = .none
        scroll.horizontalScrollElasticity = .allowed
        scroll.automaticallyAdjustsContentInsets = false

        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = hosting

        let clip = scroll.contentView
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            hosting.topAnchor.constraint(equalTo: clip.topAnchor),
            hosting.heightAnchor.constraint(equalTo: clip.heightAnchor),
        ])

        clip.postsBoundsChangedNotifications = true
        clip.postsFrameChangedNotifications = true
        context.coordinator.scroll = scroll
        context.coordinator.hosting = hosting
        context.coordinator.observe(clip)

        proxy.scrollBy = { [weak scroll] dx in
            guard let scroll, let doc = scroll.documentView else { return }
            let maxX = max(0, doc.frame.width - scroll.contentView.bounds.width)
            var origin = scroll.contentView.bounds.origin
            origin.x = min(max(0, origin.x + dx), maxX)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                scroll.contentView.animator().setBoundsOrigin(origin)
            }
            scroll.reflectScrolledClipView(scroll.contentView)
        }

        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.hosting?.rootView = AnyView(content)
        DispatchQueue.main.async { context.coordinator.updateMetrics() }
    }

    @MainActor
    final class Coordinator {
        var parent: HorizontalTabScroller
        weak var scroll: NSScrollView?
        var hosting: NSHostingView<AnyView>?

        init(_ parent: HorizontalTabScroller) { self.parent = parent }

        func observe(_ clip: NSView) {
            NotificationCenter.default.addObserver(
                self, selector: #selector(changed),
                name: NSView.boundsDidChangeNotification, object: clip)
            NotificationCenter.default.addObserver(
                self, selector: #selector(changed),
                name: NSView.frameDidChangeNotification, object: clip)
        }

        @objc func changed() { updateMetrics() }

        func updateMetrics() {
            guard let scroll else { return }
            var m = TabScrollMetrics()
            m.viewport = scroll.contentView.bounds.width
            m.content = scroll.documentView?.frame.width ?? 0
            m.offset = scroll.contentView.bounds.origin.x
            if m != parent.metrics { parent.metrics = m }
        }

        deinit { NotificationCenter.default.removeObserver(self) }
    }
}

/// NSScrollView that maps a mouse wheel's vertical delta onto horizontal scroll.
private final class WheelScrollView: NSScrollView {
    override func scrollWheel(with event: NSEvent) {
        // Precise deltas come from a trackpad and already include horizontal
        // intent; let AppKit handle those normally. A mouse wheel reports
        // only a vertical, non-precise delta, which we redirect sideways.
        if !event.hasPreciseScrollingDeltas && event.scrollingDeltaX == 0 {
            guard let doc = documentView else { return }
            let maxX = max(0, doc.frame.width - contentView.bounds.width)
            var origin = contentView.bounds.origin
            origin.x = min(max(0, origin.x - event.scrollingDeltaY * 16), maxX)
            contentView.scroll(to: origin)
            reflectScrolledClipView(contentView)
        } else {
            super.scrollWheel(with: event)
        }
    }
}
