import Foundation

/// Mathématiques pures, sans capteur : testables en CI par `swift test`.
/// Les mêmes formules sont rejouées hors ligne par analysis/compass_analysis.py.
public enum CompassMath {

    // MARK: Normalisation et écarts

    public static func normalize(_ deg: Double) -> Double {
        (deg.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    /// a - b ramené dans [-180, 180).
    public static func diff(_ a: Double, _ b: Double) -> Double {
        (a - b + 540).truncatingRemainder(dividingBy: 360) - 180
    }

    // MARK: Statistiques circulaires

    /// Moyenne circulaire, éventuellement pondérée. nil si l'entrée est vide.
    public static func mean(_ angles: [Double], weights: [Double]? = nil) -> Double? {
        guard !angles.isEmpty else { return nil }
        let w = weights ?? Array(repeating: 1, count: angles.count)
        var s = 0.0, c = 0.0
        for (a, wi) in zip(angles, w) {
            s += wi * sin(a * .pi / 180)
            c += wi * cos(a * .pi / 180)
        }
        if s == 0 && c == 0 { return nil }
        return normalize(atan2(s, c) * 180 / .pi)
    }

    /// Écart-type circulaire (degrés). nil si moins de deux valeurs.
    public static func std(_ angles: [Double]) -> Double? {
        guard angles.count >= 2 else { return nil }
        let s = angles.map { sin($0 * .pi / 180) }.reduce(0, +) / Double(angles.count)
        let c = angles.map { cos($0 * .pi / 180) }.reduce(0, +) / Double(angles.count)
        let r = (s * s + c * c).squareRoot()
        if r <= 1e-9 { return 180 }
        return (-2 * log(r)).squareRoot() * 180 / .pi
    }

    // MARK: Azimut optique arrière (repère xTrueNorthZVertical)

    /// Azimut de l'axe optique arrière à partir de la matrice d'attitude, nord vrai.
    public static func rearBearing(m31: Double, m32: Double, m33: Double) -> Double? {
        guard [m31, m32, m33].allSatisfy(\.isFinite), hypot(m31, m32) >= 0.05 else { return nil }
        return normalize(atan2(m32, -m31) * 180 / .pi)
    }

    /// Élévation de l'axe optique (0 = horizontale, +90 = vers le ciel), depuis la gravité.
    public static func elevation(gravityZ: Double) -> Double {
        asin(max(-1, min(1, gravityZ))) * 180 / .pi
    }

    // MARK: Géodésie — azimut de référence observateur -> cible

    /// Azimut initial du grand cercle, nord vrai, degrés [0,360).
    public static func initialBearing(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let p1 = lat1 * .pi / 180, p2 = lat2 * .pi / 180
        let dl = (lon2 - lon1) * .pi / 180
        let y = sin(dl) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
        return normalize(atan2(y, x) * 180 / .pi)
    }

    // MARK: Cône d'incertitude

    /// Demi-angle du cône à transmettre. Combine l'accuracy brute mise à l'échelle,
    /// l'amplification par l'élévation (1/cos) et un plancher. Le portail reçoit un demi-angle.
    public static func coneHalfAngle(headingAccuracy: Double, elevationDeg: Double,
                                     scale: Double, floorDeg: Double = 3, capDeg: Double = 45) -> Double {
        let elev = min(abs(elevationDeg), 80) * .pi / 180
        let amplified = headingAccuracy * scale / max(cos(elev), 0.17)
        return min(capDeg, max(floorDeg, amplified))
    }
}
