import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  bool _saving = false;

  final List<_LanguageEntry> _languages = [];
  String _defaultLanguage = 'es';

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
      ..add(_LanguageEntry(code: 'es', label: 'Español', flag: '🇳🇮'))
      ..add(_LanguageEntry(code: 'en', label: 'English', flag: '🇨🇦'));
    _defaultLanguage = 'es';
  }

  void _applyFromDoc(Map<String, dynamic> data) {
    final langs = (data['languages'] as List?)?.cast<String>() ?? [];
    final labels = (data['languageLabels'] as Map?)?.cast<String, String>() ?? {};
    final flags = (data['languageFlags'] as Map?)?.cast<String, String>() ?? {};

    _languages
      ..clear()
      ..addAll(langs.map((code) {
        final label = labels[code] ?? code.toUpperCase();
        final flag = flags[code] ?? '🌐';
        return _LanguageEntry(code: code, label: label, flag: flag);
      }));

    _defaultLanguage = (data['defaultLanguage'] as String?) ?? 'es';

    if (_languages.isEmpty) {
      _languages.add(_LanguageEntry(code: 'es', label: 'Español', flag: '🇳🇮'));
    }
  }

  Future<void> _saveConfig() async {
    if (_saving) return;
    
    // Validate
    if (_languages.isEmpty) {
      _showError(tr(context, en: 'At least one language is required', es: 'Se requiere al menos un idioma'));
      return;
    }

    final codes = _languages.map((e) => e.code.text.trim()).where((c) => c.isNotEmpty).toList();
    if (!codes.contains(_defaultLanguage)) {
      _showError(tr(context, en: 'Default language must be in the list', es: 'El idioma predeterminado debe estar en la lista'));
      return;
    }

    setState(() => _saving = true);
    try {
      final languages = <String>[];
      final labels = <String, String>{};
      final flags = <String, String>{};
      
      for (final entry in _languages) {
        final code = entry.code.text.trim();
        final label = entry.label.text.trim();
        final flag = entry.flag.text.trim();
        if (code.isEmpty) continue;
        languages.add(code);
        labels[code] = label.isEmpty ? code.toUpperCase() : label;
        flags[code] = flag.isEmpty ? '🌐' : flag;
      }

      await _configRef.set({
        'languages': languages,
        'languageLabels': labels,
        'languageFlags': flags,
        'defaultLanguage': _defaultLanguage,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, en: 'Languages saved successfully!', es: '¡Idiomas guardados exitosamente!')),
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

  void _addLanguage() {
    setState(() => _languages.add(_LanguageEntry()));
  }

  void _removeLanguage(int index) {
    if (_languages.length <= 1) {
      _showError(tr(context, en: 'Cannot remove the last language', es: 'No se puede eliminar el último idioma'));
      return;
    }

    final code = _languages[index].code.text.trim();
    if (code == _defaultLanguage) {
      _showError(tr(context, en: 'Cannot remove the default language', es: 'No se puede eliminar el idioma predeterminado'));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr(context, en: 'Remove Language?', es: '¿Eliminar idioma?')),
        content: Text(tr(context, en: 'Are you sure you want to remove this language?', es: '¿Estás seguro de que quieres eliminar este idioma?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(context, en: 'Cancel', es: 'Cancelar')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _languages.removeAt(index));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr(context, en: 'Remove', es: 'Eliminar')),
          ),
        ],
      ),
    );
  }

  void _showPresetLanguages() {
    final presets = [
      {'c': 'en', 'l': 'English', 'f': '🇨🇦'},
      {'c': 'es', 'l': 'Español', 'f': '🇳🇮'},
      {'c': 'fr', 'l': 'Français', 'f': '🇫🇷'},
      {'c': 'de', 'l': 'Deutsch', 'f': '🇩🇪'},
      {'c': 'it', 'l': 'Italiano', 'f': '🇮🇹'},
      {'c': 'pt', 'l': 'Português', 'f': '🇵🇹'},
      {'c': 'ja', 'l': '日本語', 'f': '🇯🇵'},
      {'c': 'zh', 'l': '中文', 'f': '🇨🇳'},
      {'c': 'ko', 'l': '한국어', 'f': '🇰🇷'},
      {'c': 'ar', 'l': 'العربية', 'f': '🇸🇦'},
      {'c': 'ru', 'l': 'Русский', 'f': '🇷🇺'},
      {'c': 'hi', 'l': 'हिन्दी', 'f': '🇮🇳'},
    ];

    final isEs = AppState.of(context).languageCode.value == 'es';

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
                Text(
                  isEs ? 'Paquetes de Idiomas' : 'Language Packs',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
                  final label = p['l']!;
                  final flag = p['f']!;
                  final exists = _languages.any((x) => x.code.text == code);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: Text(flag, style: const TextStyle(fontSize: 28)),
                      ),
                      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Code: $code'),
                      trailing: exists
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.download, color: Colors.blue),
                      onTap: exists
                          ? null
                          : () {
                              setState(() {
                                _languages.add(_LanguageEntry(code: code, label: label, flag: flag));
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$label ${isEs ? 'agregado' : 'added'}')),
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
            final title = isEs ? 'Configuración de Idiomas' : 'Language Settings';
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
                    _buildDefaultLanguageSelector(isEs),
                    const SizedBox(height: 24),
                    _buildLanguageList(isEs),
                    const SizedBox(height: 24),
                    _buildActionButtons(isEs),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: _addLanguage,
                icon: const Icon(Icons.add),
                label: Text(isEs ? 'Agregar Idioma' : 'Add Language'),
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
              child: const Icon(Icons.language, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs ? 'Gestión de Idiomas' : 'Language Management',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEs
                        ? 'Configura los idiomas disponibles en tu aplicación'
                        : 'Configure available languages in your app',
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

  Widget _buildDefaultLanguageSelector(bool isEs) {
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
                  isEs ? 'Idioma Predeterminado' : 'Default Language',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _defaultLanguage,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
              ),
              items: _languages
                  .map((e) => e.code.text.trim())
                  .where((c) => c.isNotEmpty)
                  .map((code) {
                    final entry = _languages.firstWhere((e) => e.code.text.trim() == code);
                    return DropdownMenuItem(
                      value: code,
                      child: Row(
                        children: [
                          Text(entry.flag.text.trim().isEmpty ? '🌐' : entry.flag.text.trim(),
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Text('${entry.label.text.trim()} ($code)'),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _defaultLanguage = value);
                }
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildLanguageList(bool isEs) {
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
                isEs ? 'Idiomas Configurados' : 'Configured Languages',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${_languages.length} ${isEs ? 'idiomas' : 'languages'}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ..._languages.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isDefault = item.code.text.trim() == _defaultLanguage;

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
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: item.flag,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 32),
                          decoration: const InputDecoration(
                            hintText: '🌐',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: item.label,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Nombre' : 'Name',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: item.code,
                          decoration: InputDecoration(
                            labelText: isEs ? 'Código' : 'Code',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: isEs ? 'Eliminar' : 'Remove',
                        onPressed: () => _removeLanguage(index),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
                  if (isDefault)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 4),
                          Text(
                            isEs ? 'Idioma predeterminado' : 'Default language',
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
            onPressed: _showPresetLanguages,
            icon: const Icon(Icons.cloud_download),
            label: Text(isEs ? 'Descargar Packs' : 'Download Packs'),
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

class _LanguageEntry {
  final TextEditingController code;
  final TextEditingController label;
  final TextEditingController flag;

  _LanguageEntry({String? code, String? label, String? flag})
      : code = TextEditingController(text: code ?? ''),
        label = TextEditingController(text: label ?? ''),
        flag = TextEditingController(text: flag ?? '');

  void dispose() {
    code.dispose();
    label.dispose();
    flag.dispose();
  }
}
