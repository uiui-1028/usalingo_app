import XCTest
import SwiftUI
@testable import UsalingoIOS

@MainActor
final class AudioCarouselMotionTests: XCTestCase {
    func testInterpolationMatchesJavaScript() {
        let center = AudioCarouselStyle(progress: 0)
        XCTAssertEqual(center.scale, 1.06, accuracy: 0.0001)
        XCTAssertEqual(center.depth, 35)
        XCTAssertEqual(center.opacity, 1)
        XCTAssertEqual(center.saturation, 1.08)
        let lower = AudioCarouselStyle(progress: 1)
        XCTAssertEqual(lower.scale, 0.92, accuracy: 0.0001)
        XCTAssertEqual(lower.rotation, -7)
        XCTAssertEqual(lower.depth, -60)
        XCTAssertEqual(lower.opacity, 1 - 0.6 / 2.3, accuracy: 0.0001)
        XCTAssertEqual(AudioCarouselStyle(progress: -2).rotation, 12)
        XCTAssertEqual(AudioCarouselStyle(progress: 2).brightness, 0.68, accuracy: 0.0001)
        XCTAssertEqual(AudioCarouselStyle(progress: 3).opacity, 0.4, accuracy: 0.0001)
    }

    func testPerspectiveKeepsCardCenterFixed() {
        for progress: CGFloat in [-2, -1, 0, 1, 2] {
            let matrix = AudioCarouselProjection(style: .init(progress: progress), isEnabled: true)
                .effectValue(size: CGSize(width: 310, height: 150))
            let x: CGFloat = 155
            let y: CGFloat = 75
            let w = x * matrix.m13 + y * matrix.m23 + matrix.m33
            XCTAssertEqual((x * matrix.m11 + y * matrix.m21 + matrix.m31) / w, x, accuracy: 0.001)
            XCTAssertEqual((x * matrix.m12 + y * matrix.m22 + matrix.m32) / w, y, accuracy: 0.001)
        }
    }

    func testLongDragSnapsDirectlyWithoutReturningToFirstCard() {
        let motion = makeMotion(count: 8)
        motion.beginDrag(at: 1)
        motion.drag(translation: -2.7 * 174, at: 1.1)
        var selections: [Int] = []
        motion.snap(to: 3, animated: true) { selections.append($0) }
        var previous = motion.position
        for _ in 0..<60 {
            motion.advanceFrame(seconds: 1.0 / 120)
            XCTAssertLessThanOrEqual(motion.position, previous)
            previous = motion.position
        }
        XCTAssertEqual(motion.position, -3 * 174, accuracy: 0.001)
        XCTAssertEqual(selections, [3], "キューの移動は最終位置で1回だけ")
        XCTAssertFalse(motion.isMoving)
    }

    func testGentleSnapUses420MillisecondsAndEaseOutQuart() {
        let motion = makeMotion(count: 8)
        motion.snap(to: 2, animated: true, gentle: true) { _ in }
        motion.advanceFrame(seconds: 0.210)
        XCTAssertEqual(motion.position, -348 * 0.9375, accuracy: 0.001)
        XCTAssertTrue(motion.isMoving)
        motion.advanceFrame(seconds: 0.210)
        XCTAssertEqual(motion.position, -348)
        XCTAssertFalse(motion.isMoving)
    }

    func testRubberBandAtBothEnds() {
        let motion = makeMotion(count: 3)
        motion.beginDrag(at: 1)
        motion.drag(translation: 100, at: 1.1)
        XCTAssertEqual(motion.position, 28, accuracy: 0.001)
        motion.endDrag(at: 1.1, animated: false) { XCTAssertEqual($0, 0) }
        XCTAssertEqual(motion.position, 0)
        motion.configure(stride: 174, count: 3, index: 2)
        motion.beginDrag(at: 2)
        motion.drag(translation: -100, at: 2.1)
        XCTAssertEqual(motion.position, -348 - 28, accuracy: 0.001)
        motion.endDrag(at: 2.1, animated: false) { XCTAssertEqual($0, 2) }
        XCTAssertEqual(motion.position, -348)
    }

    func testFastSwipesWithTwoAndThreeCardsFinishInsideDeck() {
        for count in [2, 3] {
            let motion = makeMotion(count: count)
            motion.beginDrag(at: 1)
            motion.drag(translation: -80, at: 1.016)
            var selected: Int?
            motion.endDrag(at: 1.016, animated: true) { selected = $0 }
            finish(motion)
            XCTAssertEqual(selected, count - 1)
            XCTAssertEqual(motion.position, -CGFloat(count - 1) * 174)
            motion.beginDrag(at: 2)
            motion.drag(translation: 80, at: 2.016)
            motion.endDrag(at: 2.016, animated: true) { selected = $0 }
            finish(motion)
            XCTAssertEqual(selected, 0)
        }
    }

    func testFasterReleaseTravelsFurther() {
        func selectedIndex(duration: TimeInterval) -> Int {
            let motion = makeMotion(count: 12)
            motion.beginDrag(at: 1)
            motion.drag(translation: -80, at: 1 + duration)
            var selected = -1
            motion.endDrag(at: 1 + duration, animated: true) { selected = $0 }
            finish(motion)
            return selected
        }
        XCTAssertGreaterThan(selectedIndex(duration: 0.016), selectedIndex(duration: 0.100))
    }

    func testNewDragInterruptsAnimationAtDisplayedPosition() {
        let motion = makeMotion(count: 8)
        motion.snap(to: 3, animated: true) { _ in XCTFail("古い完了処理は呼ばない") }
        motion.advanceFrame(seconds: 0.1)
        let displayed = motion.position
        motion.beginDrag(at: 2)
        XCTAssertEqual(motion.position, displayed)
        motion.drag(translation: 20, at: 2.016)
        let dragged = motion.position
        XCTAssertGreaterThanOrEqual(dragged, displayed, "指の向きへ動く（磁力で張り付くことはある）")
        motion.advanceFrame(seconds: 1)
        XCTAssertEqual(motion.position, dragged, accuracy: 0.001, "古いアニメーションは止まっている")
        motion.stop()
    }

    func testHoldingBeforeReleaseDiscardsStaleVelocity() {
        let motion = makeMotion(count: 10)
        motion.beginDrag(at: 1)
        motion.drag(translation: -100, at: 1.016)
        var selected: Int?
        motion.endDrag(at: 1.2, animated: true) { selected = $0 }
        finish(motion)
        XCTAssertEqual(selected, 1)
    }

    func testReduceMotionSkipsInertiaAndAnimation() {
        let motion = makeMotion(count: 8)
        motion.beginDrag(at: 1)
        motion.drag(translation: -100, at: 1.016)
        var selected: Int?
        motion.endDrag(at: 1.016, animated: false) { selected = $0 }
        XCTAssertEqual(selected, 1)
        XCTAssertFalse(motion.isMoving)
        XCTAssertEqual(motion.position, -174)
    }

    func testAutomaticAdvanceCanReachFirstCardOfNextLap() {
        let motion = makeMotion(count: 3, index: 2)
        var selected: Int?
        motion.snap(to: 3, animated: true) { selected = $0 }
        finish(motion)
        XCTAssertEqual(selected, 3)
        motion.configure(stride: 174, count: 3, index: 0)
        XCTAssertEqual(motion.position, 0)
        XCTAssertFalse(motion.isMoving)
    }

    func testReleaseIsTimeBasedAt60And120Hz() {
        func position(hz: Double) -> CGFloat {
            let motion = makeMotion(count: 30, index: 10)
            motion.beginDrag(at: 1)
            motion.drag(translation: -50, at: 1.016)
            motion.endDrag(at: 1.016, animated: true) { _ in }
            for _ in 0..<Int(hz / 2) { motion.advanceFrame(seconds: 1 / hz) }
            let result = motion.position
            motion.stop()
            return result
        }
        XCTAssertEqual(position(hz: 60), position(hz: 120), accuracy: 8)
    }

    // MARK: - 磁力

    /// 枠から間隔の4分の1までは張り付いて動かない。
    func testDragSticksToTheSlotWithinAQuarter() {
        let motion = makeMotion(count: 8, index: 2)
        motion.beginDrag(at: 1)
        motion.drag(translation: -0.2 * 174, at: 1.1)
        XCTAssertEqual(motion.position, -2 * 174, accuracy: 0.001)
        motion.drag(translation: 0.24 * 174, at: 1.2)
        XCTAssertEqual(motion.position, -2 * 174, accuracy: 0.001)
        motion.stop()
    }

    /// 4分の1を越えると外れ、指より速く次の枠へ向かい、4分の3で次の枠に張り付く。
    func testDragBreaksFreeAndLocksOntoTheNextSlot() {
        let motion = makeMotion(count: 8, index: 2)
        motion.beginDrag(at: 1)
        motion.drag(translation: -0.375 * 174, at: 1.1)
        XCTAssertEqual(motion.position, -2.25 * 174, accuracy: 0.001)
        motion.drag(translation: -0.5 * 174, at: 1.2)
        XCTAssertEqual(motion.position, -2.5 * 174, accuracy: 0.001)
        motion.drag(translation: -0.75 * 174, at: 1.3)
        XCTAssertEqual(motion.position, -3 * 174, accuracy: 0.001)
        motion.stop()
    }

    /// 指で動かすと、枠に吸い付くたびに1回ずつ振動する。同じ枠では繰り返さない。
    func testDetentFiresOncePerSlotWhileDragging() {
        let motion = makeMotion(count: 8)
        var detents = 0
        motion.onDetent = { detents += 1 }
        motion.beginDrag(at: 1)
        for step in 1...30 {
            motion.drag(translation: -CGFloat(step) * 0.1 * 174, at: 1 + Double(step) * 0.1)
        }
        XCTAssertEqual(detents, 3, "0→1→2→3 の3枠")
        motion.stop()
    }

    /// 勢いよくはじくと数枠進み、手で動かしたあとは 0.34 秒以内に止まる。
    func testFlickTravelsSeveralSlotsAndStopsQuickly() {
        let motion = makeMotion(count: 12)
        var detents = 0
        motion.onDetent = { detents += 1 }
        motion.beginDrag(at: 1)
        motion.drag(translation: -80, at: 1.016)
        var selected: Int?
        motion.endDrag(at: 1.016, animated: true) { selected = $0 }
        for _ in 0..<Int(0.34 * 120) { motion.advanceFrame(seconds: 1.0 / 120) }
        XCTAssertFalse(motion.isMoving)
        XCTAssertEqual(selected, 2)
        XCTAssertEqual(detents, 2, "通り過ぎた枠ごとに振動する")
    }

    /// 止まるときに行き先を越えない。
    func testSnapNeverOvershoots() {
        let motion = makeMotion(count: 8)
        motion.snap(to: 3, animated: true) { _ in }
        for _ in 0..<120 {
            motion.advanceFrame(seconds: 1.0 / 120)
            XCTAssertGreaterThanOrEqual(motion.position, -3 * 174 - 0.001)
        }
    }

    /// 自動送りでは振動させない。
    func testGentleSnapDoesNotFireDetents() {
        let motion = makeMotion(count: 8)
        var detents = 0
        motion.onDetent = { detents += 1 }
        motion.snap(to: 1, animated: true, gentle: true) { _ in }
        finish(motion)
        XCTAssertEqual(detents, 0)
    }

    func testLateStepCompletionWhilePausedDoesNotRequestAutomaticAdvance() async throws {
        let player = RadioPlayer()
        XCTAssertFalse(player.isPlaying)
        player.advanceStep()
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.automaticAdvanceRequest, 0)
        player.stop()
    }

    private func makeMotion(count: Int, index: Int = 0) -> AudioCarouselMotion {
        let motion = AudioCarouselMotion()
        motion.configure(stride: 174, count: count, index: index)
        return motion
    }

    private func finish(_ motion: AudioCarouselMotion) {
        for _ in 0..<600 where motion.isMoving { motion.advanceFrame(seconds: 1.0 / 60) }
        XCTAssertFalse(motion.isMoving)
        motion.stop()
    }
}
