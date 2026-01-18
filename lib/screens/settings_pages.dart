// lib/screens/settings_pages.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';
// import '../widgets/radio_group.dart'; // Unused
import '../services/config_service.dart';
import '../models/app_config_model.dart';

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
      // Fetch current to keep other fields (like currencies) intact
      final current = await ConfigService.getLocalizationConfig();
      final updated = current.copyWith(defaultLanguage: newDefault);
      await ConfigService.saveLocalizationConfig(updated);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, en: 'Global default saved.', es: 'Predeterminado global guardado.'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving config'), backgroundColor: Colors.red),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final isManager = app.isManager.value;

    if (!isManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(child: Text('Admin permissions required.')),
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
          body: Column(
            children: [
               Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  tr(context, 
                    en: 'Select the default language for new users.',
                    es: 'Seleccione el idioma predeterminado para nuevos usuarios.'
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
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
                            
                            return ListView(
                              children: options.map((lang) {
                                final label = labels[lang] ?? lang.toUpperCase();
                                final isDefault = config.defaultLanguage == lang;
                                return RadioListTile<String>(
                                  value: lang,
                                  groupValue: config.defaultLanguage,
                                  title: Text(label),
                                  secondary: isDefault ? const Icon(Icons.star, color: Colors.amber) : null,
                                  onChanged: _saving ? null : (val) {
                                    if (val != null) _saveDefaults(app, val);
                                  },
                                );
                              }).toList(),
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
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving config'), backgroundColor: Colors.red),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final isManager = app.isManager.value;

    if (!isManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(child: Text('Admin permissions required.')),
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
          body: Column(
            children: [
               Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  tr(context, 
                    en: 'Select the default currency for new users.',
                    es: 'Seleccione la moneda predeterminada para nuevos usuarios.'
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
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
                            
                            return ListView(
                              children: options.map((code) {
                                final cfg = configs[code];
                                final label = cfg == null
                                    ? code
                                    : '${cfg.code} - ${cfg.symbol}';
                                final isDefault = config.defaultCurrency == code;
                                
                                return RadioListTile<String>(
                                  value: code,
                                  groupValue: config.defaultCurrency,
                                  title: Text(label),
                                  secondary: isDefault ? const Icon(Icons.star, color: Colors.amber) : null,
                                  onChanged: _saving ? null : (val) {
                                    if (val != null) _saveDefaults(app, val);
                                  },
                                );
                              }).toList(),
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

class MessagePair {
  String en;
  String es;
  MessagePair({this.en = '', this.es = ''});
}

class _TickerSettingsPageState extends State<TickerSettingsPage>
    with TickerProviderStateMixin {
  late bool _showLocal;
  late double _speedLocal;
  late Color _laneLightLocal, _laneDarkLocal, _railLightLocal, _railDarkLocal;
  late Color _textLightLocal, _textDarkLocal;
  late bool _editingSpanish;
  late List<MessagePair> _pairs;
  late List<int> _ids;
  int _nextId = 0;

  static const Map<String, String> _enToEs = {
    'hi': 'hola',
    'hello': 'hola',
    'hi naturally, welcome to nicaragua niña verde!': 'hola, naturalmente, ¡bienvenido a nicaragua niña verde!',
    'earn nv coins.': 'gana monedas nv.',
    'get exclusive offers.': 'obten ofertas exclusivas.',
    'login to collect nv coins.': 'inicia sesion para ganar monedas nv.',
    'enjoy free services.': 'disfruta servicios gratis.',
    'tune into the best entertainment.': 'sintoniza el mejor entretenimiento.',
    'engage the community.': 'participa en la comunidad.',
    'catch the _vybz!_': 'atrapa el _vybz!_',
    'come for the food, stay for the _vybz!_':
        'ven por la comida, quedate por el _vybz!_',
  };

  String _translateEnToEs(String input) {
    final k = input.trim().toLowerCase();
    return _enToEs[k] ?? input;
  }

  String _translateEsToEn(String input) {
    final k = input.trim().toLowerCase();
    final found = _enToEs.entries.firstWhere(
      (e) => e.value == k,
      orElse: () => const MapEntry('', ''),
    );
    if (found.key.isNotEmpty) return found.key;
    return input;
  }

  bool _looksSpanish(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (RegExp(r'[¡¿]').hasMatch(t)) return true;
    const hits = [' el ', ' la ', ' los ', ' las ', ' de ', ' para ', ' sesion', ' ofertas', ' recompensas', ' gratis', ' sintoniza', ' participa', ' bienvenido', ' naturalmente', ' quedate'];
    return hits.any((w) => t.contains(w));
  }

  bool _looksEnglish(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (_looksSpanish(t)) return false;
    return RegExp(r'[a-z]').hasMatch(t);
  }

  void _autoFixMix() {
    setState(() {
      for (final p in _pairs) {
        if (_looksEnglish(p.es) && _looksSpanish(p.en)) {
          final tmp = p.es; p.es = p.en; p.en = tmp;
        }
      }
    });
  }

  void _fillMissingTranslations() {
    setState(() {
      for (final p in _pairs) {
        if (p.es.trim().isEmpty && p.en.trim().isNotEmpty) p.es = _translateEnToEs(p.en);
        if (p.en.trim().isEmpty && p.es.trim().isNotEmpty) p.en = _translateEsToEn(p.es);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppState.of(context);
    _showLocal = app.showTicker.value;
    _speedLocal = app.tickerSpeedPx.value;
    _laneLightLocal = app.laneLight.value;
    _laneDarkLocal = app.laneDark.value;
    _railLightLocal = app.railLight.value;
    _railDarkLocal = app.railDark.value;
    _textLightLocal = app.textLight.value;
    _textDarkLocal = app.textDark.value;
    _editingSpanish = app.languageCode.value == 'es';

    final es = List<String>.from(app.tickerEs.value);
    final en = List<String>.from(app.tickerEn.value);
    final n = (es.length > en.length) ? es.length : en.length;
    while (es.length < n) {
      es.add('');
    }
    while (en.length < n) {
      en.add('');
    }
    _pairs = List.generate(n, (i) => MessagePair(en: en[i], es: es[i]));
    _autoFixMix();
    _fillMissingTranslations();
    _ids = List<int>.generate(_pairs.length, (i) => i);
    _nextId = _pairs.length;
  }

  Future<void> _saveAndExit() async {
    final app = AppState.of(context);
    app.showTicker.value = _showLocal;
    app.tickerEs.value = _pairs.map((p) => p.es).toList();
    app.tickerEn.value = _pairs.map((p) => p.en).toList();
    app.tickerSpeedPx.value = _speedLocal;
    app.laneLight.value = _laneLightLocal;
    app.laneDark.value = _laneDarkLocal;
    app.railLight.value = _railLightLocal;
    app.railDark.value = _railDarkLocal;
    app.textLight.value = _textLightLocal;
    app.textDark.value = _textDarkLocal;

    try {
      await ConfigService.saveTickerConfig(TickerConfig(
        show: _showLocal,
        messagesEs: app.tickerEs.value,
        messagesEn: app.tickerEn.value,
        speedPx: _speedLocal,
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red.shade700, content: Text(tr(context, en: 'Save failed: $e', es: 'Error al guardar: $e'))));
    }
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
        content: Text(tr(context, en: 'This will delete the message in both languages.', es: 'Esto eliminara el mensaje en ambos idiomas.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr(context, en: 'No', es: 'No'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(context, en: 'Yes', es: 'Si'))),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        if (index >= 0 && index < _pairs.length) _pairs.removeAt(index);
        if (index >= 0 && index < _ids.length) _ids.removeAt(index);
      });
    }
  }

  void _editMsg({required bool spanish, required int index, required String value}) {
    setState(() {
      if (spanish) {
        _pairs[index].es = value;
        if (value.trim().isNotEmpty) _pairs[index].en = _translateEsToEn(value);
      } else {
        _pairs[index].en = value;
        if (value.trim().isNotEmpty) _pairs[index].es = _translateEnToEs(value);
      }
    });
  }

  void _addMsg() {
    setState(() {
      _pairs.add(MessagePair());
      _ids.add(_nextId++);
    });
  }

  void _reorderBoth(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final id = _ids.removeAt(oldIndex);
      _ids.insert(newIndex, id);
      final pair = _pairs.removeAt(oldIndex);
      _pairs.insert(newIndex, pair);
    });
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
    final app = AppState.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (context, code, _) {
        final isEsUI = code == 'es';
        return Scaffold(
          appBar: NvAppBar(title: tr(context, en: 'Ticker Settings', es: 'Ajustes del Ticker'), showBack: true),
          body: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(tabs: [Tab(text: tr(context, en: 'Messages', es: 'Mensajes')), Tab(text: tr(context, en: 'Appearance', es: 'Apariencia'))]),
                Expanded(
                  child: TabBarView(
                    children: [
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          SwitchListTile(title: Text(tr(context, en: 'Show ticker', es: 'Mostrar ticker')), value: _showLocal, onChanged: (v) => setState(() => _showLocal = v)),
                          const SizedBox(height: 8),
                          Text(tr(context, en: 'Speed', es: 'Velocidad'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          Slider(value: _speedLocal, min: 40, max: 160, divisions: 24, label: '${_speedLocal.toStringAsFixed(0)} px/s', onChanged: (v) => setState(() => _speedLocal = v)),
                          const SizedBox(height: 12),
                          _messagesEditor(isEsUI),
                          const SizedBox(height: 80),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(tr(context, en: 'Colors — Light Mode', es: 'Colores — Modo Claro'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          _colorRow(label: tr(context, en: 'Lane', es: 'Pista'), value: _laneLightLocal, onChanged: (c) => setState(() => _laneLightLocal = c)),
                          _colorRow(label: tr(context, en: 'Rails', es: 'Rieles'), value: _railLightLocal, onChanged: (c) => setState(() => _railLightLocal = c)),
                          _colorRow(label: tr(context, en: 'Text', es: 'Texto'), value: _textLightLocal, onChanged: (c) => setState(() => _textLightLocal = c)),
                          const SizedBox(height: 20),
                          Text(tr(context, en: 'Colors — Dark Mode', es: 'Colores — Modo Oscuro'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          _colorRow(label: tr(context, en: 'Lane', es: 'Pista'), value: _laneDarkLocal, onChanged: (c) => setState(() => _laneDarkLocal = c)),
                          _colorRow(label: tr(context, en: 'Rails', es: 'Rieles'), value: _railDarkLocal, onChanged: (c) => setState(() => _railDarkLocal = c)),
                          _colorRow(label: tr(context, en: 'Text', es: 'Texto'), value: _textDarkLocal, onChanged: (c) => setState(() => _textDarkLocal = c)),
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
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(tr(context, en: 'Cancel', es: 'Cancelar')))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: _saveAndExit, child: Text(tr(context, en: 'Save', es: 'Guardar')))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _messagesEditor(bool isEsUI) {
    return Column(
      children: [
        Row(
          children: [
            ChoiceChip(label: const Text('ES'), selected: _editingSpanish, onSelected: (s) => setState(() => _editingSpanish = true)),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('EN'), selected: !_editingSpanish, onSelected: (s) => setState(() => _editingSpanish = false)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.translate), onPressed: _fillMissingTranslations, tooltip: tr(context, en: 'Auto-translate', es: 'Auto-traducir')),
          ],
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _ids.length,
          onReorder: _reorderBoth,
          itemBuilder: (ctx, i) => ListTile(
            key: ValueKey(_ids[i]),
            leading: const Icon(Icons.drag_handle),
            title: TextFormField(
              initialValue: _editingSpanish ? _pairs[i].es : _pairs[i].en,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              onChanged: (v) => _editMsg(spanish: _editingSpanish, index: i, value: v),
            ),
            trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _confirmRemove(i)),
          ),
        ),
        TextButton.icon(onPressed: _addMsg, icon: const Icon(Icons.add), label: Text(tr(context, en: 'Add message', es: 'Agregar mensaje'))),
      ],
    );
  }
}
