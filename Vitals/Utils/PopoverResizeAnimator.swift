import AppKit

@MainActor
final class PopoverResizeAnimator {
    static let duration: TimeInterval = 0.18

    private weak var popover: NSPopover?
    private let reduceMotion: () -> Bool
    private let uptime: () -> TimeInterval
    private var timer: Timer?
    private var transition: (from: CGSize, to: CGSize, started: TimeInterval)?

    var isAnimating: Bool { transition != nil }

    init(
        popover: NSPopover,
        reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion },
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.popover = popover
        self.reduceMotion = reduceMotion
        self.uptime = uptime
    }

    func resize(to size: CGSize) {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
              let popover else { return }
        guard transition?.to != size else { return }
        cancel()
        let current = popover.contentSize
        guard current != size else { return }
        guard popover.isShown, !reduceMotion(), current.width == size.width,
              abs(current.height - size.height) > 1 else {
            apply(size, to: popover)
            return
        }

        transition = (current, size, uptime())
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func advance() {
        guard let transition, let popover, popover.isShown else {
            cancel()
            return
        }
        if reduceMotion() {
            apply(transition.to, to: popover)
            cancel()
            return
        }
        let progress = min(1, max(0, (uptime() - transition.started) / Self.duration))
        let eased = progress * progress * (3 - 2 * progress)
        let height = transition.from.height + (transition.to.height - transition.from.height) * eased
        apply(CGSize(width: transition.to.width, height: height), to: popover)
        if progress >= 1 { cancel() }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        transition = nil
    }

    private func apply(_ size: CGSize, to popover: NSPopover) {
        // Each step is immediate: a second AppKit animation would compete with this transition.
        let animates = popover.animates
        popover.animates = false
        popover.contentSize = size
        popover.animates = animates
    }

    deinit { timer?.invalidate() }
}
