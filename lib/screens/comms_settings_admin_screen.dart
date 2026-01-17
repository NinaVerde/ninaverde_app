import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';

class CommsSettingsAdminScreen extends StatefulWidget {
  const CommsSettingsAdminScreen({super.key});

  @override
  State<CommsSettingsAdminScreen> createState() =>
      _CommsSettingsAdminScreenState();
}

class _CommsSettingsAdminScreenState extends State<CommsSettingsAdminScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _saving = false;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _db.collection('users').doc(user.uid).snapshots();
  }

  bool _isAdmin(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['isAdmin'] == true) return true;
    if ((data['role'] as String?)?.toLowerCase() == 'admin') return true;
    return false;
  }

  DocumentReference<Map<String, dynamic>> get _ref =>
      _db.collection('app_config').doc('comms');

  @override
  Widget build(BuildContext context) {
    final title = tr(context, en: 'Comms Settings', es: 'Comunicaciones');
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(),
      builder: (context, userSnap) {
        final admin = _isAdmin(userSnap.data?.data());
        if (!admin) {
          return Scaffold(
            appBar: NvAppBar(title: title, showBack: true),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr(
                    context,
                    en:
                        'Access denied. Set role="admin" or isAdmin=true on your user document in Firestore.',
                    es:
                        'Acceso denegado. Configura role="admin" o isAdmin=true en tu usuario de Firestore.',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _ref.snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            bool pushEnabled = (data['pushEnabled'] as bool?) ?? false;
            bool emailEnabled = (data['emailEnabled'] as bool?) ?? true;
            bool smsEnabled = (data['smsEnabled'] as bool?) ?? true;
            bool defaultEmail = (data['defaultOptInEmail'] as bool?) ?? true;
            bool defaultSms = (data['defaultOptInSms'] as bool?) ?? true;
            bool defaultPush = (data['defaultOptInPush'] as bool?) ?? false;

            return Scaffold(
              appBar: NvAppBar(title: title, showBack: true),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    title: Text(tr(context, en: 'Enable Email', es: 'Email')),
                    value: emailEnabled,
                    onChanged: (v) => setState(() => emailEnabled = v),
                  ),
                  SwitchListTile(
                    title: Text(tr(context, en: 'Enable SMS', es: 'SMS')),
                    value: smsEnabled,
                    onChanged: (v) => setState(() => smsEnabled = v),
                  ),
                  SwitchListTile(
                    title: Text(tr(context, en: 'Enable Push', es: 'Push')),
                    value: pushEnabled,
                    onChanged: (v) => setState(() => pushEnabled = v),
                  ),
                  const Divider(height: 24),
                  SwitchListTile(
                    title:
                        Text(tr(context, en: 'Default email opt-in', es: 'Opt-in email por defecto')),
                    value: defaultEmail,
                    onChanged: (v) => setState(() => defaultEmail = v),
                  ),
                  SwitchListTile(
                    title:
                        Text(tr(context, en: 'Default SMS opt-in', es: 'Opt-in SMS por defecto')),
                    value: defaultSms,
                    onChanged: (v) => setState(() => defaultSms = v),
                  ),
                  SwitchListTile(
                    title:
                        Text(tr(context, en: 'Default push opt-in', es: 'Opt-in push por defecto')),
                    value: defaultPush,
                    onChanged: (v) => setState(() => defaultPush = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            await _ref.set({
                              'pushEnabled': pushEnabled,
                              'emailEnabled': emailEnabled,
                              'smsEnabled': smsEnabled,
                              'defaultOptInEmail': defaultEmail,
                              'defaultOptInSms': defaultSms,
                              'defaultOptInPush': defaultPush,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                            if (!context.mounted) return;
                            setState(() => _saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  tr(context,
                                      en: 'Comms settings saved.',
                                      es: 'Configuracion guardada.'),
                                ),
                              ),
                            );
                          },
                    child: Text(tr(context, en: 'Save', es: 'Guardar')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
