import Foundation

/// Gestuelles testées avant la visée. On mesure laquelle fait le plus baisser
/// l'erreur réelle, pas seulement l'accuracy affichée.
public enum Gesture: String, CaseIterable, Codable, Identifiable, Sendable {
    case fixed1 = "M0"          // visée fixe 1 s (référence actuelle de l'app)
    case fixed3 = "M1"          // visée fixe 3 s
    case downThenFixed = "M2"   // viser le sol 3 s puis fixe
    case circlesVertical = "M3a"
    case circlesHorizontal = "M3b"
    case circlesDiagonal = "M3c"
    case figure8 = "M4"         // huit lent (calibration magnétomètre)
    case fastCircles = "M5"     // cercles rapides (témoin négatif attendu)

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .fixed1: return "Visée fixe 1 s"
        case .fixed3: return "Visée fixe 3 s"
        case .downThenFixed: return "Sol 3 s, puis fixe"
        case .circlesVertical: return "Cercles haut-bas, puis fixe"
        case .circlesHorizontal: return "Cercles gauche-droite, puis fixe"
        case .circlesDiagonal: return "Cercles diagonale, puis fixe"
        case .figure8: return "Huit lent, puis fixe"
        case .fastCircles: return "Cercles rapides, puis fixe"
        }
    }

    public var instruction: String {
        switch self {
        case .fixed1: return "Visez la cible, téléphone immobile 1 seconde."
        case .fixed3: return "Visez la cible, téléphone immobile 3 secondes."
        case .downThenFixed: return "Visez le sol 3 s, revenez à la verticale, puis restez sur la cible."
        case .circlesVertical: return "10 cercles lents haut-bas en 10 s, puis fixe sur la cible."
        case .circlesHorizontal: return "10 cercles lents gauche-droite en 10 s, puis fixe sur la cible."
        case .circlesDiagonal: return "10 cercles lents en diagonale en 10 s, puis fixe sur la cible."
        case .figure8: return "Un huit lent en l'air pendant 10 s, puis fixe sur la cible."
        case .fastCircles: return "10 cercles rapides en 4 s, puis fixe sur la cible."
        }
    }

    /// Durée totale de l'essai (s). La fenêtre de visée finale est analysée hors ligne.
    public var duration: Double {
        switch self {
        case .fixed1: return 8
        case .fixed3: return 10
        case .downThenFixed: return 14
        default: return 18
        }
    }
}

/// Nature de la cible, qui détermine comment l'azimut de référence est calculé.
public enum TargetKind: String, Codable, Sendable {
    case landmark   // point cartographié : azimut géodésique observateur->cible
    case sun        // soleil : azimut solaire calculé hors ligne
    case manual     // azimut saisi à la main
}

public enum Battery {
    public static let repeats = 5
    /// Ordre mélangé mais reproductible, pour que la fatigue et la dérive ne biaisent pas
    /// systématiquement la même méthode.
    public static func plan(seed: UInt64 = 42) -> [(Gesture, Int)] {
        var items: [(Gesture, Int)] = []
        for g in Gesture.allCases { for i in 1...repeats { items.append((g, i)) } }
        var state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
        func next() -> UInt64 { state ^= state << 13; state ^= state >> 7; state ^= state << 17; return state }
        for i in stride(from: items.count - 1, to: 0, by: -1) {
            let j = Int(next() % UInt64(i + 1))
            items.swapAt(i, j)
        }
        return items
    }
}
