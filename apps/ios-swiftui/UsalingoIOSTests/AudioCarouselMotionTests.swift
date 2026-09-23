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

    func testSnapUses420MillisecondsAndEaseOutQuart() {
        let motion = makeMotion(count: 8)
        motion.snap(to: 2, animated: true) { _ in }
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
        XCTAssertEqual(motion.position, displayed + 20, accuracy: 0.001)
        motion.advanceFrame(seconds: 1)
        XCTAssertEqual(motion.position, displayed + 20, accuracy: 0.001)
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

    func testFrictionIsTimeBasedAt60And120Hz() {
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
