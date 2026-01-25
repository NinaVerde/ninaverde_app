// lib/screens/settings_pages.dart
import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';
// import '../widgets/radio_group.dart'; // Unused
import '../services/config_service.dart' hide debugPrint;
import '../models/app_config_model.dart';
import '../services/theme_service.dart';
import '../models/theme_config_model.dart';
import '../services/theme_service.dart';
import '../models/theme_config_model.dart';

/// ---------- Language Settings ----------
class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  bool _saving = false;

  Future<void> _saveDefaults(AppState app, String newDefault) async {
    setState(() => _saving = true);
    try {
      final current = await ConfigService.getLocalizationConfig();
      final updated = current.copyWith(defaultLanguage: newDefault);
      await ConfigService.saveLocalizationConfig(updated);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, en: 'Global default saved.', es: 'Predeterminado global guardado.'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving config'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addLanguage(AppState app) async {
    final codeCtl = TextEditingController();
    final labelCtl = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'Add Language', es: 'Agregar Idioma')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtl,
              decoration: const InputDecoration(labelText: 'Code (e.g. fr)', hintText: 'ISO 2-letter code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: labelCtl,
              decoration: const InputDecoration(labelText: 'Label (e.g. Français)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(context, en: 'Cancel', es: 'Cancelar'))),
          FilledButton(
            onPressed: () async {
              final code = codeCtl.text.trim().toLowerCase();
              final label = labelCtl.text.trim();
              if (code.isNotEmpty && label.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _saving = true);
                try {
                  await ConfigService.addLanguage(code, label);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text(tr(context, en: 'Language added.', es: 'Idioma agregado.'))),
                    );
                  }
                } catch (e) {
                   debugPrint('Error: $e');
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              }
            }, 
            child: Text(tr(context, en: 'Add', es: 'Agregar'))
          ),
        ],
      ),
    );
  }

  Future<void> _removeLanguage(AppState app, String code) async {
     // Protected codes
     if (code == 'en' || code == 'es') {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(tr(context, en: 'Cannot remove default languages.', es: 'No se pueden eliminar idiomas predeterminados.'))),
       );
       return;
     }

     final ok = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
         title: Text(tr(context, en: 'Remove Language?', es: '¿Eliminar Idioma?')),
         content: Text(tr(context, en: 'This will remove $code from the app.', es: 'Esto eliminará $code de la app.')),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(context, en: 'Cancel', es: 'Cancelar'))),
           FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(context, en: 'Delete', es: 'Eliminar'))),
         ],
       ),
     );
     
     if (ok == true) {
       setState(() => _saving = true);
       try {
         await ConfigService.removeLanguage(code);
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr(context, en: 'Language removed.', es: 'Idioma eliminado.'))),
            );
         }
       } catch (e) {
         debugPrint('Error removing lang: $e');
       } finally {
         if (mounted) setState(() => _saving = false);
       }
     }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final isManager = app.isManager.value;

    if (!isManager) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, en: 'Access Denied', es: 'Acceso Denegado'))),
        body: Center(child: Text(tr(context, en: 'Admin permissions required.', es: 'Se requieren permisos de administrador.'))),
      );
    }

    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (_, __, ___) {
        final title = tr(
          context,
          en: 'Global Language Settings',
          es: 'Configuracion Global de Idioma',
        );
        return Scaffold(
          appBar: NvAppBar(title: title, showBack: true),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addLanguage(app),
            child: const Icon(Icons.add),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  tr(context, 
                    en: 'Manage available languages. English (en) and Spanish (es) are protected.',
                    es: 'Administre idiomas disponibles. Inglés (en) y Español (es) están protegidos.'
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (_saving) const LinearProgressIndicator(),
              Expanded(
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: app.languageOptions,
                  builder: (context, options, _) {
                    return ValueListenableBuilder<Map<String, String>>(
                      valueListenable: app.languageLabels,
                      builder: (context, labels, _) {
                        return FutureBuilder<AppLocalizationConfig>(
                          future: ConfigService.getLocalizationConfig(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            final config = snapshot.data!;
                            
                            return ListView.separated(
                              itemCount: options.length,
                              separatorBuilder: (_,__) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final lang = options[index];
                                final label = labels[lang] ?? lang.toUpperCase();
                                final isDefault = config.defaultLanguage == lang;
                                final isProtected = lang == 'en' || lang == 'es';
                                
                                return ListTile(
                                  title: Text('$label ($lang)', style: TextStyle(fontWeight: isDefault ? FontWeight.bold : FontWeight.normal)),
                                  leading: Radio<String>(
                                    value: lang,
                                    groupValue: config.defaultLanguage,
                                    onChanged: (val) {
                                      if (val != null) _saveDefaults(app, val);
                                    },
                                  ),
                                  trailing: isProtected 
                                      ? const Icon(Icons.lock, color: Colors.grey, size: 20)
                                      : IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _removeLanguage(app, lang),
                                        ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}



/// ---------- Currency Settings ----------
class CurrencySettingsPage extends StatefulWidget {
  const CurrencySettingsPage({super.key});

  @override
  State<CurrencySettingsPage> createState() => _CurrencySettingsPageState();
}

class _CurrencySettingsPageState extends State<CurrencySettingsPage> {
  bool _saving = false;

  Future<void> _saveDefaults(AppState app, String newDefault) async {
    setState(() => _saving = true);
    try {
      final current = await ConfigService.getLocalizationConfig();
      final updated = current.copyWith(defaultCurrency: newDefault);
      await ConfigService.saveLocalizationConfig(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, en: 'Global default saved.', es: 'Predeterminado global guardado.'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving config'), backgroundColor: Colors.red),
        );
      }
    } finally {
       if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addCurrency(AppState app) async {
    final codeCtl = TextEditingController(); // e.g. EUR
    final symbolCtl = TextEditingController(); // e.g. €
    final rateCtl = TextEditingController(text: '1.0');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'Add Currency', es: 'Agregar Moneda')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtl,
              decoration: const InputDecoration(labelText: 'Code (e.g. EUR)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: symbolCtl,
              decoration: const InputDecoration(labelText: 'Symbol (e.g. €)'),
            ),
            const SizedBox(height: 12),
             TextField(
              controller: rateCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Rate to USD'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(context, en: 'Cancel', es: 'Cancelar'))),
          FilledButton(
            onPressed: () async {
              final code = codeCtl.text.trim().toUpperCase();
              final symbol = symbolCtl.text.trim();
              final rate = double.tryParse(rateCtl.text.trim()) ?? 1.0;
              
              if (code.isNotEmpty && symbol.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _saving = true);
                try {
                  await ConfigService.addCurrency(code, symbol, rate);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text(tr(context, en: 'Currency added.', es: 'Moneda agregada.'))),
                    );
                  }
                } catch (e) {
                   debugPrint('Error: $e');
                } finally {
                  if (mounted) setState(() => _saving = false);
                }
              }
            }, 
            child: Text(tr(context, en: 'Add', es: 'Agregar'))
          ),
        ],
      ),
    );
  }

  Future<void> _removeCurrency(AppState app, String code) async {
     // Protected codes
     if (code == 'USD' || code == 'NIO') {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text(tr(context, en: 'Cannot remove default currencies (USD/NIO).', es: 'No se pueden eliminar monedas predeterminadas.'))),
       );
       return;
     }

     final ok = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
         title: Text(tr(context, en: 'Remove Currency?', es: '¿Eliminar Moneda?')),
         content: Text(tr(context, en: 'This will remove $code.', es: 'Esto eliminará $code.')),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(context, en: 'Cancel', es: 'Cancelar'))),
           FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(context, en: 'Delete', es: 'Eliminar'))),
         ],
       ),
     );
     
     if (ok == true) {
       setState(() => _saving = true);
       try {
         await ConfigService.removeCurrency(code);
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr(context, en: 'Currency removed.', es: 'Moneda eliminada.'))),
            );
         }
       } catch (e) {
         debugPrint('Error removing currency: $e');
       } finally {
         if (mounted) setState(() => _saving = false);
       }
     }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final isManager = app.isManager.value;

    if (!isManager) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, en: 'Access Denied', es: 'Acceso Denegado'))),
        body: Center(child: Text(tr(context, en: 'Admin permissions required.', es: 'Se requieren permisos de administrador.'))),
      );
    }

    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (_, __, ___) {
        final title = tr(
          context,
          en: 'Global Currency Settings',
          es: 'Configuracion Global de Moneda',
        );
        return Scaffold(
          appBar: NvAppBar(title: title, showBack: true),
          floatingActionButton: FloatingActionButton(
             onPressed: () => _addCurrency(app),
             child: const Icon(Icons.add),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  tr(context, 
                    en: 'Manage currencies. USD and NIO are protected.',
                    es: 'Administre monedas. USD y NIO están protegidos.'
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (_saving) const LinearProgressIndicator(),
              Expanded(
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: app.currencyOptions,
                  builder: (context, options, _) {
                    return ValueListenableBuilder<Map<String, CurrencyConfig>>(
                      valueListenable: app.currencyConfigs,
                      builder: (context, configs, _) {
                        return FutureBuilder<AppLocalizationConfig>(
                          future: ConfigService.getLocalizationConfig(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            final config = snapshot.data!;
                            
                            return ListView.separated(
                              itemCount: options.length,
                              separatorBuilder: (_,__) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final code = options[index];
                                final cfg = configs[code];
                                final label = cfg == null
                                    ? code
                                    : '${cfg.code} - ${cfg.symbol}';
                                final isDefault = config.defaultCurrency == code;
                                final isProtected = code == 'USD' || code == 'NIO';
                                
                                return ListTile(
                                  title: Text(label, style: TextStyle(fontWeight: isDefault ? FontWeight.bold : FontWeight.normal)),
                                  subtitle: cfg != null ? Text('Rate: ${cfg.rateFromUsd}') : null,
                                  leading: Radio<String>(
                                    value: code,
                                    groupValue: config.defaultCurrency,
                                    onChanged: (val) {
                                      if (val != null) _saveDefaults(app, val);
                                    },
                                  ),
                                  trailing: isProtected
                                    ? const Icon(Icons.lock, color: Colors.grey, size: 20)
                                    : IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () => _removeCurrency(app, code),
                                      ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// ---------- Ticker Settings ----------
class TickerSettingsPage extends StatefulWidget {
  const TickerSettingsPage({super.key});

  @override
  State<TickerSettingsPage> createState() => _TickerSettingsPageState();
}

class _TickerItem {
  final String id;
  String text;
  _TickerItem(this.text) : id = UniqueKey().toString();
}

class _TickerSettingsPageState extends State<TickerSettingsPage> {
  late bool _showLocal;
  late double _speedLocal;
  late TickerDirection _directionLocal;
  late Color _laneLightLocal, _laneDarkLocal, _railLightLocal, _railDarkLocal;
  late Color _textLightLocal, _textDarkLocal;
  
  // Local mutable state
  List<_TickerItem> _items = [];
  
  // Originals for change detection
  List<String> _originalSource = [];
  List<String> _originalTarget = []; // The "other" language
  
  final GoogleTranslator _translator = GoogleTranslator();
  bool _isSaving = false;
  bool _isTranslating = false;
  String? _lastLanguageCode;
  double? _initialSpeed; // To revert on cancel

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppState.of(context);
    
    // Only initialize once or if language changed externally without us tracking
    if (_lastLanguageCode == null) {
      _showLocal = app.showTicker.value;
      
      // Capture initial speed for revert logic
      if (_initialSpeed == null) {
        _speedLocal = app.tickerSpeedPx.value;
        _initialSpeed = _speedLocal;
      }
      
      _directionLocal = app.tickerDirection.value;

      _laneLightLocal = app.laneLight.value;
      _laneDarkLocal = app.laneDark.value;
      _railLightLocal = app.railLight.value;
      _railDarkLocal = app.railDark.value;
      _textLightLocal = app.textLight.value;
      _textDarkLocal = app.textDark.value;
      
      _lastLanguageCode = app.languageCode.value;
      // Do not list to language changes dynamically here because it resets edits.
      // We assume user stays in one language while editing.
      
      final isEs = _lastLanguageCode == 'es';
      final src = isEs ? app.tickerEs.value : app.tickerEn.value;
      final target = isEs ? app.tickerEn.value : app.tickerEs.value;
      
      _originalSource = List.from(src);
      _originalTarget = List.from(target);
      
      _items = src.map((s) => _TickerItem(s)).toList();
      if (_items.isEmpty) _items.add(_TickerItem('')); 
    }
  }

  // Helper to safely get index from list
  String _safeGet(List<String> list, int index) {
    if (index >= 0 && index < list.length) return list[index];
    return '';
  }

  @override
  void dispose() {
    // AppState.of(context).languageCode.removeListener(_onLanguageChanged); // Removed listener to prevent overwrite
    super.dispose();
  }

  Future<String> _translateSafe(String text, String from, String to) async {
    const token = '[[__BRAND__]]';
    const tokenNaturally = '[[__NATURALLY__]]';
    
    // Mask: Replace variations of Brand Name with token
    String masked = text.replaceAll(RegExp(r'Niña Verde', caseSensitive: false), token);
    masked = masked.replaceAll(RegExp(r'Nina Verde', caseSensitive: false), token);
    
    // Mask "Naturally" / "Naturalmente" to enforce mapping
    masked = masked.replaceAll(RegExp(r'Naturally', caseSensitive: false), tokenNaturally);
    masked = masked.replaceAll(RegExp(r'Naturalmente', caseSensitive: false), tokenNaturally);
    
    // Mask Dynamic Tokens so they don't get translated
    final tokens = ['USER_NAME', 'USER_F_NAME', 'USER_L_NAME', '_DAY_', '_DATE_', '_MONTH_', '_YEAR_'];
    for (final t in tokens) {
      masked = masked.replaceAll(t, '[[__${t}__]]');
    }

    // Translate
    final translation = await _translator.translate(masked, from: from, to: to);

    // Unmask
    String result = translation.text.replaceAll(token, 'Niña Verde');
    for (final t in tokens) {
      result = result.replaceAll('[[__${t}__]]', t);
    }
    
    // Unmask Naturally based on TARGET language
    if (to == 'es') {
       result = result.replaceAll(tokenNaturally, 'Naturalmente');
    } else {
       result = result.replaceAll(tokenNaturally, 'Naturally');
    }
    
    return result;
  }

  Future<void> _saveAndExit() async {
    setState(() => _isSaving = true);
    final app = AppState.of(context);
    final isEs = _lastLanguageCode == 'es';
    
    app.tickerSpeedPx.value = _speedLocal;

    // Filter out completely empty messages
    final cleanItems = _items.where((m) => m.text.trim().isNotEmpty).toList();
    if (cleanItems.isEmpty) cleanItems.add(_TickerItem('')); 

    List<String> newSource = [];
    List<String> newTarget = [];

    // SMART TRANSLATION LOGIC
    // Only translate if the message has Changed from _originalSource or creates a new entry
    try {
      for (int i = 0; i < cleanItems.length; i++) {
        final item = cleanItems[i];
        final text = item.text;
        
        newSource.add(text);
        
        // Check if this item existed in original source at this index
        // Limitation: If we reorder, indices shift. 
        // Ideally we'd track matches by ID, but we generated IDs just now.
        // So we rely on text comparison safely.
        // If the user reordered, we unfortunately lose the 'link' to the old translation unless the text is identical.
        // But the user said: "original message should never change".
        
        // Let's assume reordering is "changing structure".
        // If I move "Hello" to index 0, and "Hello" was at index 5...
        // We should try to find "Hello" in _originalSource to see if we have a robust translation for it.
        
        int originalIndex = _originalSource.indexOf(text);
        
        if (originalIndex != -1) {
          // Exact match found in original!
          // Use the EXISTING translation for that index, if available.
          final existingTrans = _safeGet(_originalTarget, originalIndex);
          if (existingTrans.isNotEmpty) {
             newTarget.add(existingTrans);
             continue; // Done, preserved original.
          }
        }
        
        // If we get here, it's either NEW, CHANGED, or legacy mapping failed. 
        // We MUST translate.
        if (isEs) {
          final enText = await _translateSafe(text, 'es', 'en');
          newTarget.add(enText);
        } else {
          final esText = await _translateSafe(text, 'en', 'es');
          newTarget.add(esText);
        }
      }
    } catch (e) {
      // Fallback
      newSource = cleanItems.map((e) => e.text).toList();
      newTarget = List.from(newSource); // Copy as fail-safe
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(context, en: 'Translation failed. Saved raw text.', es: 'Fallo traducción. Guardado texto original.')),
        ));
      }
    }

    // Update Global State
    app.showTicker.value = _showLocal;
    app.tickerDirection.value = _directionLocal;
    
    if (isEs) {
      app.tickerEs.value = newSource;
      app.tickerEn.value = newTarget;
    } else {
      app.tickerEn.value = newSource;
      app.tickerEs.value = newTarget;
    }

    // Persist
    try {
      await ConfigService.saveTickerConfig(TickerConfig(
        show: _showLocal,
        messagesEs: isEs ? newSource : newTarget,
        messagesEn: isEs ? newTarget : newSource,
        speedPx: _speedLocal,
        direction: _directionLocal,
        laneLight: _laneLightLocal,
        laneDark: _laneDarkLocal,
        railLight: _railLightLocal,
        railDark: _railDarkLocal,
        textLight: _textLightLocal,
        textDark: _textDarkLocal,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, en: 'Ticker settings saved', es: 'Ajustes del ticker guardados'))));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving settings'), backgroundColor: Colors.red));
      }
      setState(() => _isSaving = false);
    }
  }
  
  void _onCancel() {
    if (_initialSpeed != null) {
      AppState.of(context).tickerSpeedPx.value = _initialSpeed!;
    }
    Navigator.pop(context);
  }

  static String _toHex(Color c, {bool leadingHash = true}) {
    final argb = c.toARGB32();
    return '${leadingHash ? '#' : ''}${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  static Color _parseHex(String input, Color fallback) {
    final s = input.trim();
    final hex = s.startsWith('#') ? s.substring(1) : s;
    if (hex.length == 6) {
      final v = int.tryParse('FF$hex', radix: 16);
      if (v != null) return Color(v);
    } else if (hex.length == 8) {
      final v = int.tryParse(hex, radix: 16);
      if (v != null) return Color(v);
    }
    return fallback;
  }

  Future<void> _confirmRemove(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'Remove message?', es: 'Eliminar mensaje?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(context, en: 'No', es: 'No'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(context, en: 'Yes', es: 'Si'))),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        if (index >= 0 && index < _items.length) _items.removeAt(index);
      });
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  Widget _buildLegendItem(String token, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          children: [
            TextSpan(text: token, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Courier', color: Colors.blueGrey)),
            const TextSpan(text: ' : '),
            TextSpan(text: desc),
          ],
        ),
      ),
    );
  }

  Widget _colorRow({required String label, required Color value, required ValueChanged<Color> onChanged}) {
    final ctl = TextEditingController(text: _toHex(value));
    return Row(
      children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: value, borderRadius: BorderRadius.circular(6))),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctl,
            decoration: InputDecoration(labelText: label, helperText: tr(context, en: 'Hex ARGB (#AARRGGBB)', es: 'Hex ARGB (#AARRGGBB)'), isDense: true, border: const OutlineInputBorder()),
            onChanged: (s) => onChanged(_parseHex(s, value)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaving) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(context, en: 'Saving...', es: 'Guardando...'))),
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(tr(context, en: 'Saving...', es: 'Guardando...')),
          ],
        )),
      );
    }

    final app = AppState.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: NvAppBar(
            tickerVisible: _showLocal, // Live preview based on switch
            title: tr(context, en: 'Ticker Settings', es: 'Ajustes del Ticker'),
            showBack: true,
            bottom: _isTranslating ? const PreferredSize(
              preferredSize: Size.fromHeight(4), 
              child: LinearProgressIndicator(minHeight: 4),
            ) : null,
          ),
          body: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(tabs: [
                  Tab(text: tr(context, en: 'Messages', es: 'Mensajes')),
                  Tab(text: tr(context, en: 'Appearance', es: 'Apariencia'))
                ]),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          SwitchListTile(
                              title: Text(tr(context,
                                  en: 'Show ticker', es: 'Mostrar ticker')),
                              value: _showLocal,
                              onChanged: (v) {
                                setState(() => _showLocal = v);
                                app.showTicker.value = v; // Live preview
                              }),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(tr(context, en: 'Scroll Direction', es: 'Dirección'),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              DropdownButton<TickerDirection>(
                              value: _directionLocal,
                                items: [
                                  DropdownMenuItem(value: TickerDirection.rtl, child: Text(tr(context, en: 'Right to Left (Standard)', es: 'Derecha a Izquierda (Estándar)'))),
                                  DropdownMenuItem(value: TickerDirection.ltr, child: Text(tr(context, en: 'Left to Right', es: 'Izquierda a Derecha'))),
                                  DropdownMenuItem(value: TickerDirection.ttb, child: Text(tr(context, en: 'Top to Bottom', es: 'Arriba a Abajo'))),
                                  DropdownMenuItem(value: TickerDirection.btt, child: Text(tr(context, en: 'Bottom to Top', es: 'Abajo a Arriba'))),
                                  DropdownMenuItem(value: TickerDirection.fade, child: Text(tr(context, en: 'Fade In/Out', es: 'Desvanecer'))),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      _directionLocal = v;
                                      // Clamp speed for "slow" modes
                                      // Increased by 25% (80 -> 100, 200 -> 250)
                                      final limit = (v == TickerDirection.fade || v == TickerDirection.ttb || v == TickerDirection.btt) ? 100.0 : 250.0;
                                      if (_speedLocal > limit) {
                                        _speedLocal = limit;
                                        app.tickerSpeedPx.value = limit;
                                      }
                                    });
                                    app.tickerDirection.value = v; // Live preview
                                  }
                                }
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(tr(context, en: 'Speed / Duration', es: 'Velocidad / Duración'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Slider(
                              value: _speedLocal,
                              min: 10,
                              max: (_directionLocal == TickerDirection.fade || _directionLocal == TickerDirection.ttb || _directionLocal == TickerDirection.btt) ? 100.0 : 250.0,
                              divisions: 50,
                              label: '${_speedLocal.toStringAsFixed(0)} px/s',
                              onChanged: (v) {
                                setState(() => _speedLocal = v);
                                app.tickerSpeedPx.value = v; // Live preview
                              }),
                          const SizedBox(height: 12),
                          _buildSingleSourceEditor(),
                          const SizedBox(height: 80),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                              tr(context,
                                  en: 'Colors — Light Mode',
                                  es: 'Colores — Modo Claro'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          _colorRow(
                              label: tr(context, en: 'Lane', es: 'Pista'),
                              value: _laneLightLocal,
                              onChanged: (c) =>
                                  setState(() => _laneLightLocal = c)),
                          _colorRow(
                              label: tr(context, en: 'Rails', es: 'Rieles'),
                              value: _railLightLocal,
                              onChanged: (c) =>
                                  setState(() => _railLightLocal = c)),
                          _colorRow(
                              label: tr(context, en: 'Text', es: 'Texto'),
                              value: _textLightLocal,
                              onChanged: (c) =>
                                  setState(() => _textLightLocal = c)),
                          const SizedBox(height: 20),
                          Text(
                              tr(context,
                                  en: 'Colors — Dark Mode',
                                  es: 'Colores — Modo Oscuro'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          _colorRow(
                              label: tr(context, en: 'Lane', es: 'Pista'),
                              value: _laneDarkLocal,
                              onChanged: (c) =>
                                  setState(() => _laneDarkLocal = c)),
                          _colorRow(
                              label: tr(context, en: 'Rails', es: 'Rieles'),
                              value: _railDarkLocal,
                              onChanged: (c) =>
                                  setState(() => _railDarkLocal = c)),
                          _colorRow(
                              label: tr(context, en: 'Text', es: 'Texto'),
                              value: _textDarkLocal,
                              onChanged: (c) =>
                                  setState(() => _textDarkLocal = c)),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: _onCancel,
                          child: Text(
                              tr(context, en: 'Cancel', es: 'Cancelar')))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: FilledButton(
                          onPressed: _saveAndExit,
                          child: Text(tr(context, en: 'Save', es: 'Guardar')))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleSourceEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text(
              tr(context, en: 'Ticker Bulletins', es: 'Boletines del Ticker'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
             IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: tr(context, en: 'Formatting Legend', es: 'Leyenda de Formato'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    final theme = Theme.of(context);
                    final isDark = theme.brightness == Brightness.dark;
                    final tokenStyle = TextStyle(
                      fontFamily: 'Courier', 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.greenAccent : Colors.blueGrey[800],
                    );
                    final descStyle = theme.textTheme.bodyMedium;
                    
                    Widget buildRow(String token, String desc) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            SizedBox(
                              width: 120, 
                              child: Text(token, style: tokenStyle),
                            ),
                            Expanded(child: Text(desc, style: descStyle)),
                          ],
                        ),
                      );
                    }

                    return AlertDialog(
                      title: Text(tr(context, en: 'Formatting Legend', es: 'Leyenda de Formato')),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(context, en: 'Style', es: 'Estilo'), 
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)
                            ),
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Text('_Bold Text_', style: tokenStyle.copyWith(fontWeight: FontWeight.normal)),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Text('Bold Text', style: descStyle?.copyWith(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              tr(context, en: 'Dynamic Tokens', es: 'Tokens Dinámicos'), 
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)
                            ),
                            const Divider(),
                            buildRow('USER_NAME', 'Full Name'),
                            buildRow('USER_F_NAME', 'First Name'),
                            const SizedBox(height: 8),
                            buildRow('_DAY_', 'Day (e.g. Friday)'),
                            buildRow('_DATE_', 'Date (e.g. 23)'),
                            buildRow('_MONTH_', 'Month (e.g. January)'),
                            buildRow('_YEAR_', 'Year (e.g. 2025)'),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tr(
            context, 
            en: 'Single List: Saving will auto-translate to other languages.', 
            es: 'Lista Única: Al guardar se traducirá automáticamente.'
          ),
          style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 10),

        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          onReorder: _reorder,
          itemBuilder: (ctx, i) => Card(
            key: ValueKey(_items[i].id), // Stable key for reordering
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const Icon(Icons.drag_handle, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _items[i].text,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.all(10),
                      ),
                      onChanged: (v) {
                        _items[i].text = v;
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmRemove(i),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _items.add(_TickerItem(''));
              });
            },
            icon: const Icon(Icons.add),
            label: Text(tr(context, en: 'Add message', es: 'Agregar mensaje')),
          ),
        ),
      ],
    );
  }
}

/// ---------- Theme Settings ----------
class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  bool _isLoading = true;
  AppThemeConfig _config = const AppThemeConfig();
  
  @override
  void initState() {
    super.initState();
    _loadConfig();
  }
  
  Future<void> _loadConfig() async {
    final cfg = await ThemeService.getThemeConfig();
    if (mounted) setState(() { _config = cfg; _isLoading = false; });
  }

  Future<void> _deleteTheme(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'Delete Theme?', es: '¿Eliminar Tema?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(context, en: 'Cancel', es: 'Cancelar'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(context, en: 'Delete', es: 'Eliminar'))),
        ],
      ),
    );
    if (ok != true) return;
    
    final newThemes = _config.customThemes.where((t) => t.id != id).toList();
    final newConfig = AppThemeConfig(
      customThemes: newThemes,
      defaultLightId: _config.defaultLightId == id ? 'default_light' : _config.defaultLightId, 
      defaultDarkId: _config.defaultDarkId == id ? 'default_dark' : _config.defaultDarkId,
    );
    
    await ThemeService.saveThemeConfig(newConfig);
    await _loadConfig();
    
    if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, en: 'Theme deleted. Restart app to apply fully.', es: 'Tema eliminado. Reinicie para aplicar.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final isManager = app.isManager.value;
    if (!isManager) {
       return const Scaffold(body: Center(child: Text('Access Denied')));
    }
    
    final title = tr(context, en: 'Theme Manager', es: 'Gestor de Temas');
    
    return Scaffold(
      appBar: NvAppBar(title: title, showBack: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const _ThemeEditor()),
          );
          _loadConfig(); // Refresh on return
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCurrentPalettesHeader(context, app),
                const SizedBox(height: 16),
                _buildSectionHeader(tr(context, en: 'Default Themes (Protected)', es: 'Temas Predeterminados')),
                _buildThemeCard(
                   CustomTheme(
                     id: 'default_light', name: 'Light Mode (Default)', isDark: false, 
                     primaryColor: Colors.green, secondaryColor: Colors.amber, 
                     surfaceColor: Colors.white, backgroundColor: const Color(0xFFF9FBF9), 
                     errorColor: Colors.red, onPrimary: Colors.white, onSurface: Colors.black
                   ),
                   isProtected: true,
                ),
                _buildThemeCard(
                   CustomTheme(
                     id: 'default_dark', name: 'Dark Mode (Default)', isDark: true, 
                     primaryColor: Colors.green, secondaryColor: Colors.amber, 
                     surfaceColor: const Color(0xFF1E1E1E), backgroundColor: const Color(0xFF121212), 
                     errorColor: Colors.redAccent, onPrimary: Colors.black, onSurface: Colors.white
                   ),
                   isProtected: true,
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(tr(context, en: 'Custom Themes', es: 'Temas Personalizados')),
                if (_config.customThemes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(tr(context, en: 'No custom themes yet.', es: 'Sin temas personalizados.'), style: TextStyle(color: Colors.grey)),
                  ),
                ..._config.customThemes.map((t) => _buildThemeCard(t, isProtected: false)),
              ],
            ),
    );
  }

  Widget _buildCurrentPalettesHeader(BuildContext context, AppState app) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, en: 'ACTIVE SYSTEM PALETTES', es: 'PALETAS ACTIVAS DEL SISTEMA'),
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 2, color: Colors.greenAccent),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    _DnaPaletteBar(
                      theme: CustomTheme(
                        id: 'def_light', name: '', isDark: false, 
                        primaryColor: Colors.green, secondaryColor: Colors.amber, 
                        surfaceColor: Colors.white, backgroundColor: const Color(0xFFF9FBF9), 
                        errorColor: Colors.red, onPrimary: Colors.white, onSurface: Colors.black
                      ),
                      height: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('DARK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    _DnaPaletteBar(
                      theme: CustomTheme(
                        id: 'def_dark', name: '', isDark: true, 
                        primaryColor: Colors.green, secondaryColor: Colors.amber, 
                        surfaceColor: const Color(0xFF1E1E1E), backgroundColor: const Color(0xFF121212), 
                        errorColor: Colors.redAccent, onPrimary: Colors.black, onSurface: Colors.white
                      ),
                      height: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, letterSpacing: 1.2)),
    );
  }
  
  Widget _buildThemeCard(CustomTheme theme, {bool isProtected = false}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isProtected ? null : () async {
           await Navigator.push(
             context,
             MaterialPageRoute(builder: (_) => _ThemeEditor(theme: theme)),
           );
           _loadConfig();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, 
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(theme.isDark ? Icons.dark_mode : Icons.light_mode, size: 20, color: theme.primaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(theme.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        Text(theme.isDark ? 'Elite Dark Theme' : 'High-Fidelity Light Theme', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (!isProtected)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _deleteTheme(theme.id),
                    )
                  else
                    const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              _DnaPaletteBar(theme: theme, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeEditor extends StatefulWidget {
  final CustomTheme? theme; // If null, new
  const _ThemeEditor({this.theme});

  @override
  State<_ThemeEditor> createState() => _ThemeEditorState();
}

class _ThemeEditorState extends State<_ThemeEditor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtl;
  bool _isDark = false;
  
  // Colors
  late Color _primary;
  late Color _secondary;
  late Color _surface;
  late Color _background;
  late Color _error;
  late Color _onPrimary;
  late Color _onSurface;

  bool _showComparison = false;
  final CustomTheme _defaultLight = CustomTheme(
      id: 'def_light', name: 'Default Light', isDark: false, 
      primaryColor: Colors.green, secondaryColor: Colors.amber, 
      surfaceColor: Colors.white, backgroundColor: const Color(0xFFF9FBF9), 
      errorColor: Colors.red, onPrimary: Colors.white, onSurface: Colors.black
  );
  final CustomTheme _defaultDark = CustomTheme(
      id: 'def_dark', name: 'Default Dark', isDark: true, 
      primaryColor: Colors.green, secondaryColor: Colors.amber, 
      surfaceColor: const Color(0xFF1E1E1E), backgroundColor: const Color(0xFF121212), 
      errorColor: Colors.redAccent, onPrimary: Colors.black, onSurface: Colors.white
  );

  @override
  void initState() {
    super.initState();
    final t = widget.theme;
    _nameCtl = TextEditingController(text: t?.name ?? '');
    _isDark = t?.isDark ?? false;
    _primary = t?.primaryColor ?? Colors.green;
    _secondary = t?.secondaryColor ?? Colors.amber;
    _surface = t?.surfaceColor ?? Colors.white;
    _background = t?.backgroundColor ?? Colors.grey[50]!;
    _error = t?.errorColor ?? Colors.red;
    _onPrimary = t?.onPrimary ?? Colors.white;
    _onSurface = t?.onSurface ?? Colors.black;
  }
  
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final newId = widget.theme?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    final newTheme = CustomTheme(
      id: newId,
      name: _nameCtl.text.trim(),
      isDark: _isDark,
      primaryColor: _primary,
      secondaryColor: _secondary,
      surfaceColor: _surface,
      backgroundColor: _background,
      errorColor: _error,
      onPrimary: _onPrimary,
      onSurface: _onSurface,
    );
    
    // Load config, append/replace, save
    try {
      final config = await ThemeService.getThemeConfig();
      final List<CustomTheme> themes = List.from(config.customThemes);
      
      final index = themes.indexWhere((t) => t.id == newId);
      if (index >= 0) {
        themes[index] = newTheme;
      } else {
        themes.add(newTheme);
      }
      
      final newConfig = AppThemeConfig(
        customThemes: themes,
        defaultLightId: config.defaultLightId,
        defaultDarkId: config.defaultDarkId
      );
      
      await ThemeService.saveThemeConfig(newConfig);
      
      if (mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, en: 'Theme Saved', es: 'Tema Guardado'))));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving theme')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(_showComparison ? Icons.compare : Icons.compare_arrows,
                color: _showComparison ? Colors.greenAccent : null),
            onPressed: () => setState(() => _showComparison = !_showComparison),
            tooltip: tr(context, en: 'Comparison Mode', es: 'Modo Comparación'),
          ),
          IconButton(icon: const Icon(Icons.check), onPressed: _save)
        ],
      ),
      body: Row(
        children: [
          if (_showComparison) _buildComparisonPanel(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Preview Box (Now Glassmorphic)
                  _buildGlassmorphicPreview(),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _nameCtl,
                    decoration: InputDecoration(
                        labelText: tr(context, en: 'Theme Name', es: 'Nombre del Tema'),
                        border: const OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(tr(context, en: 'Dark Mode?', es: '¿Modo Oscuro?')),
                    value: _isDark,
                    onChanged: (v) => setState(() => _isDark = v),
                  ),

                  const Divider(height: 32),
                  Text(tr(context, en: 'Palette', es: 'Paleta'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),

                  _buildColorPicker('Primary', _primary, (c) => setState(() => _primary = c)),
                  _buildColorPicker('Secondary', _secondary, (c) => setState(() => _secondary = c)),
                  _buildColorPicker('Background', _background, (c) => setState(() => _background = c)),
                  _buildColorPicker('Surface/Card', _surface, (c) => setState(() => _surface = c)),
                  _buildColorPicker(
                      'Text/Icons (On Surface)', _onSurface, (c) => setState(() => _onSurface = c)),
                  _buildColorPicker(
                      'Text/Icons (On Primary)', _onPrimary, (c) => setState(() => _onPrimary = c)),
                  _buildColorPicker('Error', _error, (c) => setState(() => _error = c)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildGlassmorphicPreview() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      height: 140,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Stack(
        children: [
           Positioned.fill(
             child: CustomPaint(
               painter: _GlassPainter(color: _primary.withOpacity(0.05)),
             ),
           ),
           Positioned(top: 15, left: 20, child: Text('LIVE PREVIEW', style: TextStyle(color: _onSurface.withOpacity(0.5), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 2))),
           Center(
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 _DnaPaletteBar(
                   theme: CustomTheme(
                     id: 'preview', name: '', isDark: _isDark, 
                     primaryColor: _primary, secondaryColor: _secondary, 
                     surfaceColor: _surface, backgroundColor: _background, 
                     errorColor: _error, onPrimary: _onPrimary, onSurface: _onSurface
                   ),
                   height: 8,
                 ),
                 const SizedBox(height: 16),
                 ElevatedButton(
                   style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: _onPrimary,
                      elevation: 8,
                      shadowColor: _primary.withOpacity(0.5),
                   ),
                   onPressed: (){}, 
                   child: const Text('Elite UI Element')
                 ),
               ],
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildComparisonPanel() {
    final ref = _isDark ? _defaultDark : _defaultLight;
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        border: Border(right: BorderSide(color: Colors.grey.withOpacity(0.2))),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        children: [
          const Text('REFERENCE', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 20),
          _buildRefColor('Primary', ref.primaryColor),
          _buildRefColor('Second', ref.secondaryColor),
          _buildRefColor('BG', ref.backgroundColor),
          _buildRefColor('Surface', ref.surfaceColor),
          _buildRefColor('Text', ref.onSurface),
          _buildRefColor('Error', ref.errorColor),
        ],
      ),
    );
  }

  Widget _buildRefColor(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildColorPicker(String label, Color color, ValueChanged<Color> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
             onTap: () { },
             child: Container(
               width: 40, height: 40,
               decoration: BoxDecoration(
                 color: color, 
                 borderRadius: BorderRadius.circular(8),
                 border: Border.all(color: Colors.grey),
               ),
             ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _HexColorField(
               color: color, 
               label: label, 
               onChanged: onChanged
            )
          ),
        ],
      ),
    );
  }
}

// Helper widget for Hex Input
class _HexColorField extends StatefulWidget {
  final Color color;
  final String label;
  final ValueChanged<Color> onChanged;
  const _HexColorField({required this.color, required this.label, required this.onChanged});

  @override
  State<_HexColorField> createState() => _HexColorFieldState();
}

class _HexColorFieldState extends State<_HexColorField> {
  late TextEditingController _ctl;
  
  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: _toHex(widget.color));
  }
  
  @override 
  void didUpdateWidget(covariant _HexColorField old) {
      super.didUpdateWidget(old);
      if (old.color != widget.color) {
          if (!_toHex(widget.color).contains(_ctl.text.toUpperCase().replaceAll('#', ''))) {
               _ctl.text = _toHex(widget.color);
          }
      }
  }

  String _toHex(Color c) {
    return '#${c.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctl,
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true, 
        border: const OutlineInputBorder(),
        hintText: '#AARRGGBB'
      ),
      onChanged: (v) {
         final val = v.trim().replaceAll('#', '');
         if (val.length == 8) {
            final intVal = int.tryParse(val, radix: 16);
            if (intVal != null) widget.onChanged(Color(intVal));
         } else if (val.length == 6) {
            final intVal = int.tryParse('FF$val', radix: 16);
            if (intVal != null) widget.onChanged(Color(intVal));
         }
      },
    );
  }
}

class _GlassPainter extends CustomPainter {
  final Color color;
  _GlassPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.2), 40, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.8), 30, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DnaPaletteBar extends StatelessWidget {
  final CustomTheme theme;
  final double height;
  final bool showLabels;

  const _DnaPaletteBar({
    required this.theme,
    this.height = 36,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      theme.primaryColor,
      theme.secondaryColor,
      theme.backgroundColor,
      theme.surfaceColor,
      theme.onSurface,
      theme.errorColor,
    ];

    final labels = [
      'Prim', 'Sec', 'Bg', 'Surf', 'Text', 'Err'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Row(
              children: List.generate(colors.length, (i) {
                return Expanded(
                  child: Container(
                    color: colors[i],
                    child: showLabels 
                      ? Center(
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: i == 4 ? (theme.isDark ? Colors.black : Colors.white) : colors[i].computeLuminance() > 0.5 ? Colors.black : Colors.white,
                            ),
                          ),
                        )
                      : null,
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}



