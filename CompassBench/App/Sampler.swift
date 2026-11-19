#if canImport(CoreMotion)
import Combine
import CoreLocation
import CoreMotion
import Foundation

/// Enregistre à ~20 Hz toutes les grandeurs utiles pendant un essai.
/// Même repère que Smoke Signal : xTrueNorthZVertical, aucune déclinaison ajoutée.
@MainActor
public final class Sampler: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published public var liveAccuracy: Double?
    @Published public var liveBearing: Double?
    @Published public var liveElevation: Double?
    @Published public var location: CLLocation?
    @Published public var status = "Démarrage…"

    private let manager = CLLocationManager()
    private let motion = CMMotionManager()
    private var heading: CLHeading?
    private var recording = false
    private var trialStart: TimeInterval = 0
    private var buffer: [Sample] = []
    private let minInterval = 0.05

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = kCLHeadingFilterNone
        manager.headingOrientation = .portrait
    }

    public func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
        guard motion.isDeviceMotionAvailable,
              CMMotionManager.availableAttitudeReferenceFrames().contains(.xTrueNorthZVertical) else {
            status = "Orientation nord indisponible sur cet appareil."
            return
        }
        motion.deviceMotionUpdateInterval = 1.0 / 50
        motion.showsDeviceMovementDisplay = true
        motion.startDeviceMotionUpdates(using: .xTrueNorthZVertical, to: .main) { [weak self] m, _ in
            guard let self, let m else { return }
            self.ingest(m)
        }
        status = "Prêt"
    }

    public func stop() {
        motion.stopDeviceMotionUpdates()
        manager.stopUpdatingHeading()
        manager.stopUpdatingLocation()
    }

    public func beginTrial() {
        buffer = []
        trialStart = ProcessInfo.processInfo.systemUptime
        recording = true
        status = "Enregistrement…"
    }

    public func endTrial() -> [Sample] {
        recording = false
        status = "Essai terminé"
        return buffer
    }

    private func ingest(_ m: CMDeviceMotion) {
        let r = m.attitude.rotationMatrix
        let bearing = CompassMath.rearBearing(m31: r.m31, m32: r.m32, m33: r.m33)
        let elev = CompassMath.elevation(gravityZ: m.gravity.z)
        liveBearing = bearing
        liveElevation = elev
        liveAccuracy = heading?.headingAccuracy
        guard recording else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let t = now - trialStart
        if let last = buffer.last, t - last.t < minInterval { return }
        let rate = sqrt(m.rotationRate.x * m.rotationRate.x
                        + m.rotationRate.y * m.rotationRate.y
                        + m.rotationRate.z * m.rotationRate.z)
        buffer.append(Sample(
            t: t,
            unix: Date().timeIntervalSince1970,
            headingAccuracy: heading?.headingAccuracy,
            trueHeading: heading.flatMap { $0.trueHeading >= 0 ? $0.trueHeading : nil },
            magneticHeading: heading?.magneticHeading,
            bearing: bearing,
            elevation: elev,
            gravityZ: m.gravity.z,
            rotationRate: rate,
            magneticFieldAccuracy: Int(m.magneticField.accuracy.rawValue)))
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let last = locations.last, last.horizontalAccuracy >= 0 { location = last }
    }
    public func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }
}
#endif
