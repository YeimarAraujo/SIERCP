import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/simulation/data/aed/wav_generator.dart';
import 'package:siercp/features/simulation/presentation/pages/theoretical_cases_screen.dart';

const _kQuizQuestionsPerSession = 5;

class RandomQuizScreen extends StatefulWidget {
  const RandomQuizScreen({super.key});

  @override
  State<RandomQuizScreen> createState() => _RandomQuizScreenState();
}

class _RandomQuizScreenState extends State<RandomQuizScreen> {
  static const _difficulties = ['Básico', 'Intermedio', 'Avanzado'];
  static const _difficultyIcons = [
    Icons.looks_one,
    Icons.looks_two,
    Icons.looks_3,
  ];
  static const _difficultyColors = [
    Color(0xFF059669),
    AppColors.amber,
    AppColors.red,
  ];

  void _startQuiz(String difficulty) {
    final rng = Random();
    final pool = kTheoreticalCases
        .where((c) => (c as dynamic).difficulty == difficulty)
        .toList()
      ..shuffle(rng);
    final selected = pool.take(min(5, pool.length)).toList();
    final items = <_QuizItem>[];
    for (final c in selected) {
      final qs = List<dynamic>.from(c.questions)..shuffle(rng);
      final take = min(qs.length, 2);
      for (int i = 0; i < take; i++) {
        items.add(_QuizItem(case_: c, question: qs[i]));
      }
    }
    items.shuffle(rng);
    final count = min(items.length, _kQuizQuestionsPerSession);
    final session = items.take(count).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RandomQuizDetailScreen(
          difficulty: difficulty,
          items: session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: textP),
                      onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 4),
                  Text('Evaluación Aleatoria',
                      style: TextStyle(
                          color: textP,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Selecciona la dificultad',
                  style: TextStyle(
                      color: textP,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Se elegirán $_kQuizQuestionsPerSession preguntas al azar',
                  style: TextStyle(color: textS, fontSize: 12)),
            ),
            const SizedBox(height: 24),
            ...List.generate(_difficulties.length, (i) {
              final diff = _difficulties[i];
              final color = _difficultyColors[i];
              final icon = _difficultyIcons[i];
              final count = kTheoreticalCases
                  .where((c) => (c as dynamic).difficulty == diff)
                  .length;
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _startQuiz(diff),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.2),
                            width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(diff,
                                    style: TextStyle(
                                        color: textP,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                Text('$count casos disponibles',
                                    style:
                                        TextStyle(color: textS, fontSize: 11)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: theme.colorScheme.outline, size: 22),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Item: question + case pairing ───────────────────────────────────────────

class _QuizItem {
  final dynamic case_;
  final dynamic question;
  const _QuizItem({required this.case_, required this.question});
}

// ─── Pantalla del quiz (elevada sobre el shell) ────────────────────────────

class _RandomQuizDetailScreen extends StatefulWidget {
  final String difficulty;
  final List<_QuizItem> items;
  const _RandomQuizDetailScreen({
    required this.difficulty,
    required this.items,
  });

  @override
  State<_RandomQuizDetailScreen> createState() =>
      _RandomQuizDetailScreenState();
}

class _RandomQuizDetailScreenState extends State<_RandomQuizDetailScreen> {
  int _currentQ = 0;
  int? _selectedAnswer;
  bool _answered = false;
  int _correctCount = 0;
  bool _finished = false;
  final List<bool> _results = [];
  final List<int> _timePerQuestion = [];
  int _xpEarned = 0;
  int _levelAfter = 0;

  Timer? _questionTimer;
  int _timeLeft = 30;
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _totalTimeUsed = 0;
  bool _tickPlayed = false;

  Color get _accentColor => widget.items.isNotEmpty
      ? (widget.items[_currentQ].case_ as dynamic).color as Color
      : AppColors.brand;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startTimer() {
    _questionTimer?.cancel();
    _timeLeft = 30;
    _tickPlayed = false;
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _timeLeft--;
        _totalTimeUsed++;
        _playTickSound();
        if (_timeLeft <= 0 && !_answered) {
          _questionTimer?.cancel();
          _playTimeoutSound();
          HapticFeedback.heavyImpact();
          _autoAdvance();
        }
      });
    });
  }

  void _autoAdvance() {
    _answered = true;
    _results.add(false);
    _timePerQuestion.add(30);
    if (_currentQ < widget.items.length - 1) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          _currentQ++;
          _selectedAnswer = null;
          _answered = false;
        });
        _startTimer();
      });
    } else {
      _finishQuiz();
    }
  }

  void _selectAnswer(int idx) {
    if (_answered) return;
    _questionTimer?.cancel();
    final q = widget.items[_currentQ].question;
    final correct = idx == q.correctIndex;
    _timePerQuestion.add(30 - _timeLeft);
    setState(() {
      _selectedAnswer = idx;
      _answered = true;
      if (correct) {
        _correctCount++;
        _playCorrectSound();
        HapticFeedback.heavyImpact();
      } else {
        _playWrongSound();
        HapticFeedback.lightImpact();
      }
      _results.add(correct);
    });
  }

  void _next() {
    if (_currentQ < widget.items.length - 1) {
      setState(() {
        _currentQ++;
        _selectedAnswer = null;
        _answered = false;
      });
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    setState(() => _finished = true);
    _playCompletionChime();
    _awardXp();
  }

  int get _score {
    final total = widget.items.length;
    if (total == 0) return 0;
    final basePct = _correctCount / total * 70;
    final avgTime = _timePerQuestion.isEmpty
        ? 30.0
        : _timePerQuestion.reduce((a, b) => a + b) / _timePerQuestion.length;
    final timeFactor = ((30 - avgTime) / 30).clamp(0.0, 1.0);
    final timePct = timeFactor * 30;
    return (basePct + timePct).round();
  }

  int get _totalSecondsForAll {
    final total = widget.items.length;
    return total * 30;
  }

  // ── Audio ──────────────────────────────────────────────────────────────

  Future<void> _playTickSound() async {
    try {
      final tick = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(1000, 0.015, amplitude: 0.3),
        1, 10,
      );
      final wav = WavGenerator.generateWav(samples: tick);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tick_${DateTime.now().microsecondsSinceEpoch}.wav');
      await file.writeAsBytes(wav);
      await _audioPlayer.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  Future<void> _playCorrectSound() async {
    try {
      final note1 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(880, 0.2, amplitude: 0.7), 5, 50,
      );
      final gap = WavGenerator.silence(0.05);
      final note2 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(1108, 0.3, amplitude: 0.7), 5, 80,
      );
      final wav = WavGenerator.generateWav(samples: WavGenerator.concat([note1, gap, note2]));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/correct_${DateTime.now().microsecondsSinceEpoch}.wav');
      await file.writeAsBytes(wav);
      await _audioPlayer.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  Future<void> _playWrongSound() async {
    try {
      final note1 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(440, 0.12, amplitude: 0.3), 8, 40,
      );
      final gap = WavGenerator.silence(0.03);
      final note2 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(350, 0.15, amplitude: 0.3), 8, 50,
      );
      final wav = WavGenerator.generateWav(samples: WavGenerator.concat([note1, gap, note2]));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wrong_${DateTime.now().microsecondsSinceEpoch}.wav');
      await file.writeAsBytes(wav);
      await _audioPlayer.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  Future<void> _playTimeoutSound() async {
    try {
      final samples = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(220, 0.5, amplitude: 0.5), 10, 100,
      );
      final wav = WavGenerator.generateWav(samples: samples);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/timeout_${DateTime.now().microsecondsSinceEpoch}.wav');
      await file.writeAsBytes(wav);
      await _audioPlayer.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  Future<void> _playCompletionChime() async {
    try {
      final note1 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(523, 0.2, amplitude: 0.7), 5, 50,
      );
      final gap = WavGenerator.silence(0.05);
      final note2 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(659, 0.3, amplitude: 0.7), 5, 80,
      );
      final gap2 = WavGenerator.silence(0.05);
      final note3 = WavGenerator.applyEnvelope(
        WavGenerator.sineWave(784, 0.4, amplitude: 0.7), 5, 100,
      );
      final wav = WavGenerator.generateWav(
        samples: WavGenerator.concat([note1, gap, note2, gap2, note3]),
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/complete_${DateTime.now().microsecondsSinceEpoch}.wav');
      await file.writeAsBytes(wav);
      await _audioPlayer.play(DeviceFileSource(file.path));
      file.delete();
    } catch (_) {}
  }

  // ── XP ─────────────────────────────────────────────────────────────────

  static const _xpThresholds = [
    0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500
  ];
  static int _calcLevel(int xp) =>
      _xpThresholds.where((t) => xp >= t).length;

  Future<void> _awardXp() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final total = widget.items.length;
    final score = _score;
    final passed = score >= 70;
    final xpEarned = passed ? (score >= 95 ? 75 : score >= 85 ? 50 : 25) : 0;
    final db = FirebaseFirestore.instance;

    try {
      db.collection('quizSessions').add({
        'userId': uid,
        'topicId': 'random_${widget.difficulty}',
        'type': 'theoretical',
        'score': score,
        'timeUsedSeconds': _totalTimeUsed,
        'passed': passed,
        'xpEarned': xpEarned,
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (!passed) return;

      final statsRef = db.collection('userStats').doc(uid);
      int newLevel = 0;
      await db.runTransaction((tx) async {
        final snap = await tx.get(statsRef);
        final data = snap.data() ?? {};
        final currentXp = (data['xp'] as int?) ?? 0;
        final newXp = currentXp + xpEarned;
        newLevel = _calcLevel(newXp);
        tx.set(
            statsRef,
            {
              'xp': newXp,
              'level': newLevel,
              'quizzesCompleted': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });

      if (mounted) {
        setState(() {
          _xpEarned = xpEarned;
          _levelAfter = newLevel;
        });
      }
    } catch (e) {
      debugPrint('[random_quiz] Error guardando XP: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    if (_finished) {
      return _RandomResultScreen(
        items: widget.items,
        difficulty: widget.difficulty,
        correctCount: _correctCount,
        results: _results,
        isDark: isDark,
        textP: textP,
        textS: textS,
        xpEarned: _xpEarned,
        levelAfter: _levelAfter,
        score: _score,
        totalTimeUsed: _totalTimeUsed,
      );
    }

    final item = widget.items[_currentQ];
    final q = item.question;
    final total = widget.items.length;
    final progress = (_currentQ + (_answered ? 1 : 0)) / total;
    final accent = _accentColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: textS),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Aleatorio · ${widget.difficulty}',
                            style: TextStyle(
                                color: textP,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                        Text('Pregunta ${_currentQ + 1} de $total',
                            style: TextStyle(color: textS, fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _timeLeft <= 10
                          ? AppColors.red.withValues(alpha: 0.1)
                          : accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _timeLeft <= 10
                              ? Icons.timer_off_outlined
                              : Icons.timer_outlined,
                          size: 12,
                          color: _timeLeft <= 10 ? AppColors.red : accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_timeLeft}s',
                          style: TextStyle(
                            color: _timeLeft <= 10 ? AppColors.red : accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_correctCount/${_results.length}',
                      style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                  minHeight: 4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.1 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                        (item.case_ as dynamic).icon as IconData,
                        size: 16,
                        color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        (item.case_ as dynamic).caseText as String,
                        style: TextStyle(
                          color: isDark
                              ? textS
                              : accent.withValues(alpha: 0.9),
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.question as String,
                      style: TextStyle(
                        color: textP,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(q.options.length, (i) {
                      final isSelected = _selectedAnswer == i;
                      final isCorrect = i == q.correctIndex;
                      Color? bg;
                      Color border;
                      Color textColor = textP;
                      IconData? trailingIcon;

                      if (_answered) {
                        if (isCorrect) {
                          bg = const Color(0xFF059669).withValues(alpha: 0.1);
                          border = const Color(0xFF059669).withValues(alpha: 0.5);
                          textColor = const Color(0xFF059669);
                          trailingIcon = Icons.check_circle_outline_rounded;
                        } else if (isSelected) {
                          bg = AppColors.red.withValues(alpha: 0.08);
                          border = AppColors.red.withValues(alpha: 0.4);
                          textColor = AppColors.red;
                          trailingIcon = Icons.cancel_outlined;
                        } else {
                          bg = null;
                          border = theme.colorScheme.outline.withValues(alpha: 0.15);
                          textColor = textS.withValues(alpha: 0.5);
                        }
                      } else {
                        bg = null;
                        border = theme.colorScheme.outline.withValues(alpha: 0.3);
                      }

                      final letter = ['A', 'B', 'C', 'D'][i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => _selectAnswer(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: bg ?? theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: border,
                                  width: isSelected && _answered ? 1.5 : 0.8),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: _answered
                                        ? textColor.withValues(alpha: 0.12)
                                        : theme.colorScheme.outline
                                            .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        color: _answered
                                            ? textColor
                                            : textS.withValues(alpha: 0.6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    q.options[i] as String,
                                    style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.35),
                                  ),
                                ),
                                if (trailingIcon != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(trailingIcon,
                                      size: 18, color: textColor),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (_answered) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: theme.colorScheme.outline
                                  .withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.lightbulb_outline_rounded,
                                    size: 14, color: AppColors.amber),
                                SizedBox(width: 7),
                                Text(
                                  'Explicación',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              q.explanation as String,
                              style: TextStyle(
                                  color: textS, fontSize: 12, height: 1.55),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (_answered)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _currentQ < total - 1
                          ? 'Siguiente pregunta'
                          : 'Ver resultados',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Pantalla de resultados ───────────────────────────────────────────────────

class _RandomResultScreen extends StatelessWidget {
  final List<_QuizItem> items;
  final String difficulty;
  final int correctCount;
  final List<bool> results;
  final bool isDark;
  final Color textP;
  final Color textS;
  final int xpEarned;
  final int levelAfter;
  final int score;
  final int totalTimeUsed;

  const _RandomResultScreen({
    required this.items,
    required this.difficulty,
    required this.correctCount,
    required this.results,
    required this.isDark,
    required this.textP,
    required this.textS,
    this.xpEarned = 0,
    this.levelAfter = 0,
    this.score = 0,
    this.totalTimeUsed = 0,
  });

  @override
  Widget build(BuildContext context) {
    final total = items.length;
    final maximumTime = total * 30;
    final timePct = maximumTime > 0
        ? ((maximumTime - totalTimeUsed) / maximumTime * 100).round().clamp(0, 100)
        : 0;
    final passed = score >= 70;
    final scoreColor = score >= 90
        ? const Color(0xFF059669)
        : score >= 70
            ? AppColors.amber
            : AppColors.red;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.brand,
                  AppColors.brand.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Evaluación Aleatoria',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.shuffle_rounded,
                        color: Colors.white70, size: 20),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scoreColor.withValues(alpha: 0.08),
                      border: Border.all(
                          color: scoreColor.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$score%',
                          style: TextStyle(
                            color: scoreColor,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '$correctCount/$total · ${totalTimeUsed}s',
                          style: TextStyle(
                              color: scoreColor.withValues(alpha: 0.7),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    passed
                        ? '¡Evaluación superada!'
                        : 'Necesitas repasar',
                    style: TextStyle(
                        color: textP,
                        fontSize: 20,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dificultad: $difficulty · Tiempo: ${totalTimeUsed}s / ${maximumTime}s',
                    style: TextStyle(color: textS, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (xpEarned > 0) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 18, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '+$xpEarned XP ganados',
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (levelAfter > 0)
                                Text(
                                  'Nivel actual: $levelAfter',
                                  style: TextStyle(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.75),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else if (passed == false) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.red.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 16,
                              color: AppColors.red.withValues(alpha: 0.8)),
                          const SizedBox(width: 8),
                          Text(
                            'Necesitas ≥70% para ganar XP',
                            style: TextStyle(
                              color: AppColors.red.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      passed
                          ? score >= 90
                              ? 'Excelente dominio'
                              : 'Competencia suficiente'
                          : 'Revisa los protocolos AHA',
                      style: TextStyle(
                          color: scoreColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ...List.generate(results.length, (i) {
                    final correct = results[i];
                    final q = items[i].question;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? (correct
                                ? const Color(0xFF059669).withValues(alpha: 0.08)
                                : AppColors.red.withValues(alpha: 0.08))
                            : (correct
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFEF2F2)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: correct
                              ? const Color(0xFF059669).withValues(alpha: 0.3)
                              : AppColors.red.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            correct
                                ? Icons.check_circle_outline_rounded
                                : Icons.cancel_outlined,
                            color: correct
                                ? const Color(0xFF059669)
                                : AppColors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'P${i + 1}: ${q.question as String}',
                              style: TextStyle(
                                color: correct
                                    ? const Color(0xFF059669)
                                    : AppColors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.list_alt_rounded, size: 16),
                          label: const Text('Volver'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => _RandomQuizDetailScreen(
                                  difficulty: difficulty,
                                  items: items,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Repetir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
