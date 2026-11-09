import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/constants/clinical_scenarios.dart';
import 'package:siercp/core/services/vr_launcher.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/devices/data/ble_service.dart';

/// Casos que existen en SICAP VR (los mismos del simulador del PC).
const _vrCases = {
  'paroCardiaco', 'accidenteTransito', 'ahogamiento', 'colapsoEjercicio',
  'atragantamiento', 'descargaElectrica', 'sobredosis', 'infarto',
  'pediatricoParo', 'ahogamientoPediatrico', 'rvNeonatal', 'traumaCraneo',
};

final _vrInstalledProvider = FutureProvider.autoDispose<bool>((_) => VrLauncher.isInstalled());

/// Práctica en realidad virtual: el teléfono va en unas gafas con SICAP VR y la
/// app sigue leyendo el maniquí en segundo plano. El PC, si está en la red,
/// muestra lo mismo que ve el estudiante.
class VrPracticeScreen extends ConsumerStatefulWidget {
  const VrPracticeScreen({super.key});

  @override
  ConsumerState<VrPracticeScreen> createState() => _VrPracticeScreenState();
}

class _VrPracticeScreenState extends ConsumerState<VrPracticeScreen> {
  String _scenarioId = 'paroCardiaco';
  int _minutes = 2;

  @override
  Widget build(BuildContext context) {
    final installed = ref.watch(_vrInstalledProvider);
    final connected = ref.watch(bleServiceProvider).isConnected;
    final cases = kClinicalScenarios.where((c) => _vrCases.contains(c.id)).toList();
    final ready = connected && (installed.valueOrNull ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('Práctica en realidad virtual')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _Steps(),
            const SizedBox(height: 16),
            _Check(
              ok: installed.valueOrNull ?? false,
              okText: 'SICAP VR está instalada',
              missingText: 'Instala SICAP VR en este teléfono',
            ),
            _Check(
              ok: connected,
              okText: 'Maniquí conectado',
              missingText: 'Conecta el maniquí por Bluetooth',
              action: connected ? null : () => context.push('/session/device-select'),
              actionLabel: 'Conectar',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _scenarioId,
              decoration: const InputDecoration(labelText: 'Caso clínico'),
              items: [
                for (final c in cases) DropdownMenuItem(value: c.id, child: Text(c.title)),
              ],
              onChanged: (v) => setState(() => _scenarioId = v ?? _scenarioId),
            ),
            const SizedBox(height: 16),
            Text('Duración', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1 min')),
                ButtonSegment(value: 2, label: Text('2 min')),
                ButtonSegment(value: 3, label: Text('3 min')),
              ],
              selected: {_minutes},
              onSelectionChanged: (v) => setState(() => _minutes = v.first),
            ),
            const SizedBox(height: 8),
            const Text('Con el teléfono en las gafas no puedes tocar la pantalla: la práctica termina sola.'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: ready
                  ? () => context.push('/simulation/practical/session?scenario=$_scenarioId&vr=$_minutes')
                  : null,
              icon: const Icon(Icons.vrpano_outlined),
              label: const Text('Comenzar en las gafas'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Coloca las manos en el centro del pecho del maniquí.',
      'Toca "Comenzar en las gafas": se abre SICAP VR y empieza una cuenta de 5 segundos.',
      'Pon el teléfono en el soporte de las gafas y póntelas.',
      'Mira alrededor con la cabeza y comprime. Al terminar, quítate las gafas y vuelve a la app para ver tu resultado.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 12, backgroundColor: AppColors.brand, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.white))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(steps[i])),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.ok, required this.okText, required this.missingText, this.action, this.actionLabel});

  final bool ok;
  final String okText;
  final String missingText;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(ok ? Icons.check_circle : Icons.error_outline, color: ok ? AppColors.green : AppColors.amber),
      title: Text(ok ? okText : missingText),
      trailing: action == null ? null : TextButton(onPressed: action, child: Text(actionLabel ?? '')),
    );
  }
}
