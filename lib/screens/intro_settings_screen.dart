import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
import '../theme/brand_colors.dart';

class IntroSettingsScreen extends StatefulWidget {
  const IntroSettingsScreen({super.key});

  @override
  State<IntroSettingsScreen> createState() => _IntroSettingsScreenState();
}

class _IntroSettingsScreenState extends State<IntroSettingsScreen> {
  final _cfgCol = 'app_config';
  final _videoDoc = 'video';

  // Fallbacks
  static const String _defaultYoutube = 'https://youtu.be/ZczKlWNp5qY';
  static const String _defaultVideoAsset = 'assets/videos/Nina Verde Delicia Halada (Baila Conmingo).mp4';
  static const String _defaultLogoUrl = 'https://raw.githubusercontent.com/example/nv_logo_round.png';
  static const String _defaultLogoAsset = 'assets/images/nv_logo_round.png';

  // Video State
  String _videoSource = 'asset'; // 'youtube', 'asset', 'url'
  final _videoUrlCtrl = TextEditingController();
  final _videoAssetCtrl = TextEditingController();

  // Logo State
  String _logoSource = 'asset'; // 'network', 'asset'
  final _logoUrlCtrl = TextEditingController();
  final _logoAssetCtrl = TextEditingController();

  bool _busy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection(_cfgCol).doc(_videoDoc).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _videoSource = data['videoSource'] ?? (data['url'] != null ? 'youtube' : 'asset');
          _videoUrlCtrl.text = data['url'] ?? data['videoUrl'] ?? '';
          _videoAssetCtrl.text = data['videoAsset'] ?? '';

          _logoSource = data['logoSource'] ?? (data['logo'] != null ? 'network' : 'asset');
          _logoUrlCtrl.text = data['logo'] ?? data['logoUrl'] ?? '';
          _logoAssetCtrl.text = data['logoAsset'] ?? '';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save(bool setAsDefault) async {
    setState(() => _busy = true);
    try {
      final payload = <String, dynamic>{
        'videoSource': _videoSource,
        'videoUrl': _videoUrlCtrl.text.trim(),
        'videoAsset': _videoAssetCtrl.text.trim(),
        'logoSource': _logoSource,
        'logoUrl': _logoUrlCtrl.text.trim(),
        'logoAsset': _logoAssetCtrl.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Compatibility with old fields
      if (_videoSource == 'youtube') payload['url'] = _videoUrlCtrl.text.trim();
      if (_logoSource == 'network') payload['logo'] = _logoUrlCtrl.text.trim();

      if (setAsDefault) {
        payload['default_videoSource'] = _videoSource;
        payload['default_videoUrl'] = _videoUrlCtrl.text.trim();
        payload['default_videoAsset'] = _videoAssetCtrl.text.trim();
        payload['default_logoSource'] = _logoSource;
        payload['default_logoUrl'] = _logoUrlCtrl.text.trim();
        payload['default_logoAsset'] = _logoAssetCtrl.text.trim();
      }

      await FirebaseFirestore.instance.collection(_cfgCol).doc(_videoDoc).set(payload, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, en: 'Settings saved', es: 'Configuracion guardada'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isEs = AppState.of(context).languageCode.value == 'es';

    return Scaffold(
      appBar: NvAppBar(
        title: isEs ? 'Intro y Logo' : 'Intro & Logo',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildInfo(isEs),
          const SizedBox(height: 32),
          
          _sectionHeader(isEs ? 'Video de Introduccion' : 'Intro Video'),
          const SizedBox(height: 12),
          _sourceToggle(
            value: _videoSource,
            options: [
              {'id': 'youtube', 'label': 'YouTube'},
              {'id': 'asset', 'label': isEs ? 'Activo (Asset)' : 'Local Asset'},
              {'id': 'url', 'label': isEs ? 'URL Directa' : 'Direct MP4 URL'},
            ],
            onChanged: (v) => setState(() => _videoSource = v),
          ),
          const SizedBox(height: 16),
          if (_videoSource == 'youtube' || _videoSource == 'url')
            TextField(
              controller: _videoUrlCtrl,
              decoration: InputDecoration(
                labelText: _videoSource == 'youtube' ? 'YouTube URL' : 'Video URL (.mp4)',
                border: const OutlineInputBorder(),
              ),
            )
          else
            TextField(
              controller: _videoAssetCtrl,
              decoration: InputDecoration(
                labelText: isEs ? 'Ruta del Activo' : 'Asset Path',
                helperText: 'e.g. assets/videos/intro.mp4',
                border: const OutlineInputBorder(),
              ),
            ),

          const SizedBox(height: 40),
          _sectionHeader(isEs ? 'Configuracion del Logo' : 'Logo Configuration'),
          const SizedBox(height: 12),
          _sourceToggle(
            value: _logoSource,
            options: [
              {'id': 'network', 'label': isEs ? 'Red (URL)' : 'Network (URL)'},
              {'id': 'asset', 'label': isEs ? 'Activo (Asset)' : 'Local Asset'},
            ],
            onChanged: (v) => setState(() => _logoSource = v),
          ),
          const SizedBox(height: 16),
          if (_logoSource == 'network')
            TextField(
              controller: _logoUrlCtrl,
              decoration: InputDecoration(
                labelText: isEs ? 'URL de la Imagen' : 'Image URL',
                border: const OutlineInputBorder(),
              ),
            )
          else
            TextField(
              controller: _logoAssetCtrl,
              decoration: InputDecoration(
                labelText: isEs ? 'Ruta del Activo' : 'Asset Path',
                helperText: 'e.g. assets/images/logo.png',
                border: const OutlineInputBorder(),
              ),
            ),

          const SizedBox(height: 48),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _save(false),
                  child: Text(isEs ? 'Guardar Cambios' : 'Save Changes'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: _busy ? null : () => _save(true),
                  child: Text(isEs ? 'Hacer Predeter.' : 'Make Default'),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _videoSource = 'youtube';
                _videoUrlCtrl.text = _defaultYoutube;
                _videoAssetCtrl.text = _defaultVideoAsset;
                _logoSource = 'network';
                _logoUrlCtrl.text = _defaultLogoUrl;
                _logoAssetCtrl.text = _defaultLogoAsset;
              });
            },
            child: Text(isEs ? 'Restablecer Valores Iniciales' : 'Reset to Defaults'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: nvGreenDark),
    );
  }

  Widget _sourceToggle({
    required String value,
    required List<Map<String, String>> options,
    required ValueChanged<String> onChanged,
  }) {
    return SegmentedButton<String>(
      segments: options.map((o) => ButtonSegment<String>(
        value: o['id']!,
        label: Text(o['label']!),
      )).toList(),
      selected: {value},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }

  Widget _buildInfo(bool isEs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: nvGreenDark.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: nvGreenDark.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_applications_outlined, color: nvGreenDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEs 
                ? 'Elige si prefieres usar enlaces de YouTube/Web o archivos locales guardados directamente en la carpeta assets del app.'
                : 'Choose whether you prefer to use YouTube/Web links or local files saved directly in the app\'s assets folder.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
