import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../models/course_module.dart';
import '../../../services/course_service.dart';

class ModuleQuizScreen extends StatefulWidget {
  final CourseModule module;
  final String courseId;
  final String studentId;

  const ModuleQuizScreen({
    super.key,
    required this.module,
    required this.courseId,
    required this.studentId,
  });

  @override
  State<ModuleQuizScreen> createState() => _ModuleQuizScreenState();
}

class _ModuleQuizScreenState extends State<ModuleQuizScreen> {
  final Map<int, int> _answers = {};
  bool _submitted = false;
  double _score = 0;

  void _submit() {
    int correct = 0;
    for (int i = 0; i < widget.module.questions.length; i++) {
      if (_answers[i] == widget.module.questions[i].correctIndex) {
        correct++;
      }
    }
    setState(() {
      _score = (correct / widget.module.questions.length) * 100;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;

    if (_submitted) {
      final passed = _score >= widget.module.passingScore;
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  passed ? Icons.check_circle_outline : Icons.error_outline,
                  size: 80,
                  color: passed ? AppColors.green : AppColors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  passed ? '¡Felicitaciones!' : 'Sigue intentando',
                  style: TextStyle(color: textP, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu puntaje: ${_score.toStringAsFixed(0)}%',
                  style: TextStyle(color: textS, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mínimo requerido: ${widget.module.passingScore}%',
                  style: TextStyle(color: textS.withValues(alpha: 0.6), fontSize: 14),
                ),
                const SizedBox(height: 32),
                if (passed)
                  Consumer(builder: (context, ref, _) {
                    return ElevatedButton(
                      onPressed: () async {
                        await ref.read(courseServiceProvider).markModuleComplete(
                              courseId: widget.courseId,
                              moduleId: widget.module.id,
                              studentId: widget.studentId,
                            );
                        if (context.mounted) context.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        minimumSize: const Size(200, 50),
                      ),
                      child: const Text('Continuar'),
                    );
                  })
                else
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _submitted = false;
                      _answers.clear();
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      minimumSize: const Size(200, 50),
                    ),
                    child: const Text('Reintentar'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.module.title, style: const TextStyle(fontSize: 16))),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: widget.module.questions.length,
        itemBuilder: (context, i) {
          final q = widget.module.questions[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pregunta ${i + 1}', style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(q.text, style: TextStyle(color: textP, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  ...q.options.asMap().entries.map((opt) {
                    return RadioListTile<int>(
                      title: Text(opt.value, style: TextStyle(color: textS, fontSize: 14)),
                      value: opt.key,
                      groupValue: _answers[i],
                      onChanged: (val) => setState(() => _answers[i] = val!),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: _answers.length == widget.module.questions.length ? _submit : null,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
            child: const Text('Enviar evaluación'),
          ),
        ),
      ),
    );
  }
}
