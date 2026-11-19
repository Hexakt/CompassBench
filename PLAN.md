# CompassBench — plan repensé

Banc d'essai **séparé** de Smoke Signal. But : mesurer, puis réduire, l'erreur
d'azimut du compas iPhone par tous les moyens réalistes. Rien ici n'est publié
avec l'app de signalement.

## Le changement d'approche

La première version comparait des gestuelles en regardant surtout `headingAccuracy`.
Problème : `headingAccuracy` est **l'estimation que l'iPhone fait de sa propre
erreur**. C'est un indice utile, pas la vérité. On peut avoir une accuracy
affichée basse et un azimut faux (biais magnétique local), ou l'inverse.

Nouvelle règle : **enregistrer beaucoup, décider hors ligne.** L'app n'applique
aucun traitement ; elle enregistre à ~20 Hz toutes les grandeurs brutes. Toute
l'intelligence est dans le script d'analyse, qui compare plusieurs estimateurs
et plusieurs réglages à partir d'**une seule** campagne de mesures. On ne refait
pas les tests à chaque idée.

## Deux leviers distincts

1. **La gestuelle** (ce que fait l'utilisateur) : fixe, cercles, huit, viser le sol.
   Elle agit sur l'erreur réelle via la calibration du magnétomètre et la stabilité.
2. **L'estimateur** (ce que fait le code au moment du déclenchement) : prendre un
   instantané, moyenner, pondérer, filtrer. Il agit sur le bruit, pas sur le biais.

On les teste séparément. Une même gestuelle est rejouée hors ligne avec chaque
estimateur, donc 40 essais suffisent à classer 8 gestuelles × 5 estimateurs.

## Ce qui est « plus intelligent » que la v1

- **Référence absolue par le soleil.** Si l'utilisateur vise le soleil (avec
  protection), l'azimut solaire se calcule à partir de l'heure et du GPS, sans
  carte ni boussole. C'est une vérité indépendante du magnétomètre, disponible
  en plein air — exactement le contexte d'un feu. Implémenté dans l'analyse
  (algorithme NOAA, précision ~0,1°).
- **Référence géodésique par point cartographié.** Vous visez un point dont vous
  connaissez les coordonnées ; l'azimut vrai est calculé par la formule du grand
  cercle. C'est la méthode principale.
- **Moyenne circulaire pondérée** par `1/accuracy²` : les instants où l'iPhone
  se dit précis comptent davantage.
- **Filtrage par stabilité** : on ne garde que les échantillons à faible vitesse
  de rotation, champ magnétique calibré et accuracy basse.
- **Calibrage mesuré de `headingAccuracy`.** L'analyse ajuste le rapport
  erreur_réelle / accuracy_affichée sur vos données. C'est la réponse chiffrée à
  votre question du `/2` : au lieu de diviser par deux au jugé, on applique le
  facteur que les mesures donnent.
- **Amplification par l'élévation.** L'erreur d'azimut croît en 1/cos(élévation)
  quand on vise haut ou bas. L'élévation est enregistrée et prise en compte dans
  le cône conseillé.

## Les estimateurs comparés (hors ligne)

| Code | Méthode |
|------|---------|
| E0 | Instantané au déclenchement (ce que fait l'app aujourd'hui) |
| E1 | Moyenne circulaire sur la fenêtre finale |
| E2 | Moyenne pondérée par 1/accuracy² |
| E3 | Moyenne filtrée (rotation faible, champ calibré, accuracy basse) |
| E4 | Meilleur échantillon de la fenêtre |

## Les gestuelles comparées

M0 fixe 1 s · M1 fixe 3 s · M2 sol 3 s puis fixe · M3a/b/c cercles (3 sens) ·
M4 huit lent · M5 cercles rapides (témoin négatif attendu).

## Déroulé pour vous

1. Choisir une cible : un point éloigné cartographié (≥ 300 m), ou le soleil.
2. Pour un point : relever ses coordonnées sur une carte, les saisir dans l'app.
   Votre position et l'heure sont enregistrées seules.
3. Suivre la consigne affichée, lancer l'essai (compte à rebours, puis durée fixe).
4. Répéter : 8 gestuelles × 5 essais ≈ 40 essais, ~25 min. L'ordre est mélangé
   mais reproductible, pour que la fatigue ne pénalise pas toujours la même méthode.
5. Exporter le JSON, me l'envoyer.

Idéalement, refaire la série sur **deux ou trois lieux différents** (dont un près
d'une masse métallique) pour voir si le classement tient.

## L'analyse répond à

- Quel estimateur donne l'erreur la plus basse ? (E0 vs moyennes)
- Quelle gestuelle donne l'erreur la plus basse, et de combien ?
- Quel facteur appliquer à `headingAccuracy` pour un cône honnête ? (le vrai `/2`)
- De combien l'élévation dégrade-t-elle la mesure ?

## Portée vers Smoke Signal

Seules les conclusions remontent dans l'app : le bon facteur de cône, la bonne
fenêtre de visée, l'estimateur retenu, et la décision de garder ou non les
cercles. Le correctif du demi-angle reste traité dans l'autre fil.

## État technique

- `CompassBench/Core` : maths pures (géodésie, stats circulaires, cône),
  testées par `swift test` en CI.
- `CompassBench/App` : app SwiftUI iOS 17, enregistrement des capteurs.
- `analysis/compass_analysis.py` : analyse hors ligne, auto-test inclus (vérifié).
- Non encore compilé sur Mac ni essayé sur iPhone : à traiter comme un premier jet
  jusqu'au premier build et au premier essai réel.
