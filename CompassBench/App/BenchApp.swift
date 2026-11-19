#if canImport(SwiftUI)
import SwiftUI
import CoreLocation

@main
struct CompassBenchApp: App {
    var body: some Scene { WindowGroup { BenchView() } }
}

@MainActor
final class BenchModel: ObservableObject {
    @Published var plan = Battery.plan()
    @Published var position = 0
    @Published var trials: [Trial] = []
    @Published var targetKind: TargetKind = .landmark
    @Published var targetLatText = ""
    @Published var targetLonText = ""
    @Published var manualAzimuthText = ""
    @Published var note = ""
    @Published var countdown: Int?
    @Published var running = false
    @Published var message = ""

    let sampler = Sampler()

    private var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("compassbench-trials.json")
    }

    init() { load(); sampler.start() }

    var current: (Gesture, Int)? { position < plan.count ? plan[position] : nil }

    func runTrial() {
        guard let next = current, !running else { return }
        let (gesture, index) = next
        running = true
        message = ""
        Task {
            for n in stride(from: 3, through: 1, by: -1) {
                countdown = n
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            countdown = nil
            sampler.beginTrial()
            let started = Date()
            try? await Task.sleep(nanoseconds: UInt64(gesture.duration * 1_000_000_000))
            let samples = sampler.endTrial()
            let loc = sampler.location
            let observer = loc.map { GeoPoint(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude,
                                              accuracy: $0.horizontalAccuracy) }
            let mid = samples.isEmpty ? nil : samples[samples.count / 2].unix
            let trial = Trial(
                gesture: gesture.rawValue, index: index, targetKind: targetKind.rawValue,
                observer: observer, target: targetPoint(), referenceAzimuth: manualAzimuth(),
                startedAt: started, midUnix: mid, note: note, samples: samples)
            trials.append(trial)
            save()
            position += 1
            note = ""
            running = false
            message = "Essai enregistré : \(samples.count) échantillons."
        }
    }

    private func targetPoint() -> GeoPoint? {
        guard targetKind == .landmark,
              let lat = parse(targetLatText), let lon = parse(targetLonText) else { return nil }
        return GeoPoint(lat: lat, lon: lon, accuracy: nil)
    }
    private func manualAzimuth() -> Double? {
        targetKind == .manual ? parse(manualAzimuthText) : nil
    }
    private func parse(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    func resetAll() { trials = []; position = 0; save() }

    func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.sortedKeys]
        if let data = try? enc.encode(trials) { try? data.write(to: fileURL, options: .atomic) }
    }
    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        trials = (try? dec.decode([Trial].self, from: data)) ?? []
        position = min(trials.count, plan.count)
    }
    var exportURL: URL { fileURL }
}
#endif
