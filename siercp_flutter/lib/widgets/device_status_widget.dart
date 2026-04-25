import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/guide_provider.dart';
import '../core/theme.dart';

class DeviceConnectionWidget extends ConsumerWidget {
  final bool compact;
  const DeviceConnectionWidget({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(deviceConnectionProvider);

    return statusAsync.when(
      loading: () => _buildChip(
        context,
        label: 'Buscando...',
        color: AppColors.amber,
        icon: Icons.bluetooth_searching_rounded,
        pulsing: true,
      ),
      error: (_, __) => _buildChip(
        context,
        label: 'Error',
        color: AppColors.red,
        icon: Icons.error_outline_rounded,
      ),
      data: (status) => _buildChip(
        context,
        label: status.isConnected ? 'Maniquí conectado' : 'Sin maniquí',
        color: status.isConnected ? AppColors.green : AppColors.red,
        icon: status.isConnected
            ? Icons.sensors_rounded
            : Icons.sensors_off_rounded,
        pulsing: status.isConnected,
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
    bool pulsing = false,
  }) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PulsingDot(color: color, animate: pulsing),
        const SizedBox(width: 6),
        Icon(icon, size: compact ? 12 : 14, color: color),
        if (!compact) ...[
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    if (compact) return content;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: content,
    );
  }
}

// Punto pulsante animado
class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _PulsingDot({required this.color, required this.animate});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.animate && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// Banner expandido para usar en SessionScreen o al inicio de sesión.
class DeviceStatusBanner extends ConsumerWidget {
  const DeviceStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(deviceConnectionProvider);

    return statusAsync.when(
      loading: () => _banner(
        context,
        msg: 'Buscando maniquí...',
        color: AppColors.amber,
        icon: Icons.bluetooth_searching_rounded,
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (status) {
        if (status.isConnected) return const SizedBox.shrink();
        return _banner(
          context,
          msg: '⚠️ Maniquí no detectado. Verificar conexión del ESP32.',
          color: AppColors.red,
          icon: Icons.sensors_off_rounded,
        );
      },
    );
  }

  Widget _banner(
    BuildContext context, {
    required String msg,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
