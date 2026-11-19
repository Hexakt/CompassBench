import Foundation

/// Un échantillon brut. On enregistre tout ce dont un estimateur hors ligne
/// pourrait avoir besoin, pour ne faire la campagne de mesures qu'une fois.
public struct Sample: Codable, Sendable {
    public let t: Double                  // s depuis le début de l'essai
    public let unix: Double               // horodatage absolu (pour l'azimut solaire)
    public let headingAccuracy: Double?   // valeur Apple brute, degrés
    public let trueHeading: Double?
    public let magneticHeading: Double?
    public let bearing: Double?           // azimut axe optique, nord vrai
    public let elevation: Double?         // degrés, 0 = horizontale
    public let gravityZ: Double
    public let rotationRate: Double       // norme vitesse de rotation, rad/s
    public let magneticFieldAccuracy: Int // CMMagneticFieldCalibrationAccuracy.rawValue
}

/// Une position WGS84.
public struct GeoPoint: Codable, Sendable {
    public let lat: Double
    public let lon: Double
    public let accuracy: Double?
}

/// Un essai complet, sérialisé en JSON pour analysis/compass_analysis.py.
public struct Trial: Codable, Sendable {
    public let gesture: String            // Gesture.rawValue
    public let index: Int
    public let targetKind: String         // TargetKind.rawValue
    public let observer: GeoPoint?
    public let target: GeoPoint?          // cible cartographiée, si landmark
    public let referenceAzimuth: Double?  // azimut saisi, si manual
    public let startedAt: Date
    public let midUnix: Double?           // horodatage médian, pour le solaire
    public let note: String
    public var samples: [Sample]

    enum CodingKeys: String, CodingKey {
        case gesture = "method", index, targetKind, observer, target,
             referenceAzimuth, startedAt, midUnix, note, samples
    }
}
