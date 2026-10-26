import AppKit

@MainActor
private final class ResizeTestPopover: NSPopover {
    var visibleForTests = true
    var recordedSizes: [CGSize] = []
    private var size = CGSize(width: 360, height: 100)

    override var isShown: Bool { visibleForTests }
    override var contentSize: NSSize {
        get { size }
        set { size = newValue; recordedSizes.append(newValue) }
    }
}

@main
struct PopoverResizeTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let popover = ResizeTestPopover()
        popover.animates = true
        var now: TimeInterval = 0
        var reduceMotion = false
        let animator = PopoverResizeAnimator(popover: popover, reduceMotion: { reduceMotion }, uptime: { now })
        animator.resize(to: CGSize(width: 360, height: 220))
        assert(animator.isAnimating && popover.contentSize.height == 100)
        now = PopoverResizeAnimator.duration / 2
        animator.advance()
        assert(abs(popover.contentSize.height - 160) < 0.001)
        assert(popover.animates)
        animator.resize(to: CGSize(width: 360, height: 220))
        now = PopoverResizeAnimator.duration
        animator.advance()
        assert(popover.contentSize.height == 220 && !animator.isAnimating)

        animator.resize(to: CGSize(width: 360, height: 100))
        now += PopoverResizeAnimator.duration / 2
        animator.advance()
        let midway = popover.contentSize.height
        animator.resize(to: CGSize(width: 360, height: 300))
        assert(popover.contentSize.height == midway)
        now += PopoverResizeAnimator.duration + 0.001
        animator.advance()
        assert(popover.contentSize.height == 300 && !animator.isAnimating)

        animator.resize(to: CGSize(width: 360, height: 100))
        animator.cancel()
        let cancelledSize = popover.contentSize
        now += 1
        animator.advance()
        assert(popover.contentSize == cancelledSize && !animator.isAnimating)

        animator.resize(to: CGSize(width: 360, height: 100))
        popover.visibleForTests = false
        animator.advance()
        assert(!animator.isAnimating && popover.contentSize == cancelledSize)
        animator.resize(to: CGSize(width: 360, height: 80))
        assert(popover.contentSize.height == 80 && !animator.isAnimating)
        popover.visibleForTests = true

        reduceMotion = true
        animator.resize(to: CGSize(width: 360, height: 200))
        assert(popover.contentSize.height == 200 && !animator.isAnimating)
        reduceMotion = false
        animator.resize(to: CGSize(width: 360, height: 100))
        reduceMotion = true
        animator.advance()
        assert(popover.contentSize.height == 100 && !animator.isAnimating)
        reduceMotion = false
        animator.resize(to: CGSize(width: 420, height: 180))
        assert(popover.contentSize == CGSize(width: 420, height: 180) && !animator.isAnimating)

        let count = popover.recordedSizes.count
        animator.resize(to: popover.contentSize)
        animator.resize(to: CGSize(width: CGFloat.nan, height: 100))
        animator.resize(to: CGSize(width: 360, height: -1))
        assert(popover.recordedSizes.count == count && !animator.isAnimating)

        weak var releasedAnimator: PopoverResizeAnimator?
        do {
            let temporary = PopoverResizeAnimator(popover: popover, reduceMotion: { false })
            releasedAnimator = temporary
            temporary.resize(to: CGSize(width: 420, height: 300))
            assert(temporary.isAnimating)
        }
        assert(releasedAnimator == nil)
        print("Popover resize interpolation, retargeting, cancellation, reduced motion and lifetime checks passed")
    }
}
