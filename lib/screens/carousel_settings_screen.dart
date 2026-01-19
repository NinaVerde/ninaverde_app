import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../services/user_prefs_service.dart';
import '../widgets/nv_widgets.dart';
import '../config/product_animations_map.dart'; // For category order

class CarouselSettingsScreen extends StatefulWidget {
  const CarouselSettingsScreen({super.key});

  @override
  State<CarouselSettingsScreen> createState() => _CarouselSettingsScreenState();
}

class _CarouselSettingsScreenState extends State<CarouselSettingsScreen> {
  bool _saving = false;

  // Local state for editing
  late double _speed;
  late bool _autoPlay;
  late CarouselMode _globalMode;
  late Map<String, CategoryConfig> _catConfigs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppState.of(context);
    _speed = app.carouselSpeed.value;
    _autoPlay = app.carouselAutoPlay.value;
    _globalMode = app.carouselGlobalMode.value;
    _catConfigs = Map.from(app.categoryConfigs.value);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    
    // 1. Update Global State immediately
    final app = AppState.of(context);
    app.carouselSpeed.value = _speed;
    app.carouselAutoPlay.value = _autoPlay;
    app.carouselGlobalMode.value = _globalMode;
    app.categoryConfigs.value = _catConfigs;

    // 2. Persist
    final configMap = {
      'speed': _speed,
      'autoPlay': _autoPlay,
      'globalMode': _globalMode.index,
      'categories': _catConfigs.map((k, v) => MapEntry(k, v.toJson())),
    };

    try {
      await UserPrefsService.saveCarouselConfig(configMap);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carousel settings saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _editCategory(String category) {
    // Current config or default
    final currentCfg = _catConfigs[category] ?? const CategoryConfig();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit: $category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Override Mode for this category:'),
            const SizedBox(height: 10),
            _ModeRadio(
              label: 'Default (Use Global)',
              // We don't have a "default" enum value, so we'll use a specific way to represent "no override"
              // Actually, looking at AppState, I defined `CarouselMode { still, animated }`.
              // I should probably add a `default` to the enum OR use null.
              // Let's check AppState...
              // I defined:
              // enum CarouselMode { still, animated, // 'default' implies falling back... wait, I commented it out/didn't add it?
              // checking logic...
              // In AppState step I wrote:
              // enum CarouselMode { still, animated, ... }
              // AND in CategoryConfig I default to still?
              // "CategoryConfig({ this.modeOverride = CarouselMode.still })"
              // Ah, I need to know if I should respect global.
              // Let's assume for now the user wants explicit control per category or global everywhere.
              // But logically "Default" is best.
              // I'll stick to what I have: existing enum.
              // Wait, I can't really do "default" if the enum only has 2 values.
              // Let's assume the user will pick Still or Animated explicitly for override.
              // BUT, to allow "Global" to control it, I need a way to say "No Override".
              // `CategoryConfig` stores an override.
              // Maybe I should add `useGlobal` bool to CategoryConfig?
              // Or make modeOverride nullable?
              // The `CategoryConfig` I wrote has `modeOverride` as non-nullable with default `still`.
              // That might be a bug in my plan.
              // Let's check `_catConfigs`. If key is missing, it uses global.
              // So "Default" means removing the key from `_catConfigs`.
              value: null, 
              groupValue: _catConfigs.containsKey(category) ? currentCfg.modeOverride : null, 
              onChanged: (_) {
                setState(() => _catConfigs.remove(category));
                Navigator.pop(ctx);
              },
            ),
            _ModeRadio(
              label: 'Force Still',
              value: CarouselMode.still,
              groupValue: _catConfigs.containsKey(category) ? currentCfg.modeOverride : null,
              onChanged: (val) {
                setState(() => _catConfigs[category] = CategoryConfig(modeOverride: val!));
                Navigator.pop(ctx);
              },
            ),
            _ModeRadio(
              label: 'Force Animated',
              value: CarouselMode.animated,
              groupValue: _catConfigs.containsKey(category) ? currentCfg.modeOverride : null,
              onChanged: (val) {
                setState(() => _catConfigs[category] = CategoryConfig(modeOverride: val!));
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NvAppBar(
        title: 'Hero Carousel Settings',
        showBack: true,
        extraActions: [
           IconButton(
             icon: const Icon(Icons.save),
             onPressed: _saving ? null : _save,
           ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader('Global Settings'),
          SwitchListTile(
            title: const Text('Auto-Play Rotation'),
            subtitle: const Text('Carousel spins automatically when idle'),
            value: _autoPlay,
            onChanged: (v) => setState(() => _autoPlay = v),
          ),
          ListTile(
            title: const Text('Rotation Duration'),
            subtitle: Text('${_speed.toStringAsFixed(1)} seconds per full rotation'),
            trailing: Text('${_speed.toInt()}s', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Slider(
            value: _speed.clamp(2.0, 120.0), // Ensure existing value fits new range
            min: 2,
            max: 120,
            divisions: 118,
            label: '${_speed.toInt()}s',
            onChanged: (v) => setState(() => _speed = v),
          ),
          const SizedBox(height: 10),
          const Text('Global Display Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: RadioListTile<CarouselMode>(
                  title: const Text('Still Images'),
                  value: CarouselMode.still,
                  // ignore: deprecated_member_use
                  groupValue: _globalMode,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setState(() => _globalMode = v!),
                ),
              ),
              Expanded(
                child: RadioListTile<CarouselMode>(
                  title: const Text('Animated 3D'),
                  value: CarouselMode.animated,
                  // ignore: deprecated_member_use
                  groupValue: _globalMode,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setState(() => _globalMode = v!),
                ),
              ),
            ],
          ),
          const Divider(height: 40),
          const _SectionHeader('Category Overrides'),
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Click a category to force it to be Still or Animated, overriding the global setting.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          ...HeroCategoryConfig.order.map((cat) {
            final hasOverride = _catConfigs.containsKey(cat);
            final overrideMode = _catConfigs[cat]?.modeOverride;
            
            String statusText = 'Default (Global)';
            Color statusColor = Colors.grey;
            
            if (hasOverride) {
              if (overrideMode == CarouselMode.still) {
                statusText = 'Force STILL';
                statusColor = Colors.orange;
              } else {
                statusText = 'Force ANIMATED';
                statusColor = Colors.green;
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.edit, size: 20),
                onTap: () => _editCategory(cat),
              ),
            );
          }),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
    );
  }
}

class _ModeRadio extends StatelessWidget {
  final String label;
  final CarouselMode? value;
  final CarouselMode? groupValue;
  final ValueChanged<CarouselMode?> onChanged;

  const _ModeRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<CarouselMode?>(
      title: Text(label),
      value: value,
      // ignore: deprecated_member_use
      groupValue: groupValue,
      // ignore: deprecated_member_use
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}
