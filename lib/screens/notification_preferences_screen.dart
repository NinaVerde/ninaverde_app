import 'package:flutter/material.dart';

import '../main.dart';
import '../state/app_state.dart';
import '../services/comms_prefs_service.dart';
import '../services/push_token_service.dart';
import '../widgets/nv_widgets.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final title = tr(context, en: 'Messaging Preferences', es: 'Preferencias');
    final service = CommsPrefsService();
    final pushTokens = PushTokenService();

    return Scaffold(
      appBar: NvAppBar(title: title, showBack: true),
      body: StreamBuilder<CommsPrefs>(
        stream: service.prefsStream(),
        builder: (context, snapshot) {
          final prefs = snapshot.data ??
              const CommsPrefs(optInEmail: true, optInSms: true, optInPush: false);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: Text(tr(context, en: 'Email offers', es: 'Email ofertas')),
                value: prefs.optInEmail,
                onChanged: (v) => service.update(optInEmail: v),
              ),
              SwitchListTile(
                title: Text(tr(context, en: 'SMS offers', es: 'SMS ofertas')),
                value: prefs.optInSms,
                onChanged: (v) => service.update(optInSms: v),
              ),
              SwitchListTile(
                title: Text(tr(context, en: 'Push notifications', es: 'Push')),
                subtitle: Text(
                  tr(
                    context,
                    en: 'Disabled by default. Enable to receive alerts.',
                    es: 'Desactivado por defecto. Activalo para alertas.',
                  ),
                ),
                value: prefs.optInPush,
                onChanged: (v) async {
                  await service.update(optInPush: v);
                  if (v) {
                    await pushTokens.registerIfOptedIn(optInPush: true);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
