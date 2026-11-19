#if canImport(SwiftUI)
import SwiftUI

struct BenchView: View {
    @StateObject private var model = BenchModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Essai en cours") {
                    if let next = model.current {
                        let (gesture, index) = next
                        Text("\(model.position + 1) / \(model.plan.count) — \(gesture.rawValue), essai \(index)")
                            .font(.headline)
                        Text(gesture.title)
                        Text(gesture.instruction).font(.callout).foregroundStyle(.secondary)
                    } else {
                        Text("Batterie terminée. Exportez le JSON ci-dessous.")
                    }
                    if let c = model.countdown { Text("Début dans \(c)").font(.largeTitle.bold()) }
                    if !model.message.isEmpty { Text(model.message).font(.footnote) }
                }

                LiveSection(sampler: model.sampler)

                Section("Cible de référence") {
                    Picker("Type", selection: $model.targetKind) {
                        Text("Point cartographié").tag(TargetKind.landmark)
                        Text("Soleil").tag(TargetKind.sun)
                        Text("Azimut saisi").tag(TargetKind.manual)
                    }
                    switch model.targetKind {
                    case .landmark:
                        TextField("Latitude cible", text: $model.targetLatText).keyboardType(.numbersAndPunctuation)
                        TextField("Longitude cible", text: $model.targetLonText).keyboardType(.numbersAndPunctuation)
                        Text("Votre position et l'heure sont enregistrées automatiquement.")
                            .font(.caption).foregroundStyle(.secondary)
                    case .sun:
                        Text("Visez le soleil (lunettes requises). L'azimut solaire est calculé hors ligne.")
                            .font(.caption).foregroundStyle(.secondary)
                    case .manual:
                        TextField("Azimut connu en degrés", text: $model.manualAzimuthText).keyboardType(.numbersAndPunctuation)
                    }
                    TextField("Note (distance, obstacle…)", text: $model.note)
                }

                Section {
                    Button(model.running ? "Essai en cours…" : "Lancer l'essai") { model.runTrial() }
                        .disabled(model.running || model.current == nil)
                }

                Section("Données") {
                    Text("Essais enregistrés : \(model.trials.count)")
                    ShareLink("Exporter le JSON", item: model.exportURL)
                    Button("Tout effacer", role: .destructive) { model.resetAll() }
                }
            }
            .navigationTitle("CompassBench")
        }
    }

}

/// Observe directement le Sampler : sans cela, les valeurs en direct ne se rafraîchissent pas.
struct LiveSection: View {
    @ObservedObject var sampler: Sampler

    var body: some View {
        Section("Mesure en direct") {
            row("headingAccuracy", sampler.liveAccuracy)
            row("Azimut axe optique", sampler.liveBearing)
            row("Élévation", sampler.liveElevation)
            Text(sampler.status).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func row(_ label: String, _ value: Double?) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value.map { String(format: "%.1f°", $0) } ?? "—")
                .foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
#endif
