# CompassBench

Banc d'essai de précision du compas iPhone, **séparé** de Smoke Signal. Il mesure
quelle gestuelle et quel traitement réduisent le plus l'erreur d'azimut, en
enregistrant les données brutes des capteurs et en décidant hors ligne.

Voir [PLAN.md](PLAN.md) pour l'approche complète.

## Structure

- `CompassBench/Core/` — maths pures (géodésie, statistiques circulaires, cône).
  Testées par `swift test`.
- `CompassBench/App/` — app SwiftUI iOS 17 : enregistrement des capteurs, interface.
- `Tests/` — tests du coeur.
- `analysis/compass_analysis.py` — analyse hors ligne (stdlib). Auto-test :
  `python3 analysis/compass_analysis.py --self-test`.
- `.github/workflows/ci.yml` — `swift test` + auto-test de l'analyse sur macOS.

## Utilisation

1. Compiler et installer l'app (Mac ou CI + sideload).
2. Choisir une cible cartographiée éloignée, ou le soleil. Saisir les coordonnées
   de la cible si c'est un point.
3. Suivre les consignes, enregistrer les 40 essais, exporter le JSON.
4. `python3 analysis/compass_analysis.py trials.json`.

## Limites

- `headingAccuracy` est l'auto-estimation de l'iPhone, pas une vérité : seule la
  comparaison à une référence indépendante révèle le biais.
- Cinq essais par méthode suffisent pour un écart net, pas pour une conclusion fine.
- La référence d'azimut doit être indépendante du téléphone.
