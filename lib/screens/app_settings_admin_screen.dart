import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';

class AppSettingsAdminScreen extends StatefulWidget {
  const AppSettingsAdminScreen({super.key});

  @override
  State<AppSettingsAdminScreen> createState() => _AppSettingsAdminScreenState();
}

class _AppSettingsAdminScreenState extends State<AppSettingsAdminScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  bool _saving = false;

  final List<_LangEntry> _languages = [];
  final List<_CurrencyEntry> _currencies = [];
  String _defaultLanguage = 'es';
  String _defaultCurrency = 'USD';

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _db.collection('app_config').doc('localization');

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final l in _languages) {
      l.dispose();
    }
    for (final c in _currencies) {
      c.dispose();
    }
    super.dispose();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userDocStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _db.collection('users').doc(user.uid).snapshots();
  }

  bool _isAdmin(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['isAdmin'] == true) return true;
    if ((data['role'] as String?)?.toLowerCase() == 'admin') return true;
    return false;
  }

  Future<void> _loadConfig() async {
    try {
      final doc = await _configRef.get();
      if (doc.exists) {
        _applyFromDoc(doc.data()!);
      } else {
        _seedDefaults();
      }
    } catch (_) {
      _seedDefaults();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _seedDefaults() {
    _languages
      ..clear()
      ..add(_LangEntry(code: 'es', label: 'Espanol'))
      ..add(_LangEntry(code: 'en', label: 'English'));
    _currencies
      ..clear()
      ..add(_CurrencyEntry(code: 'USD', symbol: '\$', rate: '1.0', digits: '2'))
      ..add(
          _CurrencyEntry(code: 'NIO', symbol: 'C\$', rate: '36.5', digits: '2'));
    _defaultLanguage = 'es';
    _defaultCurrency = 'USD';
  }

  void _applyFromDoc(Map<String, dynamic> data) {
    final langs = (data['languages'] as List?)?.cast<String>() ?? [];
    final labels = (data['languageLabels'] as Map?)?.cast<String, String>() ?? {};
    final currencies = (data['currencies'] as List?)?.cast<String>() ?? [];
    final cfgs = (data['currencyConfigs'] as Map?) ?? {};

    _languages
      ..clear()
      ..addAll(langs.map((code) {
        final label = labels[code] ?? code.toUpperCase();
        return _LangEntry(code: code, label: label);
      }));

    _currencies
      ..clear()
      ..addAll(currencies.map((code) {
        final raw = cfgs[code] as Map?;
        final symbol = (raw?['symbol'] as String?) ?? code;
        final rate = (raw?['rateFromUsd'] as num?)?.toDouble() ?? 1.0;
        final digits = (raw?['fractionDigits'] as num?)?.toInt() ?? 2;
        return _CurrencyEntry(
          code: code,
          symbol: symbol,
          rate: rate.toStringAsFixed(3),
          digits: digits.toString(),
        );
      }));

    _defaultLanguage = (data['defaultLanguage'] as String?) ?? 'es';
    _defaultCurrency = (data['defaultCurrency'] as String?) ?? 'USD';

    if (_languages.isEmpty) {
      _languages.add(_LangEntry(code: 'es', label: 'Espanol'));
    }
    if (_currencies.isEmpty) {
      _currencies
          .add(_CurrencyEntry(code: 'USD', symbol: '\$', rate: '1.0', digits: '2'));
    }
  }

  Future<void> _saveConfig() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final languages = <String>[];
      final labels = <String, String>{};
      for (final entry in _languages) {
        final code = entry.code.text.trim();
        final label = entry.label.text.trim();
        if (code.isEmpty) continue;
        languages.add(code);
        labels[code] = label.isEmpty ? code.toUpperCase() : label;
      }

      final currencyCodes = <String>[];
      final currencyCfgs = <String, Map<String, dynamic>>{};
      for (final entry in _currencies) {
        final code = entry.code.text.trim();
        final symbol = entry.symbol.text.trim();
        final rate = double.tryParse(entry.rate.text.trim());
        final digits = int.tryParse(entry.digits.text.trim()) ?? 2;
        if (code.isEmpty || rate == null) continue;
        currencyCodes.add(code);
        currencyCfgs[code] = {
          'symbol': symbol.isEmpty ? code : symbol,
          'rateFromUsd': rate,
          'fractionDigits': digits,
        };
      }

      await _configRef.set({
        'languages': languages,
        'languageLabels': labels,
        'defaultLanguage': _defaultLanguage,
        'currencies': currencyCodes,
        'currencyConfigs': currencyCfgs,
        'defaultCurrency': _defaultCurrency,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              en: 'App localization saved.',
              es: 'Localizacion guardada.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              en: 'Save failed: $e',
              es: 'Error al guardar: $e',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userDocStream(),
      builder: (context, snapshot) {
        return ValueListenableBuilder<String>(
          valueListenable: AppState.of(context).languageCode,
          builder: (_, code, __) {
            final isEs = code == 'es';
            final title = isEs ? 'Configuraciones de la app' : 'App Settings';
            final denied = isEs
                ? 'Acceso denegado. Configura role="admin" o isAdmin=true en tu usuario de Firestore para habilitar este panel.'
                : 'Access denied. Set role="admin" or isAdmin=true on your user document in Firestore to unlock this panel.';
            final saveLabel = isEs ? 'Guardar' : 'Save';
            final savingLabel = isEs ? 'Guardando...' : 'Saving...';

            final admin = _isAdmin(snapshot.data?.data());
            if (!admin) {
              return Scaffold(
                appBar: NvAppBar(title: title, showBack: true),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      denied,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            return Scaffold(
              appBar: NvAppBar(
                title: title,
                showBack: true,
                extraActions: [
                  IconButton(
                    tooltip: saveLabel,
                    onPressed: _saving ? null : _saveConfig,
                    icon: const Icon(Icons.save),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle(isEs ? 'Idiomas' : 'Languages'),
                  _buildLanguageList(isEs),
                  const SizedBox(height: 16),
                  _sectionTitle(isEs ? 'Idioma por defecto' : 'Default language'),
                  DropdownButton<String>(
                    value: _defaultLanguage,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _defaultLanguage = value);
                    },
                    items: _languages
                        .map((e) => e.code.text.trim())
                        .where((c) => c.isNotEmpty)
                        .map((code) => DropdownMenuItem(
                              value: code,
                              child: Text(code),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(isEs ? 'Monedas' : 'Currencies'),
                  _buildCurrencyList(isEs),
                  const SizedBox(height: 16),
                  _sectionTitle(isEs ? 'Moneda por defecto' : 'Default currency'),
                  DropdownButton<String>(
                    value: _defaultCurrency,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _defaultCurrency = value);
                    },
                    items: _currencies
                        .map((e) => e.code.text.trim())
                        .where((c) => c.isNotEmpty)
                        .map((code) => DropdownMenuItem(
                              value: code,
                              child: Text(code),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _saveConfig,
                    child: Text(_saving ? savingLabel : saveLabel),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLanguageList(bool isEs) {
    return Column(
      children: [
        ..._languages.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: item.code,
                      decoration: InputDecoration(
                        labelText:
                            isEs ? 'Codigo (es, en)' : 'Code (es, en)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: item.label,
                      decoration: InputDecoration(
                        labelText: isEs ? 'Etiqueta' : 'Label',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isEs ? 'Eliminar' : 'Remove',
                    onPressed: () => setState(() => _languages.removeAt(index)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () => setState(() => _languages.add(_LangEntry())),
          icon: const Icon(Icons.add),
          label: Text(isEs ? 'Agregar idioma' : 'Add language'),
        ),
      ],
    );
  }

  Widget _buildCurrencyList(bool isEs) {
    return Column(
      children: [
        ..._currencies.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: item.code,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Codigo' : 'Code',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: item.symbol,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Simbolo' : 'Symbol',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: isEs ? 'Eliminar' : 'Remove',
                        onPressed: () => setState(() => _currencies.removeAt(index)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: item.rate,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                isEs ? 'Tasa desde USD' : 'Rate from USD',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: item.digits,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Decimales' : 'Decimals',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () => setState(() => _currencies.add(_CurrencyEntry())),
          icon: const Icon(Icons.add),
          label: Text(isEs ? 'Agregar moneda' : 'Add currency'),
        ),
      ],
    );
  }
}

class _LangEntry {
  _LangEntry({String? code, String? label})
      : code = TextEditingController(text: code ?? ''),
        label = TextEditingController(text: label ?? '');

  final TextEditingController code;
  final TextEditingController label;

  void dispose() {
    code.dispose();
    label.dispose();
  }
}

class _CurrencyEntry {
  _CurrencyEntry({String? code, String? symbol, String? rate, String? digits})
      : code = TextEditingController(text: code ?? ''),
        symbol = TextEditingController(text: symbol ?? ''),
        rate = TextEditingController(text: rate ?? ''),
        digits = TextEditingController(text: digits ?? '2');

  final TextEditingController code;
  final TextEditingController symbol;
  final TextEditingController rate;
  final TextEditingController digits;

  void dispose() {
    code.dispose();
    symbol.dispose();
    rate.dispose();
    digits.dispose();
  }
}


