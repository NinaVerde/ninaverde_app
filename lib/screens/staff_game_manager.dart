import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../services/live_game_service.dart';
import '../models/live_game_models.dart';

class StaffSessionManager extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isEs = AppState.of(context).languageCode.value == 'es';
    
    return StreamBuilder<List<LiveGameSession>>(
      stream: LiveGameService.getActiveSessions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        
        final sessions = snapshot.data!;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            border: Border.all(color: Colors.red.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    isEs ? 'Panel de Staff (Sesiones Activas)' : 'Staff Dashboard (Active Sessions)',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  // We need config to know price... but session doesn't store price snapshot.
                  // For MVP, we assume current price. Ideally session should store price snapshot.
                  // Let's fetch config async or just show "Calculator" in dialog.
                  return _StaffSessionTile(session: session);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StaffSessionTile extends StatelessWidget {
  final LiveGameSession session;
  const _StaffSessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final isEs = AppState.of(context).languageCode.value == 'es';
    final duration = DateTime.now().difference(session.startTime);
    final waitingEnd = session.endTime != null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(session.userName),
      subtitle: Text(
        '${session.gameId} • ${duration.inMinutes} mins\n' +
        (session.collateralDescription.isNotEmpty ? 'Collateral: ${session.collateralDescription}' : 'No Collateral'),
        style: const TextStyle(fontSize: 12),
      ),
      leading: CircleAvatar(
        backgroundColor: waitingEnd ? Colors.orange : Colors.green,
        child: Icon(waitingEnd ? Icons.timer_off : Icons.timer, color: Colors.white, size: 20),
      ),
      trailing: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red, 
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: () => _showCloseDialog(context, session),
        child: Text(isEs ? 'Cerrar' : 'Close'),
      ),
    );
  }

  void _showCloseDialog(BuildContext context, LiveGameSession session) {
    final isEs = AppState.of(context).languageCode.value == 'es';
    // We need price to calc charge. Fetch config.
    // Hack: we'll just ask staff to input final charge, pre-filling with calculation if possible?
    // Better: Fetch config properly.
    
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<LiveGameConfig>>(
        future: LiveGameService.getConfigs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final config = snapshot.data!.firstWhere((c) => c.id == session.gameId, orElse: () => snapshot.data!.first);
          final pricePerQuarter = config.pricePerQuarterHour;
          
          final now = DateTime.now();
          final start = session.startTime;
          final duration = now.difference(start);
          final quarters = (duration.inMinutes / 15).ceil();
          final recommendedCharge = quarters * pricePerQuarter;
          
          final chargeCtrl = TextEditingController(text: recommendedCharge.toStringAsFixed(2));
          bool equipmentReturned = false;

          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(isEs ? 'Cerrar Sesión' : 'Close Session'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User: ${session.userName}'),
                  Text('Game: ${config.name}'),
                  Text('Duration: ${duration.inHours}h ${duration.inMinutes % 60}m'),
                  const Divider(),
                  if (session.collateralDescription.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.amber.withValues(alpha: 0.2),
                      child: Text('RETURN COLLATERAL:\n${session.collateralDescription}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                    ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: Text(isEs ? 'Equipo devuelto y verificado' : 'Equipment returned & verified'),
                    value: equipmentReturned,
                    onChanged: (v) => setState(() => equipmentReturned = v ?? false),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: chargeCtrl,
                    decoration: InputDecoration(
                       labelText: isEs ? 'Cargo Final (\$)' : 'Final Charge (\$)',
                       helperText: isEs ? 'Sugerido: \$$recommendedCharge' : 'Suggested: \$$recommendedCharge',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(isEs ? 'Cancelar' : 'Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: equipmentReturned ? () async {
                    final finalCharge = double.tryParse(chargeCtrl.text) ?? recommendedCharge;
                    await LiveGameService.approveEndSession(session.id, finalCharge);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session closed.')));
                    }
                  } : null,
                  child: Text(isEs ? 'Confirmar & Cerrar' : 'Confirm & Close'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
