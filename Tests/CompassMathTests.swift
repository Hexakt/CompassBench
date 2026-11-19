import XCTest
@testable import CompassBenchCore

final class CompassMathTests: XCTestCase {

    func testDiffWrap() {
        XCTAssertEqual(CompassMath.diff(1, 359), 2, accuracy: 1e-9)
        XCTAssertEqual(CompassMath.diff(359, 1), -2, accuracy: 1e-9)
    }

    func testCircularMeanAcrossNorth() {
        let m = CompassMath.mean([359, 1, 0])!
        XCTAssertLessThan(abs(CompassMath.diff(m, 0)), 1e-6)
    }

    func testWeightedMeanFavoursPreciseSamples() {
        // 100° avec poids fort, 200° avec poids faible -> proche de 100°
        let m = CompassMath.mean([100, 200], weights: [100, 1])!
        XCTAssertLessThan(abs(CompassMath.diff(m, 100)), 2)
    }

    func testStdZeroForConstant() {
        XCTAssertEqual(CompassMath.std([90, 90, 90])!, 0, accuracy: 1e-6)
    }

    func testInitialBearingDueEast() {
        XCTAssertEqual(CompassMath.initialBearing(lat1: 0, lon1: 0, lat2: 0, lon2: 1), 90, accuracy: 0.01)
    }

    func testInitialBearingDueNorth() {
        let b = CompassMath.initialBearing(lat1: 42.6986, lon1: 2.8956, lat2: 43.6986, lon2: 2.8956)
        XCTAssertLessThan(min(b, 360 - b), 0.5)
    }

    func testRearBearingNearVerticalRejected() {
        XCTAssertNil(CompassMath.rearBearing(m31: 0.01, m32: 0.01, m33: 1))
    }

    func testElevationSign() {
        XCTAssertEqual(CompassMath.elevation(gravityZ: 0), 0, accuracy: 1e-6)
        XCTAssertGreaterThan(CompassMath.elevation(gravityZ: 0.5), 0)
    }

    func testConeAmplifiedByElevationAndFloored() {
        let flat = CompassMath.coneHalfAngle(headingAccuracy: 10, elevationDeg: 0, scale: 0.5)
        let steep = CompassMath.coneHalfAngle(headingAccuracy: 10, elevationDeg: 60, scale: 0.5)
        XCTAssertGreaterThan(steep, flat)                 // l'élévation élargit le cône
        XCTAssertGreaterThanOrEqual(
            CompassMath.coneHalfAngle(headingAccuracy: 1, elevationDeg: 0, scale: 0.5), 3) // plancher
    }

    func testBatteryPlanDeterministicAndComplete() {
        let a = Battery.plan(seed: 7)
        let b = Battery.plan(seed: 7)
        XCTAssertEqual(a.map { $0.0.rawValue }, b.map { $0.0.rawValue })
        XCTAssertEqual(a.count, Gesture.allCases.count * Battery.repeats)
    }
}
