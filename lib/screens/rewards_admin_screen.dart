import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import '../services/rewards_service.dart';

class RewardsAdminScreen extends StatefulWidget {
  const RewardsAdminScreen({super.key});

  @override
  State<RewardsAdminScreen> createState() => _RewardsAdminScreenState();
}

class _RewardsAdminScreenState extends State<RewardsAdminScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final RewardsService _service = RewardsService();

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(),
      builder: (context, snapshot) {
        final admin = _isAdmin(snapshot.data?.data());
        final title = tr(context, en: 'NV Coins Rewards', es: 'Monedas NV');
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

        return StreamBuilder<RewardsSettings>(
          stream: _service.settingsStream(),
          builder: (context, settingsSnap) {
            final settings = settingsSnap.data ??
                const RewardsSettings(
                  enabled: true,
                  usdPerCoin: 10,
                  signupBonus: 0,
                  referralBonus: 0,
                  minOrderUsd: 0,
                  maxCoinsPerOrder: 0,
                );
            return _RewardsSettingsForm(
              settings: settings,
              saving: _saving,
              onSave: (next) async {
                final snackText = tr(
                  context,
                  en: 'Rewards settings saved.',
                  es: 'Ajustes guardados.',
                );
                setState(() => _saving = true);
                await _service.saveSettings(next);
                if (!context.mounted) return;
                setState(() => _saving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(snackText),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RewardsSettingsForm extends StatefulWidget {
  final RewardsSettings settings;
  final bool saving;
  final ValueChanged<RewardsSettings> onSave;

  const _RewardsSettingsForm({
    required this.settings,
    required this.saving,
    required this.onSave,
  });

  @override
  State<_RewardsSettingsForm> createState() => _RewardsSettingsFormState();
}

class _RewardsSettingsFormState extends State<_RewardsSettingsForm> {
  late bool _enabled;
  late final TextEditingController _usdPerCoin;
  late final TextEditingController _minOrderUsd;
  late final TextEditingController _maxCoins;
  late final TextEditingController _signupBonus;
  late final TextEditingController _referralBonus;

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.enabled;
    _usdPerCoin =
        TextEditingController(text: widget.settings.usdPerCoin.toString());
    _minOrderUsd =
        TextEditingController(text: widget.settings.minOrderUsd.toString());
    _maxCoins =
        TextEditingController(text: widget.settings.maxCoinsPerOrder.toString());
    _signupBonus =
        TextEditingController(text: widget.settings.signupBonus.toString());
    _referralBonus =
        TextEditingController(text: widget.settings.referralBonus.toString());
  }

  @override
  void dispose() {
    _usdPerCoin.dispose();
    _minOrderUsd.dispose();
    _maxCoins.dispose();
    _signupBonus.dispose();
    _referralBonus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labelEnabled =
        tr(context, en: 'Rewards enabled', es: 'Recompensas activas');
    final labelUsd =
        tr(context, en: 'USD per NV Coin', es: 'USD por Moneda NV');
    final labelMin =
        tr(context, en: 'Minimum order (USD)', es: 'Pedido minimo (USD)');
    final labelMax =
        tr(context, en: 'Max coins per order (0 = unlimited)', es: 'Max coins por pedido (0 = ilimitado)');
    final labelSignup =
        tr(context, en: 'Signup bonus (coins)', es: 'Bono al registrarse');
    final labelReferral =
        tr(context, en: 'Referral bonus (coins)', es: 'Bono por referidos');
    final save = tr(context, en: 'Save', es: 'Guardar');
    final saving = tr(context, en: 'Saving...', es: 'Guardando...');

    return Scaffold(
      appBar: NvAppBar(title: tr(context, en: 'NV Coins Rewards', es: 'Monedas NV'), showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: Text(labelEnabled),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _usdPerCoin,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: labelUsd,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minOrderUsd,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: labelMin,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxCoins,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: labelMax,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _signupBonus,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: labelSignup,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _referralBonus,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: labelReferral,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.saving
                ? null
                : () {
                    final settings = RewardsSettings(
                      enabled: _enabled,
                      usdPerCoin: double.tryParse(_usdPerCoin.text.trim()) ?? 10,
                      minOrderUsd:
                          double.tryParse(_minOrderUsd.text.trim()) ?? 0,
                      maxCoinsPerOrder:
                          int.tryParse(_maxCoins.text.trim()) ?? 0,
                      signupBonus:
                          int.tryParse(_signupBonus.text.trim()) ?? 0,
                      referralBonus:
                          int.tryParse(_referralBonus.text.trim()) ?? 0,
                    );
                    widget.onSave(settings);
                  },
            child: Text(widget.saving ? saving : save),
          ),
        ],
      ),
    );
  }
}
