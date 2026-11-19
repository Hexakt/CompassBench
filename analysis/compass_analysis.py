#!/usr/bin/env python3
"""Analyse des essais CompassBench.

Principe : l'app enregistre BEAUCOUP de données brutes (10-30 Hz) pendant chaque
essai ; toute l'intelligence est ici, hors ligne. Une seule campagne de mesures
permet donc de comparer plusieurs estimateurs et plusieurs réglages sans refaire
les tests.

Stdlib uniquement. Usage : python3 compass_analysis.py trials.json [--self-test]
"""
from __future__ import annotations
import json
import math
import statistics
import sys
from collections import defaultdict

# --------------------------------------------------------------------------
# Géodésie : azimut de référence observateur -> cible
# --------------------------------------------------------------------------

def initial_bearing(lat1, lon1, lat2, lon2):
    """Azimut initial du grand cercle, de (lat1,lon1) vers (lat2,lon2), en degrés
    [0,360) par rapport au nord vrai. Suffisant pour une cible éloignée."""
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dlon = math.radians(lon2 - lon1)
    y = math.sin(dlon) * math.cos(phi2)
    x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dlon)
    return (math.degrees(math.atan2(y, x)) + 360) % 360


def haversine_m(lat1, lon1, lat2, lon2):
    r = 6_371_000.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(min(1, math.sqrt(a)))


# --------------------------------------------------------------------------
# Azimut solaire : référence absolue indépendante du magnétomètre
# (algorithme NOAA simplifié ; précision ~0.1°, largement suffisante)
# --------------------------------------------------------------------------

def solar_azimuth(lat, lon, unix_seconds):
    """Azimut du soleil (degrés depuis le nord vrai) pour une position et un
    instant (UTC, secondes Unix). Sert de cible de référence si l'opérateur
    vise le soleil : aucune carte nécessaire."""
    jd = unix_seconds / 86400.0 + 2440587.5
    t = (jd - 2451545.0) / 36525.0
    L0 = (280.46646 + t * (36000.76983 + t * 0.0003032)) % 360
    M = 357.52911 + t * (35999.05029 - 0.0001537 * t)
    Mr = math.radians(M)
    C = (math.sin(Mr) * (1.914602 - t * (0.004817 + 0.000014 * t))
         + math.sin(2 * Mr) * (0.019993 - 0.000101 * t)
         + math.sin(3 * Mr) * 0.000289)
    true_long = L0 + C
    omega = 125.04 - 1934.136 * t
    lam = true_long - 0.00569 - 0.00478 * math.sin(math.radians(omega))
    eps0 = (23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60)
    eps = eps0 + 0.00256 * math.cos(math.radians(omega))
    lam_r, eps_r = math.radians(lam), math.radians(eps)
    decl = math.asin(math.sin(eps_r) * math.sin(lam_r))
    # Équation du temps (minutes)
    y = math.tan(eps_r / 2) ** 2
    L0r = math.radians(L0)
    eot = 4 * math.degrees(
        y * math.sin(2 * L0r) - 2 * 0.016708634 * math.sin(Mr)
        + 4 * 0.016708634 * y * math.sin(Mr) * math.cos(2 * L0r)
        - 0.5 * y * y * math.sin(4 * L0r) - 1.25 * 0.016708634 ** 2 * math.sin(2 * Mr))
    # Heure solaire vraie
    minutes_utc = (unix_seconds % 86400) / 60.0
    true_solar_min = (minutes_utc + eot + 4 * lon) % 1440
    ha = true_solar_min / 4 - 180  # angle horaire, degrés
    ha_r = math.radians(ha)
    lat_r = math.radians(lat)
    zenith = math.acos(math.sin(lat_r) * math.sin(decl)
                       + math.cos(lat_r) * math.cos(decl) * math.cos(ha_r))
    az = math.acos(max(-1, min(1, (math.sin(decl) - math.cos(zenith) * math.sin(lat_r))
                                  / (math.cos(math.radians(90) - zenith + 1e-12) * math.cos(lat_r) + 1e-12))))
    az = math.degrees(az)
    return (360 - az) % 360 if ha > 0 else az % 360


# --------------------------------------------------------------------------
# Statistiques circulaires
# --------------------------------------------------------------------------

def circ_diff(a, b):
    """a - b ramené dans [-180, 180)."""
    return (a - b + 540) % 360 - 180


def circ_mean(angles, weights=None):
    if not angles:
        return None
    if weights is None:
        weights = [1.0] * len(angles)
    s = sum(w * math.sin(math.radians(a)) for a, w in zip(angles, weights))
    c = sum(w * math.cos(math.radians(a)) for a, w in zip(angles, weights))
    if s == 0 and c == 0:
        return None
    return (math.degrees(math.atan2(s, c)) + 360) % 360


def circ_std(angles):
    """Écart-type circulaire (degrés)."""
    if len(angles) < 2:
        return None
    s = sum(math.sin(math.radians(a)) for a in angles) / len(angles)
    c = sum(math.cos(math.radians(a)) for a in angles) / len(angles)
    r = math.hypot(s, c)
    if r <= 1e-9:
        return 180.0
    return math.degrees(math.sqrt(-2 * math.log(r)))


# --------------------------------------------------------------------------
# Estimateurs : plusieurs façons de tirer UN azimut d'une fenêtre d'échantillons
# --------------------------------------------------------------------------

def tail(samples, seconds):
    if not samples:
        return []
    end = samples[-1]["t"]
    return [s for s in samples if s["t"] >= end - seconds]


def usable(s):
    return s.get("bearing") is not None


def est_instant(samples):
    """E0 : dernier échantillon (ce que fait l'app aujourd'hui)."""
    for s in reversed(samples):
        if usable(s):
            return s["bearing"]
    return None


def est_mean(samples, seconds=2):
    """E1 : moyenne circulaire simple sur la fenêtre finale."""
    bs = [s["bearing"] for s in tail(samples, seconds) if usable(s)]
    return circ_mean(bs)


def est_weighted(samples, seconds=2):
    """E2 : moyenne pondérée par 1/accuracy² (les mesures précises comptent plus)."""
    win = [s for s in tail(samples, seconds) if usable(s) and s.get("headingAccuracy")]
    bs = [s["bearing"] for s in win]
    ws = [1.0 / max(s["headingAccuracy"], 0.5) ** 2 for s in win]
    return circ_mean(bs, ws)


def est_gated(samples, seconds=2, max_rate=0.15, max_acc=12):
    """E3 : moyenne sur les seuls échantillons stables (peu de rotation,
    champ calibré, accuracy basse)."""
    win = [s for s in tail(samples, seconds)
           if usable(s) and s.get("rotationRate", 1) <= max_rate
           and (s.get("headingAccuracy") or 99) <= max_acc
           and s.get("magneticFieldAccuracy", 0) >= 1]
    bs = [s["bearing"] for s in win]
    return circ_mean(bs) if bs else est_mean(samples, seconds)


def est_best(samples, seconds=4):
    """E4 : l'échantillon de meilleure accuracy affichée dans la fenêtre."""
    win = [s for s in tail(samples, seconds) if usable(s) and s.get("headingAccuracy")]
    if not win:
        return None
    return min(win, key=lambda s: s["headingAccuracy"])["bearing"]


ESTIMATORS = {
    "E0_instant": est_instant,
    "E1_moyenne": est_mean,
    "E2_ponderee": est_weighted,
    "E3_filtree": est_gated,
    "E4_meilleure": est_best,
}


# --------------------------------------------------------------------------
# Référence d'un essai
# --------------------------------------------------------------------------

def reference_azimuth(trial):
    """Priorité : azimut géodésique si coordonnées cible fournies ; sinon azimut
    solaire si l'essai est marqué 'soleil' ; sinon la valeur saisie à la main."""
    obs = trial.get("observer")
    tgt = trial.get("target")
    if obs and tgt:
        return initial_bearing(obs["lat"], obs["lon"], tgt["lat"], tgt["lon"])
    if trial.get("targetKind") == "sun" and obs and trial.get("samples"):
        t = trial["samples"][len(trial["samples"]) // 2]
        unix = trial.get("midUnix")
        if unix:
            return solar_azimuth(obs["lat"], obs["lon"], unix)
    return trial.get("referenceAzimuth")


def elevation_deg(samples):
    """Élévation moyenne de la visée (0 = horizontale), depuis la gravité."""
    vals = []
    for s in tail(samples, 2):
        gz = s.get("gravityZ")
        if gz is not None:
            vals.append(abs(math.degrees(math.asin(max(-1, min(1, gz))))))
    return statistics.median(vals) if vals else None


# --------------------------------------------------------------------------
# Analyse principale
# --------------------------------------------------------------------------

def analyse(trials):
    rows = []
    for tr in trials:
        samples = tr.get("samples", [])
        if not samples:
            continue
        ref = reference_azimuth(tr)
        row = {"method": tr["method"], "index": tr["index"], "ref": ref,
               "elevation": elevation_deg(samples),
               "acc_final": est_best_accuracy(samples),
               "spread": circ_std([s["bearing"] for s in tail(samples, 2) if usable(s)]),
               "n": len(samples), "errors": {}}
        for name, fn in ESTIMATORS.items():
            est = fn(samples)
            row["errors"][name] = abs(circ_diff(est, ref)) if (est is not None and ref is not None) else None
        rows.append(row)
    return rows


def est_best_accuracy(samples):
    win = [s.get("headingAccuracy") for s in tail(samples, 2) if s.get("headingAccuracy")]
    return statistics.median(win) if win else None


def fmt(v, nd=1):
    return "   —" if v is None else f"{v:>{3+nd}.{nd}f}"


def report(rows):
    print(f"{len(rows)} essais analysés\n")

    # 1) Quel estimateur est le meilleur, toutes méthodes confondues ?
    print("Erreur médiane par estimateur (degrés, toutes méthodes)")
    for name in ESTIMATORS:
        errs = [r["errors"][name] for r in rows if r["errors"][name] is not None]
        if errs:
            print(f"  {name:14} médiane {statistics.median(errs):5.2f}   "
                  f"90e pct {pctl(errs, 90):5.2f}   n={len(errs)}")

    # 2) Quelle procédure de gestuelle est la meilleure ? (sur le meilleur estimateur)
    best_est = min(ESTIMATORS,
                   key=lambda n: statistics.median([r["errors"][n] for r in rows if r["errors"][n] is not None] or [99]))
    print(f"\nProcédure (gestuelle) — erreur médiane avec l'estimateur {best_est}")
    groups = defaultdict(list)
    for r in rows:
        if r["errors"][best_est] is not None:
            groups[r["method"]].append(r["errors"][best_est])
    ranked = sorted(groups.items(), key=lambda kv: statistics.median(kv[1]))
    for rank, (method, errs) in enumerate(ranked, 1):
        accs = [r["acc_final"] for r in rows if r["method"] == method and r["acc_final"] is not None]
        acc_med = statistics.median(accs) if accs else None
        print(f"  {rank}. {method:6} erreur {statistics.median(errs):5.2f}°   "
              f"accuracy affichée {fmt(acc_med)}°   n={len(errs)}")

    # 3) Calibrage headingAccuracy -> erreur réelle (le coeur du /2)
    print("\nCalibrage : erreur réelle vs accuracy affichée")
    pairs = [(r["acc_final"], r["errors"][best_est]) for r in rows
             if r["acc_final"] and r["errors"][best_est] is not None]
    if len(pairs) >= 3:
        k = fit_scale(pairs)
        print(f"  erreur_réelle ≈ {k:.2f} × accuracy_affichée")
        print(f"  => demi-angle du cône conseillé = {k:.2f} × headingAccuracy "
              f"(aujourd'hui l'app applique 0.5)")
        med_ratio = statistics.median([e / a for a, e in pairs])
        print(f"  ratio médian erreur/accuracy = {med_ratio:.2f}")
    else:
        print("  pas assez de points avec référence connue.")

    # 4) Effet de l'élévation
    print("\nEffet de l'élévation de la visée")
    low = [r["errors"][best_est] for r in rows
           if r["errors"][best_est] is not None and (r["elevation"] or 0) <= 20]
    high = [r["errors"][best_est] for r in rows
            if r["errors"][best_est] is not None and (r["elevation"] or 0) > 20]
    if low:
        print(f"  élévation ≤ 20° : erreur médiane {statistics.median(low):5.2f}°  (n={len(low)})")
    if high:
        print(f"  élévation > 20° : erreur médiane {statistics.median(high):5.2f}°  (n={len(high)})")


def pctl(xs, p):
    xs = sorted(xs)
    if not xs:
        return None
    k = (len(xs) - 1) * p / 100
    f = math.floor(k)
    c = min(f + 1, len(xs) - 1)
    return xs[f] + (xs[c] - xs[f]) * (k - f)


def fit_scale(pairs):
    """Pente de la régression erreur = k * accuracy (sans ordonnée, via médiane des ratios
    pour robustesse)."""
    return statistics.median([e / a for a, e in pairs if a > 0])


# --------------------------------------------------------------------------
# Auto-test
# --------------------------------------------------------------------------

def self_test():
    # Azimut géodésique : plein est à l'équateur ~ 90°
    b = initial_bearing(0, 0, 0, 1)
    assert abs(b - 90) < 0.01, b
    # Plein nord
    b = initial_bearing(0, 0, 1, 0)
    assert abs(b) < 0.01 or abs(b - 360) < 0.01, b
    # Perpignan -> un point plein nord
    b = initial_bearing(42.6986, 2.8956, 43.6986, 2.8956)
    assert abs(b) < 0.5, b
    # Stats circulaires autour de 359/1
    assert abs(circ_diff(circ_mean([359, 1, 0]), 0)) < 0.01
    # Solaire : midi solaire approx plein sud dans l'hémisphère nize (lat > decl)
    # 2026-06-21 ~12:00 UTC à lon 0, lat 45 -> azimut proche du sud (180°)
    import calendar
    noon = calendar.timegm((2026, 6, 21, 12, 0, 0, 0, 0, 0))
    az = solar_azimuth(45.0, 0.0, noon)
    assert 150 < az < 210, az
    # Estimateur : bruit blanc autour de 100 -> moyenne ~100
    samples = [{"t": i * 0.1, "bearing": 100 + (i % 3 - 1) * 2, "headingAccuracy": 10,
                "rotationRate": 0.05, "gravityZ": 0.0, "magneticFieldAccuracy": 2}
               for i in range(30)]
    assert abs(circ_diff(est_mean(samples), 100)) < 1.5
    print("self-test OK")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    elif len(sys.argv) >= 2:
        with open(sys.argv[1], encoding="utf-8") as f:
            report(analyse(json.load(f)))
    else:
        sys.exit(__doc__)
