import 'package:flutter/material.dart';
import 'package:siercp/features/session/data/sim_bridge_service.dart';

/// Activa el envío de la sesión al simulador SICAP Sim en un PC de la misma red.
class SimBridgeSheet extends StatefulWidget {
  const SimBridgeSheet({super.key, required this.bridge});

  final SimBridgeService bridge;

  @override
  State<SimBridgeSheet> createState() => _SimBridgeSheetState();
}

class _SimBridgeSheetState extends State<SimBridgeSheet> {
  late bool _enabled = widget.bridge.enabled;
  late final TextEditingController _target =
      TextEditingController(text: widget.bridge.target);
  String? _error;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!SimBridgeService.isValidTarget(_target.text)) {
      setState(() => _error = 'Escribe una IP válida, como 192.168.1.20.');
      return;
    }
    await widget.bridge.configure(enabled: _enabled, target: _target.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Simulador en PC', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Muestra esta sesión en SICAP Sim. Abre el simulador en el PC y '
            'conecta este equipo al mismo Wi-Fi: se encuentran solos. La sesión '
            'se guarda aquí igual que siempre.',
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enviar señal al simulador'),
            value: _enabled,
            onChanged: (value) {
              setState(() => _enabled = value);
              widget.bridge.configure(
                enabled: value,
                target: widget.bridge.target,
              );
            },
          ),
          if (_enabled)
            ListenableBuilder(
              listenable: widget.bridge,
              builder: (context, _) {
                final address = widget.bridge.simulatorAddress;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    address == null
                        ? 'Buscando el simulador en esta red…'
                        : 'Simulador encontrado en $address',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                );
              },
            ),
          TextField(
            controller: _target,
            enabled: _enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'IP del PC (opcional)',
              helperText:
                  'Solo si no lo encuentra. La IP aparece en el menú del simulador.',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('Guardar')),
          ),
        ],
      ),
    );
  }
}
