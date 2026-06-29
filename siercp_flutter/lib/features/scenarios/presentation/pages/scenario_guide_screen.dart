import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:siercp/core/theme/theme.dart';

class ScenarioGuideScreen extends ConsumerStatefulWidget {
  final String scenarioId;
  final String? courseId;
  const ScenarioGuideScreen({
    super.key,
    required this.scenarioId,
    this.courseId,
  });

  @override
  ConsumerState<ScenarioGuideScreen> createState() =>
      _ScenarioGuideScreenState();
}

class _ScenarioGuideScreenState extends ConsumerState<ScenarioGuideScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _controlsVisible = true;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/guiaRCP.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      }).catchError((e) {
        // Si el video falla, no bloqueamos al estudiante: pasamos a la sesión.
        debugPrint('❌ Error al cargar guiaRCP.mp4: $e');
        _goToSession();
      });
    _controller.addListener(_onTick);
  }

  void _onTick() {
    if (!mounted) return;
    // Avanza automáticamente al terminar el video.
    final v = _controller.value;
    if (v.isInitialized &&
        !_navigated &&
        v.position >= v.duration &&
        v.duration > Duration.zero) {
      _goToSession();
    }
    setState(() {});
  }

  void _goToSession() {
    if (_navigated) return;
    _navigated = true;
    final courseParam =
        widget.courseId != null ? '&courseId=${widget.courseId}' : '';
    if (mounted) {
      context.go(
          '/simulation/practical/scenario-detail/${widget.scenarioId}$courseParam');
    }
  }

  void _seekBy(Duration delta) {
    final target = _controller.value.position + delta;
    final dur = _controller.value.duration;
    _controller.seekTo(
      target < Duration.zero ? Duration.zero : (target > dur ? dur : target),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Video ────────────────────────────────────────────────────
            Center(
              child: _ready
                  ? GestureDetector(
                      onTap: () =>
                          setState(() => _controlsVisible = !_controlsVisible),
                      child: AspectRatio(
                        aspectRatio:
                            value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    )
                  : const _GuideLoader(),
            ),

            // ── Capa de controles ────────────────────────────────────────
            if (_ready && _controlsVisible) ...[
              // Degradado superior + barra de título
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        onPressed: _goToSession,
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Guía de posicionamiento',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Observa cómo posicionarte antes de iniciar la RCP',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Controles centrales: retroceder / play-pause / adelantar
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundControl(
                      icon: Icons.replay_10_rounded,
                      onTap: () => _seekBy(const Duration(seconds: -10)),
                    ),
                    const SizedBox(width: 28),
                    _RoundControl(
                      icon: value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 40,
                      onTap: () {
                        setState(() {
                          value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                      },
                    ),
                    const SizedBox(width: 28),
                    _RoundControl(
                      icon: Icons.forward_10_rounded,
                      onTap: () => _seekBy(const Duration(seconds: 10)),
                    ),
                  ],
                ),
              ),

              // Barra inferior: progreso + tiempos + botón continuar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        colors: const VideoProgressColors(
                          playedColor: AppColors.brand,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _fmt(value.position),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            _fmt(value.duration),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _goToSession,
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text(
                            'Continuar a la simulación',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _goToSession,
                        child: const Text(
                          'Omitir guía',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  const _RoundControl({
    required this.icon,
    required this.onTap,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

class _GuideLoader extends StatelessWidget {
  const _GuideLoader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Cargando guía…',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}
