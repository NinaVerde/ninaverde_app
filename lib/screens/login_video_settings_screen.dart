import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // for kIsWeb

import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';

class LoginVideoSettingsScreen extends StatefulWidget {
  const LoginVideoSettingsScreen({super.key});

  @override
  State<LoginVideoSettingsScreen> createState() => _LoginVideoSettingsScreenState();
}

class _LoginVideoSettingsScreenState extends State<LoginVideoSettingsScreen> {
  // Config state
  String _videoSource = 'asset'; // asset, network
  final TextEditingController _videoUrlCtrl = TextEditingController();
  final TextEditingController _videoAssetCtrl = TextEditingController();

  String _logoSource = 'asset'; // asset, network
  final TextEditingController _logoUrlCtrl = TextEditingController();
  final TextEditingController _logoAssetCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _videoUrlCtrl.dispose();
    _videoAssetCtrl.dispose();
    _logoUrlCtrl.dispose();
    _logoAssetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('video').get();
      final data = doc.data() ?? {};

      _videoSource = data['videoSource'] ?? 'asset';
      _videoUrlCtrl.text = data['videoUrl'] ?? data['url'] ?? '';
      _videoAssetCtrl.text = data['videoAsset'] ?? 'assets/videos/nina_verde_intro.mp4';

      _logoSource = data['logoSource'] ?? 'asset';
      _logoUrlCtrl.text = data['logoUrl'] ?? data['logo'] ?? '';
      _logoAssetCtrl.text = data['logoAsset'] ?? 'assets/images/app_icon_foreground.png';
    } catch (e) {
      debugPrint('Error loading video config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('app_config').doc('video').set({
        'videoSource': _videoSource,
        'videoUrl': _videoUrlCtrl.text.trim(),
        'videoAsset': _videoAssetCtrl.text.trim(),
        'logoSource': _logoSource,
        'logoUrl': _logoUrlCtrl.text.trim(),
        'logoAsset': _logoAssetCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(tr(context, en: 'Settings saved', es: 'Configuración guardada'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, en: 'Error saving: $e', es: 'Error al guardar: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---- Upload Helpers ----

  Future<void> _uploadVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
        });

        Uint8List? fileBytes;
        String fileName = 'intro_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        
        if (kIsWeb) {
          fileBytes = result.files.first.bytes;
        } else {
          final path = result.files.single.path;
          if (path != null) {
            fileBytes = await File(path).readAsBytes();
          }
        }

        if (fileBytes == null) throw Exception("No file data");

        final ref = FirebaseStorage.instance.ref().child('config/videos/$fileName');
        final task = ref.putData(fileBytes, SettableMetadata(contentType: 'video/mp4'));

        task.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        });

        await task;
        final downloadUrl = await ref.getDownloadURL();

        setState(() {
          _videoSource = 'network';
          _videoUrlCtrl.text = downloadUrl;
          _isUploading = false;
        });
        
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(tr(context, en: 'Video uploaded!', es: '¡Video subido!'))),
           );
         }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadLogo() async {
    try {
      // Use ImagePicker for images as it's often smoother on mobile
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
         setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
        });

        final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.png'; // Assume png/jpg
        final ref = FirebaseStorage.instance.ref().child('config/logos/$fileName');
        
        final data = await image.readAsBytes();
        final task = ref.putData(data, SettableMetadata(contentType: image.mimeType ?? 'image/png'));

        task.snapshotEvents.listen((TaskSnapshot snapshot) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        });

        await task;
        final downloadUrl = await ref.getDownloadURL();

        setState(() {
          _logoSource = 'network';
          _logoUrlCtrl.text = downloadUrl;
          _isUploading = false;
        });
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(tr(context, en: 'Logo uploaded!', es: '¡Logo subido!'))),
           );
         }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Fix: Listen to language changes
    return ValueListenableBuilder<String>(
      valueListenable: AppState.of(context).languageCode,
      builder: (context, langCode, _) {
        final isEs = langCode == 'es';

        return Stack(
          children: [
            DefaultTabController(
              length: 2,
              child: Scaffold(
                appBar: NvAppBar(
                  tickerVisible: AppState.of(context).showTicker.value,
                  title: tr(context, en: 'Login Screen Settings', es: 'Configuración Pantalla de Inicio'),
                  showBack: true,
                ),
                body: TabBarView(
                  children: [
                    _buildVideoTab(isEs),
                    _buildLogoTab(isEs),
                  ],
                ),
                bottomNavigationBar: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: Text(tr(context, en: 'Cancel', es: 'Cancelar')),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving ? null : _saveConfig,
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: _isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : Text(tr(context, en: 'Save', es: 'Guardar')),
                        ),
                      ),
                    ],
                  ),
                ),
                // TabBar needs to be somewhere. In previous code it was in Column below AppBar.
                // Let's put it in the AppBar bottom or keep the Column structure.
                // Reverting to Column structure for TabBar, but moving buttons to bottomNavigationBar.
              ),
            ),
            
            // Upload Overlay
            if (_isUploading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(32),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text('${(_uploadProgress * 100).toStringAsFixed(0)}%'),
                          const SizedBox(height: 8),
                          Text(tr(context, en: 'Uploading...', es: 'Subiendo...')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }
    );
  }
  
  // Re-implement build to include TabBar properly since I removed the Column above
  // Actually, NvAppBar doesn't support bottom. 
  // Let's use the Column structure again inside the Scaffold body.

  Widget _buildScaffoldContent(BuildContext context, bool isEs) {
      return Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: tr(context, en: 'Intro Video', es: 'Video Intro')),
              Tab(text: tr(context, en: 'Logo Image', es: 'Imagen Logo')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildVideoTab(isEs),
                _buildLogoTab(isEs),
              ],
            ),
          ),
        ],
      );
  }

  Widget _buildVideoTab(bool isEs) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _SectionHeader(
          title: tr(context, en: 'Video Source', es: 'Fuente del Video'),
          subtitle: tr(context, en: 'Choose how the intro video is loaded.', es: 'Elige cómo se carga el video de intro.'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _SourceChip(
                label: tr(context, en: 'Asset', es: 'Local'),
                icon: Icons.folder,
                selected: _videoSource == 'asset',
                onTap: () => setState(() => _videoSource = 'asset'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SourceChip(
                label: tr(context, en: 'Network', es: 'Nube'),
                icon: Icons.cloud_upload,
                selected: _videoSource == 'network',
                onTap: () => setState(() => _videoSource = 'network'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (_videoSource == 'asset') ...[
          TextField(
            controller: _videoAssetCtrl,
            decoration: InputDecoration(
              labelText: tr(context, en: 'Asset Path', es: 'Ruta del Asset'),
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              helperText: 'e.g. assets/videos/nina_verde_intro.mp4',
            ),
          ),
        ] else ...[
          TextField(
            controller: _videoUrlCtrl,
            decoration: InputDecoration(
              labelText: tr(context, en: 'Video URL', es: 'URL del Video'),
              prefixIcon: const Icon(Icons.public),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              helperText: tr(context, en: 'Direct MP4 URL or YouTube Link', es: 'URL directa de MP4 o enlace de YouTube'),
            ),
          ),
          const SizedBox(height: 16),
          _uploadButton(isEs, video: true),
        ],
        const SizedBox(height: 32),
        _buildPreviewFrame(
          context,
          title: tr(context, en: 'Video Preview', es: 'Vista Previa de Video'),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_fill, size: 48, color: Colors.white54),
                  const SizedBox(height: 12),
                  Text(
                    _videoSource == 'asset' ? _videoAssetCtrl.text : _videoUrlCtrl.text,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoTab(bool isEs) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _SectionHeader(
          title: tr(context, en: 'Logo Source', es: 'Fuente del Logo'),
          subtitle: tr(context, en: 'Select the branding logo for the login screen.', es: 'Selecciona el logo de marca para el inicio.'),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _SourceChip(
                label: tr(context, en: 'Asset', es: 'Local'),
                icon: Icons.image_search,
                selected: _logoSource == 'asset',
                onTap: () => setState(() => _logoSource = 'asset'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _SourceChip(
                label: tr(context, en: 'Network', es: 'Nube'),
                icon: Icons.cloud_sync,
                selected: _logoSource == 'network',
                onTap: () => setState(() => _logoSource = 'network'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (_logoSource == 'asset') ...[
          TextField(
            controller: _logoAssetCtrl,
            decoration: InputDecoration(
              labelText: tr(context, en: 'Asset Path', es: 'Ruta del Asset'),
              prefixIcon: const Icon(Icons.file_present),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              helperText: 'e.g. assets/images/app_icon_foreground.png',
            ),
          ),
        ] else ...[
          TextField(
            controller: _logoUrlCtrl,
            decoration: InputDecoration(
              labelText: tr(context, en: 'Logo URL', es: 'URL del Logo'),
              prefixIcon: const Icon(Icons.image),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              helperText: 'https://...',
            ),
          ),
          const SizedBox(height: 16),
          _uploadButton(isEs, video: false),
        ],
        const SizedBox(height: 32),
        _buildPreviewFrame(
          context,
          title: tr(context, en: 'Logo Preview', es: 'Vista Previa del Logo'),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            child: Center(
              child: _logoSource == 'asset'
                  ? Image.asset(_logoAssetCtrl.text, height: 120, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48, color: Colors.grey))
                  : _logoUrlCtrl.text.isNotEmpty
                      ? Image.network(_logoUrlCtrl.text, height: 120, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48, color: Colors.grey))
                      : const Icon(Icons.image, size: 48, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewFrame(BuildContext context, {required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
  
  Widget _uploadButton(bool isEs, {required bool video}) {
      return FilledButton.icon(
        onPressed: video ? _uploadVideo : _uploadLogo,
        icon: Icon(video ? Icons.video_file : Icons.add_photo_alternate),
        label: Text(video 
          ? tr(context, en: 'Upload New Video', es: 'Subir Nuevo Video')
          : tr(context, en: 'Upload New Logo', es: 'Subir Nuevo Logo')),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SourceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.disabledColor;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }
}
