import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../state/app_state.dart';
import '../services/profile_picture_service.dart';
import '../theme/brand_colors.dart';

class AngelinaProfileSettingsScreen extends StatefulWidget {
  const AngelinaProfileSettingsScreen({super.key});

  @override
  State<AngelinaProfileSettingsScreen> createState() => _AngelinaProfileSettingsScreenState();
}

class _AngelinaProfileSettingsScreenState extends State<AngelinaProfileSettingsScreen> {
  final ProfilePictureService _service = ProfilePictureService();
  final ImagePicker _picker = ImagePicker();
  bool _uploading = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _loadProfilePictures();
  }

  Future<void> _loadProfilePictures() async {
    final urls = await _service.fetchUserProfilePictures(hostId: 'angelina');
    if (mounted) {
      AppState.of(context).angelinaProfilePics.value = urls;
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );

      if (image == null) return;

      final file = File(image.path);
      
      // Validate
      final error = ProfilePictureService.validateImage(file);
      if (error != null) {
        setState(() => _uploadError = error);
        return;
      }

      // Check limit (20 pictures max)
      if (!mounted) return;
      final app = AppState.of(context);
      if (app.angelinaProfilePics.value.length >= 20) {
        if (!mounted) return; // Added safety check
        // ignore: use_build_context_synchronously
        setState(() => _uploadError = tr(context, en: 'Maximum 20 pictures allowed', es: 'Máximo 20 imágenes permitidas'));
        return;
      }

      setState(() {
        _uploading = true;
        _uploadError = null;
      });

      // Upload
      final url = await _service.uploadProfilePicture(file, hostId: 'angelina');
      
      // Add to list
      final updated = List<String>.from(app.angelinaProfilePics.value)..add(url);
      app.angelinaProfilePics.value = updated;

      // If it's the first picture, auto-select it
      if (updated.length == 1) {
        app.selectedProfilePic.value = url;
      }

      setState(() => _uploading = false);
    } catch (e) {
      setState(() {
        _uploading = false;
        _uploadError = '${tr(context, en: 'Upload failed: ', es: 'Error de carga: ')}$e';
      });
    }
  }

  Future<void> _deleteImage(String url) async {
    final app = AppState.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, en: 'Delete Picture?', es: '¿Eliminar imagen?')),
        content: Text(tr(context, en: 'This action cannot be undone.', es: 'Esta acción no se puede deshacer.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, en: 'Cancel', es: 'Cancelar')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, en: 'Delete', es: 'Eliminar'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Delete from storage
    await _service.deleteProfilePicture(url);

    // Remove from list
    final updated = List<String>.from(app.angelinaProfilePics.value)..remove(url);
    app.angelinaProfilePics.value = updated;

    // If deleted was selected, pick new selection
    if (app.selectedProfilePic.value == url) {
      app.selectedProfilePic.value = updated.isNotEmpty ? updated.first : null;
    }
  }

  String _formatInterval(int seconds) {
    if (seconds < 60) return '$seconds ${tr(context, en: 'seconds', es: 'segundos')}';
    if (seconds < 3600) return '${(seconds / 60).round()} ${tr(context, en: 'minutes', es: 'minutos')}';
    return '${(seconds / 3600).round()} ${tr(context, en: 'hours', es: 'horas')}';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, en: 'Angelina Profile Pictures', es: 'Fotos de Perfil de Angelina')),
        backgroundColor: nvGreenDark,
      ),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: app.angelinaProfilePics,
        builder: (context, pics, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Picture Preview
                _buildCurrentPictureSection(app, scheme),
                const SizedBox(height: 24),

                // Upload Button
                _buildUploadSection(pics, theme),
                const SizedBox(height: 24),

                // Gallery Grid
                if (pics.isNotEmpty) ...[
                  _buildGallerySection(app, pics, scheme),
                  const SizedBox(height: 24),
                ],

                // Randomization Controls
                _buildRandomizationSection(app, pics, theme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentPictureSection(AppState app, ColorScheme scheme) {
    return ValueListenableBuilder<String?>(
      valueListenable: app.selectedProfilePic,
      builder: (context, selected, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, en: 'Current Profile Picture', es: 'Foto de Perfil Actual'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: nvAccentOrange, width: 3),
                    ),
                    child: ClipOval(
                      child: selected != null
                          ? CachedNetworkImage(
                              imageUrl: selected,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (_, __, ___) => const Icon(Icons.error),
                            )
                          : Image.asset(
                              'assets/images/angelina/angelina_bubble_avatar.jpg',
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    selected != null 
                        ? tr(context, en: 'Custom Picture', es: 'Foto Personalizada') 
                        : tr(context, en: 'Default Avatar', es: 'Avatar Predeterminado'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadSection(List<String> pics, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr(context, en: 'Upload New Picture', es: 'Subir Nueva Foto'),
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${pics.length}/20',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_uploadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _uploadError!,
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _uploading || pics.length >= 20 ? null : _pickAndUploadImage,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo),
              label: Text(_uploading 
                  ? tr(context, en: 'Uploading...', es: 'Subiendo...') 
                  : tr(context, en: 'Select from Gallery', es: 'Seleccionar de Galería')),
              style: ElevatedButton.styleFrom(
                backgroundColor: nvGreenDark,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(context, en: 'Max 5MB • JPG, PNG, or WebP • 200x200 to 2000x2000 px', es: 'Max 5MB • JPG, PNG, o WebP • 200x200 a 2000x2000 px'),
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGallerySection(AppState app, List<String> pics, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '${tr(context, en: 'Select Persona Avatar', es: 'Seleccionar Avatar')} (${pics.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 320, // Taller for cards
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: pics.length,
            itemBuilder: (context, index) {
              final url = pics[index];
              return ValueListenableBuilder<String?>(
                valueListenable: app.selectedProfilePic,
                builder: (context, selected, _) {
                  final isSelected = selected == url;
                  return _PersonaCard(
                    url: url,
                    isSelected: isSelected,
                    onTap: () => app.selectedProfilePic.value = url,
                    onDelete: () => _deleteImage(url),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            tr(context, en: 'Swipe to browse • Tap to select • Long-press to delete', es: 'Desliza para ver • Toca para seleccionar • Mantén para borrar'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildRandomizationSection(AppState app, List<String> pics, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, en: 'Randomization', es: 'Aleatorización'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: app.profilePicRandomize,
              builder: (context, randomize, _) {
                return SwitchListTile(
                  title: Text(tr(context, en: 'Randomize Profile Picture', es: 'Aleatorizar Foto de Perfil')),
                  subtitle: pics.length < 2
                      ? Text(tr(context, en: 'Upload at least 2 pictures to enable', es: 'Sube al menos 2 fotos para habilitar'))
                      : Text(randomize 
                          ? tr(context, en: 'Pictures will cycle automatically', es: 'Las fotos rotarán automáticamente') 
                          : tr(context, en: 'Show selected picture only', es: 'Mostrar solo foto seleccionada')),
                  value: randomize,
                  onChanged: pics.length < 2
                      ? null
                      : (value) => app.profilePicRandomize.value = value,
                  // ignore: deprecated_member_use
                  activeColor: nvGreenDark,
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: app.profilePicRandomize,
              builder: (context, randomize, _) {
                if (!randomize) return const SizedBox.shrink();
                
                return ValueListenableBuilder<int>(
                  valueListenable: app.profilePicInterval,
                  builder: (context, interval, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          '${tr(context, en: 'Change Interval: ', es: 'Intervalo de Cambio: ')}${_formatInterval(interval)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Slider(
                          value: interval.toDouble(),
                          min: 30, // 30 seconds
                          max: 86400, // 24 hours
                          divisions: 20,
                          label: _formatInterval(interval),
                          onChanged: (value) {
                            app.profilePicInterval.value = value.round();
                          },
                          activeColor: nvGreenDark,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonaCard extends StatelessWidget {
  final String url;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PersonaCard({
    required this.url,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Elegant Persona Card
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 220,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B5E20) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected 
             ? Border.all(color: Colors.greenAccent, width: 2)
             : Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
             if (isSelected) 
               BoxShadow(color: Colors.greenAccent.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)
             else 
               const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[200]),
                  errorWidget: (_, __, ___) => const Icon(Icons.error),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.green[900] : Colors.white,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isSelected ? 'ACTIVE PERSONA' : 'AVAILABLE',
                      style: TextStyle(
                        color: isSelected ? Colors.greenAccent : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 4),
                       const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
