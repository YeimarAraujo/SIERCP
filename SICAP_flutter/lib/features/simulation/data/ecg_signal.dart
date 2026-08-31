import 'dart:math';

import 'package:siercp/features/simulation/data/models/ecg_scenario.dart';

/// Parámetros morfológicos de un latido individual. Permiten construir desde un
/// complejo PQRST normal hasta complejos ventriculares anchos, bloqueos de
/// rama, ondas T picudas (hiperkalemia), inversión de T, elevación/descenso del
/// ST, ondas U y espigas de marcapasos.
class _Morph {
  final double pAmp; // amplitud onda P (0 = sin P / no conducida)
  final double pr; // intervalo P-R en segundos (separación P↔R)
  final double qAmp;
  final double rAmp;
  final double sAmp;
  final double qrsWidth; // anchura base del QRS (0.08 normal, ~0.14 ancho)
  final double stShift; // desplazamiento del ST (+ elevación, − descenso)
  final double tAmp; // amplitud T (negativa = invertida)
  final bool peakedT; // T picuda y estrecha (hiperkalemia)
  final double uAmp; // onda U (hipokalemia)
  final bool rsr; // patrón rSR' (bloqueo de rama derecha)
  final bool ventricular; // complejo ventricular ancho y bizarro (sin P)
  final bool pacingSpike; // espiga de marcapasos antes del QRS

  const _Morph({
    this.pAmp = 0.15,
    this.pr = 0.16,
    this.qAmp = -0.05,
    this.rAmp = 1.0,
    this.sAmp = -0.22,
    this.qrsWidth = 0.08,
    this.stShift = 0.0,
    this.tAmp = 0.28,
    this.peakedT = false,
    this.uAmp = 0.0,
    this.rsr = false,
    this.ventricular = false,
    this.pacingSpike = false,
  });

  _Morph copyWith({
    double? pAmp,
    double? pr,
    double? stShift,
    double? tAmp,
    double? qrsWidth,
    bool? peakedT,
    double? uAmp,
    bool? rsr,
  }) =>
      _Morph(
        pAmp: pAmp ?? this.pAmp,
        pr: pr ?? this.pr,
        qAmp: qAmp,
        rAmp: rAmp,
        sAmp: sAmp,
        qrsWidth: qrsWidth ?? this.qrsWidth,
        stShift: stShift ?? this.stShift,
        tAmp: tAmp ?? this.tAmp,
        peakedT: peakedT ?? this.peakedT,
        uAmp: uAmp ?? this.uAmp,
        rsr: rsr ?? this.rsr,
        ventricular: ventricular,
        pacingSpike: pacingSpike,
      );
}

/// Un latido programado en la línea de tiempo: instante del pico R y morfología.
class _Beat {
  final double r;
  final _Morph m;
  const _Beat(this.r, this.m);
}

// Morfologías reutilizables para complejos especiales.
const _Morph _kPOnly =
    _Morph(rAmp: 0, sAmp: 0, qAmp: 0, tAmp: 0); // sólo onda P (no conducida)
const _Morph _kVt = _Morph(
    pAmp: 0, pr: 0, qAmp: 0, rAmp: 1.1, sAmp: -0.2, qrsWidth: 0.15, tAmp: -0.5,
    ventricular: true);
const _Morph _kPvc = _Morph(
    pAmp: 0, pr: 0, qAmp: 0, rAmp: 1.3, sAmp: -0.2, qrsWidth: 0.16, tAmp: -0.55,
    ventricular: true);
const _Morph _kPaced = _Morph(
    pAmp: 0, pr: 0, qAmp: 0, rAmp: 1.0, sAmp: -0.25, qrsWidth: 0.15,
    tAmp: -0.26, ventricular: true, pacingSpike: true);

/// Sintetizador de señal de ECG. Genera de forma perezosa una secuencia de
/// latidos (con su ritmo e irregularidades) y entrega el valor de la señal en
/// milivoltios aproximados para cualquier instante `t` (segundos). Es la única
/// pieza que conoce la "física" de cada ritmo; las pantallas sólo consumen
/// [sample].
class EcgGenerator {
  final EcgRhythm rhythm;
  final double hr; // frecuencia base en lpm

  final List<_Beat> _beats = [];
  double _genTime = 0; // hasta dónde se han generado latidos
  int _idx = 0; // índice de latido para patrones cíclicos
  double _wenckebachPr = 0.16;

  EcgGenerator(this.rhythm, this.hr);

  double get _rr => hr > 0 ? 60.0 / hr : 1.0;

  /// Valor de la señal en `t` segundos.
  double sample(double t) {
    switch (rhythm) {
      case EcgRhythm.vfib:
        return _vfib(t) + _wander(t) * 0.4;
      case EcgRhythm.asystole:
        return _wander(t) * 0.35 + _micro(t) * 0.15;
      case EcgRhythm.torsades:
        return _torsades(t) + _wander(t) * 0.3;
      default:
        return _beatBased(t);
    }
  }

  // ── Generación basada en latidos ──────────────────────────────────────────
  double _beatBased(double t) {
    _ensure(t + 0.8);
    double v = _wander(t) + _micro(t) * 0.06;

    if (rhythm == EcgRhythm.atrialFlutter) {
      v += _flutterBaseline(t);
    } else if (rhythm == EcgRhythm.atrialFibrillation) {
      v += _fibBaseline(t);
    }

    for (final b in _beats) {
      final dt = t - b.r;
      if (dt < -0.34 || dt > 0.50) continue;
      v += _beatContribution(dt, b.m);
    }
    return v;
  }

  double _beatContribution(double dt, _Morph m) {
    double v = 0;

    if (m.pacingSpike) {
      v += _g(dt, -0.045, 0.0035, 0.6);
    }
    if (m.pAmp != 0) {
      v += _g(dt, -m.pr, 0.022, m.pAmp);
    }

    final w = m.qrsWidth;

    if (m.ventricular) {
      v += _g(dt, 0.0, w * 0.95, m.rAmp);
      v += _g(dt, w * 1.25, w * 1.1, -m.rAmp * 0.4);
      v += _g(dt, 0.34, 0.085, m.tAmp);
      return v;
    }

    v += _g(dt, -w * 0.55, w * 0.30, m.qAmp); // Q
    v += _g(dt, 0.0, w * 0.32, m.rAmp); // R
    v += _g(dt, w * 0.85, w * 0.34, m.sAmp); // S
    if (m.rsr) {
      v += _g(dt, w * 1.7, w * 0.34, m.rAmp * 0.5); // R' (BRD)
    }

    final tCenter = 0.21 + w * 1.4;
    if (m.stShift != 0) {
      v += _g(dt, w * 1.3 + 0.05, 0.055, m.stShift);
    }

    final tSigma = m.peakedT ? 0.040 : 0.060;
    final tAmp = m.peakedT ? m.tAmp * 1.7 : m.tAmp;
    v += _g(dt, tCenter, tSigma, tAmp);

    if (m.uAmp != 0) {
      v += _g(dt, tCenter + 0.17, 0.05, m.uAmp);
    }
    return v;
  }

  /// Asegura que existan latidos generados al menos hasta `until` segundos.
  void _ensure(double until) {
    while (_genTime <= until) {
      _generateNext();
      if (_beats.length > 64) {
        _beats.removeRange(0, _beats.length - 48);
      }
    }
  }

  void _generateNext() {
    const base = _Morph();
    switch (rhythm) {
      case EcgRhythm.sinusNormal:
        _push(base, _rr);
        break;
      case EcgRhythm.sinusBradycardia:
        _push(base.copyWith(tAmp: 0.30), _rr);
        break;
      case EcgRhythm.sinusTachycardia:
        _push(base.copyWith(pr: 0.13), _rr);
        break;
      case EcgRhythm.sinusArrhythmia:
        final phase = sin(2 * pi * 0.20 * _genTime);
        _push(base, _rr * (1 + 0.18 * phase));
        break;
      case EcgRhythm.atrialFibrillation:
        final jitter = 0.55 + (_idx % 7) * 0.13; // RR irregular determinista
        _idx++;
        _push(base.copyWith(pAmp: 0.0), _rr * jitter);
        break;
      case EcgRhythm.atrialFlutter:
        _push(base.copyWith(pAmp: 0.0), _rr);
        break;
      case EcgRhythm.svt:
        _push(base.copyWith(pAmp: 0.0, tAmp: 0.20), _rr);
        break;
      case EcgRhythm.vtach:
        _push(_kVt, _rr);
        break;
      case EcgRhythm.pea:
        _push(base.copyWith(tAmp: 0.22), _rr);
        break;
      case EcgRhythm.avBlock1:
        _push(base.copyWith(pr: 0.30), _rr);
        break;
      case EcgRhythm.avBlock2TypeI:
        if (_idx >= 3) {
          _pushBeat(_kPOnly, _rr); // P bloqueada
          _wenckebachPr = 0.16;
          _idx = 0;
        } else {
          _push(base.copyWith(pr: _wenckebachPr), _rr);
          _wenckebachPr += 0.07;
          _idx++;
        }
        break;
      case EcgRhythm.avBlock2TypeII:
        _idx = (_idx + 1) % 3;
        if (_idx == 0) {
          _pushBeat(_kPOnly, _rr);
        } else {
          _push(base.copyWith(pr: 0.18), _rr);
        }
        break;
      case EcgRhythm.avBlock3:
        _generateAvBlock3();
        break;
      case EcgRhythm.rbbb:
        _push(base.copyWith(qrsWidth: 0.14, rsr: true), _rr);
        break;
      case EcgRhythm.lbbb:
        _push(base.copyWith(qrsWidth: 0.15, tAmp: -0.28, stShift: -0.05), _rr);
        break;
      case EcgRhythm.pac:
        _idx = (_idx + 1) % 4;
        if (_idx == 0) {
          _push(base.copyWith(pAmp: 0.22, pr: 0.13), _rr * 0.62);
        } else {
          _push(base, _rr);
        }
        break;
      case EcgRhythm.pvc:
        _idx = (_idx + 1) % 4;
        if (_idx == 0) {
          _push(_kPvc, _rr * 0.60);
          _genTime += _rr * 0.40; // pausa compensadora
        } else {
          _push(base, _rr);
        }
        break;
      case EcgRhythm.bigeminy:
        _idx = (_idx + 1) % 2;
        if (_idx == 0) {
          _push(base, _rr * 0.9);
        } else {
          _push(_kPvc, _rr * 0.55);
          _genTime += _rr * 0.55;
        }
        break;
      case EcgRhythm.trigeminy:
        _idx = (_idx + 1) % 3;
        if (_idx == 0) {
          _push(_kPvc, _rr * 0.55);
          _genTime += _rr * 0.45;
        } else {
          _push(base, _rr * 0.9);
        }
        break;
      case EcgRhythm.hyperkalemia:
        _push(base.copyWith(pAmp: 0.04, qrsWidth: 0.13, peakedT: true, tAmp: 0.5),
            _rr);
        break;
      case EcgRhythm.hypokalemia:
        _push(base.copyWith(tAmp: 0.10, uAmp: 0.16, stShift: -0.05), _rr);
        break;
      case EcgRhythm.ischemia:
        _push(base.copyWith(stShift: -0.10, tAmp: -0.24), _rr);
        break;
      case EcgRhythm.stemi:
        _push(base.copyWith(stShift: 0.28, tAmp: 0.34), _rr);
        break;
      case EcgRhythm.nstemi:
        _push(base.copyWith(stShift: -0.12, tAmp: -0.30), _rr);
        break;
      case EcgRhythm.pericarditis:
        _push(base.copyWith(stShift: 0.12, tAmp: 0.30), _rr);
        break;
      case EcgRhythm.paced:
        _push(_kPaced, _rr);
        break;

      // Ritmos caóticos generados directamente en sample().
      case EcgRhythm.vfib:
      case EcgRhythm.asystole:
      case EcgRhythm.torsades:
        _genTime += 1.0;
        break;
    }
  }

  /// Bloqueo AV completo: QRS de escape lentos y ondas P independientes a su
  /// propio ritmo (disociación auriculo-ventricular).
  void _generateAvBlock3() {
    final escapeRr = _rr; // hr del escenario = ventricular (~40 lpm)
    final r = _genTime + escapeRr;
    _beats.add(_Beat(r, const _Morph(pAmp: 0.0, qrsWidth: 0.13)));
    const pRr = 60.0 / 90.0; // aurículas a ~90 lpm
    double pt = _genTime + pRr * 0.5;
    while (pt < r + escapeRr - 0.05) {
      _beats.add(_Beat(pt + 0.16, _kPOnly));
      pt += pRr;
    }
    _genTime = r;
  }

  void _push(_Morph m, double rr) => _pushBeat(m, rr);

  void _pushBeat(_Morph m, double rr) {
    final r = _genTime + rr;
    _beats.add(_Beat(r, m));
    _genTime = r;
  }

  // ── Líneas de base y ritmos caóticos ──────────────────────────────────────
  double _flutterBaseline(double t) {
    final phase = (t * 5.0) % 1.0; // ondas F en sierra a ~300/min
    return (phase - 0.5) * 0.34;
  }

  double _fibBaseline(double t) =>
      0.05 * sin(2 * pi * 7.3 * t) +
      0.035 * sin(2 * pi * 11.1 * t + 1.3) +
      0.03 * sin(2 * pi * 5.0 * t + 0.4);

  double _vfib(double t) =>
      0.5 * sin(2 * pi * 5.4 * t) * (0.6 + 0.4 * sin(2 * pi * 1.6 * t + 0.9)) +
      0.22 * sin(2 * pi * 8.9 * t + 0.6) +
      0.12 * sin(2 * pi * 12.7 * t + 2.1);

  double _torsades(double t) {
    final env = sin(2 * pi * 0.33 * t); // huso: amplitud crece y decrece
    return 0.75 * env * sin(2 * pi * 3.6 * t);
  }

  double _wander(double t) => 0.02 * sin(2 * pi * 0.25 * t + 0.5);

  double _micro(double t) =>
      0.5 * sin(2 * pi * 31.0 * t) + 0.5 * sin(2 * pi * 47.0 * t + 1.7);

  double _g(double x, double mu, double sigma, double amp) {
    final d = (x - mu) / sigma;
    return amp * exp(-0.5 * d * d);
  }
}
