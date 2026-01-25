import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';
import '../models/app_config_model.dart';
import '../services/exchange_rate_service.dart';

class CurrencySettingsScreen extends StatefulWidget {
  const CurrencySettingsScreen({super.key});

  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  bool _saving = false;

  final List<_CurrencyEntry> _currencies = [];
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
    _currencies
      ..clear()
      ..add(_CurrencyEntry(code: 'USD', symbol: '\$', rate: '1.0', digits: '2'))
      ..add(_CurrencyEntry(code: 'NIO', symbol: 'C\$', rate: '36.6', digits: '2'));
    _defaultCurrency = 'USD';
  }

  void _applyFromDoc(Map<String, dynamic> data) {
    final currencies = (data['currencies'] as List?)?.cast<String>() ?? [];
    final cfgs = (data['currencyConfigs'] as Map?) ?? {};

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
          rate: rate.toStringAsFixed(4),
          digits: digits.toString(),
        );
      }));

    _defaultCurrency = (data['defaultCurrency'] as String?) ?? 'USD';

    if (_currencies.isEmpty) {
      _currencies.add(_CurrencyEntry(code: 'USD', symbol: '\$', rate: '1.0', digits: '2'));
    }
  }

  Future<void> _saveConfig() async {
    if (_saving) return;

    // Validate
    if (_currencies.isEmpty) {
      _showError(tr(context, en: 'At least one currency is required', es: 'Se requiere al menos una moneda'));
      return;
    }

    final codes = _currencies.map((e) => e.code.text.trim()).where((c) => c.isNotEmpty).toList();
    if (!codes.contains(_defaultCurrency)) {
      _showError(tr(context, en: 'Default currency must be in the list', es: 'La moneda predeterminada debe estar en la lista'));
      return;
    }

    setState(() => _saving = true);
    try {
      final currencyCodes = <String>[];
      final currencyCfgs = <String, Map<String, dynamic>>{};

      for (final entry in _currencies) {
        final code = entry.code.text.trim();
        final symbol = entry.symbol.text.trim();
        final rate = double.tryParse(entry.rate.text.trim());
        final digits = int.tryParse(entry.digits.text.trim()) ?? 2;
        
        if (code.isEmpty || rate == null || rate <= 0) {
          _showError('${tr(context, en: 'Invalid currency: ', es: 'Moneda inválida: ')}$code');
          setState(() => _saving = false);
          return;
        }
        
        currencyCodes.add(code);
        currencyCfgs[code] = {
          'symbol': symbol.isEmpty ? code : symbol,
          'rateFromUsd': rate,
          'fractionDigits': digits,
        };
      }

      await _configRef.set({
        'currencies': currencyCodes,
        'currencyConfigs': currencyCfgs,
        'defaultCurrency': _defaultCurrency,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, en: 'Currencies saved successfully!', es: '¡Monedas guardadas exitosamente!')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('${tr(context, en: 'Save failed: ', es: 'Error al guardar: ')}$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _addCurrency() {
    setState(() => _currencies.add(_CurrencyEntry()));
  }

  void _removeCurrency(int index) {
    if (_currencies.length <= 1) {
      _showError(tr(context, en: 'Cannot remove the last currency', es: 'No se puede eliminar la última moneda'));
      return;
    }

    final code = _currencies[index].code.text.trim();
    if (code == _defaultCurrency) {
      _showError(tr(context, en: 'Cannot remove the default currency', es: 'No se puede eliminar la moneda predeterminada'));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'Remove Currency?', es: '¿Eliminar moneda?')),
        content: Text(tr(context, en: 'Are you sure you want to remove this currency?', es: '¿Estás seguro de que quieres eliminar esta moneda?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(context, en: 'Cancel', es: 'Cancelar')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currencies.removeAt(index));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr(context, en: 'Remove', es: 'Eliminar')),
          ),
        ],
      ),
    );
  }

  void _showPresetCurrencies() async {
    final isEs = AppState.of(context).languageCode.value == 'es';

    // Show loading dialog while fetching rates
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(isEs ? 'Obteniendo tasas de cambio...' : 'Fetching exchange rates...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final presets = await ExchangeRateService.getPresetsWithLiveRates();
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEs ? 'Monedas Populares' : 'Popular Currencies',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            isEs ? 'Tasas bancarias en tiempo real' : 'Live bank buying rates',
                            style: const TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: presets.length,
                  itemBuilder: (context, index) {
                    final p = presets[index];
                    final code = p['c']!;
                    final symbol = p['s']!;
                    final rate = p['r']!;
                    final digits = p['d']!;
                    final name = p['n']!;
                    final exists = _currencies.any((x) => x.code.text == code);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF4CAF50).withOpacity(0.2),
                          child: Text(symbol, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        title: Text('$code - $name', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${isEs ? 'Tasa bancaria' : 'Bank rate'}: $rate USD'),
                        trailing: exists
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.download, color: Colors.blue),
                        onTap: exists
                            ? null
                            : () {
                                setState(() {
                                  _currencies.add(_CurrencyEntry(
                                    code: code,
                                    symbol: symbol,
                                    rate: rate,
                                    digits: digits,
                                  ));
                                });
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$code ${isEs ? 'agregado con tasa en tiempo real' : 'added with live rate'}')),
                                );
                              },
                      ),
                    ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.2, end: 0);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${isEs ? 'Error al obtener tasas: ' : 'Error fetching rates: '}$e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  String _formatPreview(String code, String symbol, String rate) {
    try {
      final r = double.parse(rate);
      final amount = 100.0 * r;
      return '\$100 USD = $symbol${amount.toStringAsFixed(2)} $code';
    } catch (_) {
      return '${isEs ? 'Vista previa no disponible' : 'Preview unavailable'}';
    }
  }

  bool get isEs => AppState.of(context).languageCode.value == 'es';

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
            final title = isEs ? 'Configuración de Monedas' : 'Currency Settings';
            final denied = isEs
                ? 'Acceso denegado. Solo administradores pueden acceder.'
                : 'Access denied. Admin access required.';

            final admin = _isAdmin(snapshot.data?.data());
            if (!admin) {
              return Scaffold(
                appBar: NvAppBar(
                  tickerVisible: AppState.of(context).showTicker.value,
                  title: title,
                  showBack: true,
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(denied, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Scaffold(
              appBar: NvAppBar(
                tickerVisible: AppState.of(context).showTicker.value,
                title: title,
                showBack: true,
                extraActions: [
                  IconButton(
                    tooltip: isEs ? 'Guardar' : 'Save',
                    onPressed: _saving ? null : _saveConfig,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                  ),
                ],
              ),
              body: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: Theme.of(context).brightness == Brightness.dark
                        ? [const Color(0xFF1a1a1a), const Color(0xFF000000)]
                        : [const Color(0xFFf5f5f5), const Color(0xFFe0e0e0)],
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeader(isEs),
                    const SizedBox(height: 24),
                    _buildDefaultCurrencySelector(isEs),
                    const SizedBox(height: 24),
                    _buildCurrencyList(isEs),
                    const SizedBox(height: 24),
                    _buildActionButtons(isEs),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: _addCurrency,
                icon: const Icon(Icons.add),
                label: Text(isEs ? 'Agregar Moneda' : 'Add Currency'),
                backgroundColor: const Color(0xFF4CAF50),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(bool isEs) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF4CAF50),
              ),
              child: const Icon(Icons.attach_money, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs ? 'Gestión de Monedas' : 'Currency Management',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEs
                        ? 'Configura las monedas y tasas de cambio'
                        : 'Configure currencies and exchange rates',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildDefaultCurrencySelector(bool isEs) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                Text(
                  isEs ? 'Moneda Predeterminada' : 'Default Currency',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _defaultCurrency,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
              ),
              items: _currencies
                  .map((e) => e.code.text.trim())
                  .where((c) => c.isNotEmpty)
                  .map((code) {
                    final entry = _currencies.firstWhere((e) => e.code.text.trim() == code);
                    return DropdownMenuItem(
                      value: code,
                      child: Row(
                        children: [
                          Text(entry.symbol.text.trim().isEmpty ? code : entry.symbol.text.trim(),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          Text(code),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _defaultCurrency = value);
                }
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildCurrencyList(bool isEs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.list, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                isEs ? 'Monedas Configuradas' : 'Configured Currencies',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_currencies.length} ${isEs ? 'monedas' : 'currencies'}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ..._currencies.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isDefault = item.code.text.trim() == _defaultCurrency;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: isDefault ? 4 : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isDefault
                  ? const BorderSide(color: Color(0xFF4CAF50), width: 2)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: item.symbol,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: '\$',
                            labelText: isEs ? 'Símbolo' : 'Symbol',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: item.code,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Código' : 'Code',
                            hintText: 'USD',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: isEs ? 'Eliminar' : 'Remove',
                        onPressed: () => _removeCurrency(index),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: item.rate,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: isEs ? 'Tasa desde USD' : 'Rate from USD',
                            hintText: '1.0',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            prefixIcon: const Icon(Icons.currency_exchange),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: item.digits,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Decimales' : 'Decimals',
                            hintText: '2',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calculate, size: 16, color: Color(0xFF4CAF50)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatPreview(item.code.text.trim(), item.symbol.text.trim(), item.rate.text.trim()),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDefault)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 4),
                          Text(
                            isEs ? 'Moneda predeterminada' : 'Default currency',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: -0.1, end: 0);
        }),
      ],
    );
  }

  Widget _buildActionButtons(bool isEs) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _showPresetCurrencies,
            icon: const Icon(Icons.cloud_download),
            label: Text(isEs ? 'Descargar Monedas' : 'Download Currencies'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveConfig,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? (isEs ? 'Guardando...' : 'Saving...') : (isEs ? 'Guardar' : 'Save')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrencyEntry {
  final TextEditingController code;
  final TextEditingController symbol;
  final TextEditingController rate;
  final TextEditingController digits;

  _CurrencyEntry({String? code, String? symbol, String? rate, String? digits})
      : code = TextEditingController(text: code ?? ''),
        symbol = TextEditingController(text: symbol ?? ''),
        rate = TextEditingController(text: rate ?? ''),
        digits = TextEditingController(text: digits ?? '');

  void dispose() {
    code.dispose();
    symbol.dispose();
    rate.dispose();
    digits.dispose();
  }
}
