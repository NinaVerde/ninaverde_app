import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/angelina_widget.dart';
import '../state/app_state.dart';
import '../services/user_prefs_service.dart';
import '../services/translation_service.dart';
import '../theme/brand_colors.dart';

class IntroSettingsScreen extends StatefulWidget {
  const IntroSettingsScreen({super.key});

  @override
  State<IntroSettingsScreen> createState() => _IntroSettingsScreenState();
}

class _IntroSettingsScreenState extends State<IntroSettingsScreen> {
  int _step = 0;
  bool _micGranted = false;
  bool _notifGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final mic = await Permission.microphone.status;
    final notif = await Permission.notification.status;
    setState(() {
      _micGranted = mic.isGranted;
      _notifGranted = notif.isGranted;
    });
  }

  Future<void> _requestMic() async {
    final status = await Permission.microphone.request();
    setState(() => _micGranted = status.isGranted);
  }

  Future<void> _requestNotif() async {
    final status = await Permission.notification.request();
    setState(() => _notifGranted = status.isGranted);
  }

  void _next() {
    if (_step < 4) {
      setState(() => _step++);
    } else {
      UserPrefsService.setIntroSeen();
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final theme = Theme.of(context);
    final isEs = app.languageCode.value == 'es';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;

            if (isLandscape) {
              // LANDSCAPE LAYOUT: Row (Side-by-Side)
              return Row(
                children: [
                  // Left Side: Angelina
                  Expanded(
                    flex: 4, // 40% width
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                             // No 130px margin in landscape
                            SizedBox(
                              height: 280,
                              child: AngelinaWidget(
                                pose: _getAngelinaPose(),
                                speech: _getSpeech(isEs),
                                height: 280,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Right Side: Content PageView
                  Expanded(
                    flex: 6, // 60% width
                    child: PageView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        if (_step == 0) _buildLanguageStep(app, isEs, theme, isLandscape: true),
                        if (_step == 1) _buildThemeModeStep(app, isEs, theme, isLandscape: true),
                        if (_step == 2) _buildCurrencyStep(app, isEs, theme, isLandscape: true),
                        if (_step == 3) _buildPermissionsStep(isEs, theme, isLandscape: true),
                        if (_step == 4) _buildCompletionStep(isEs, theme, isLandscape: true),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              // PORTRAIT LAYOUT: Column (Stacked)
              return Column(
                children: [
                  const SizedBox(height: 130), // User requested top margin
                  SizedBox(
                    height: 280,
                    child: AngelinaWidget(
                      pose: _getAngelinaPose(),
                      speech: _getSpeech(isEs),
                      height: 280,
                    ),
                  ),
                  // Use Expanded to safely fill remaining space (prevents negative height crash)
                  Expanded(
                    child: PageView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        if (_step == 0) _buildLanguageStep(app, isEs, theme),
                        if (_step == 1) _buildThemeModeStep(app, isEs, theme),
                        if (_step == 2) _buildCurrencyStep(app, isEs, theme),
                        if (_step == 3) _buildPermissionsStep(isEs, theme),
                        if (_step == 4) _buildCompletionStep(isEs, theme),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  AngelinaPose _getAngelinaPose() {
    switch (_step) {
      case 0:
        return AngelinaPose.languageWelcome;
      case 1:
        return AngelinaPose.themeSelector;
      case 2:
        return AngelinaPose.currencyCoins;
      case 3:
        return AngelinaPose.microphoneFriendly;
      case 4:
        return AngelinaPose.conciergeHappy;
      default:
        return AngelinaPose.conciergeWaving;
    }
  }

  String _getSpeech(bool isEs) {
    switch (_step) {
      case 0:
        return isEs
            ? "¡Bienvenido! ¿En qué idioma prefieres hablar?"
            : "Welcome! Which language would you prefer?";
      case 1:
        return isEs
            ? "¿Prefieres el modo claro u oscuro?"
            : "Do you prefer light or dark mode?";
      case 2:
        return isEs
            ? "¿Qué moneda debo usar para los precios?"
            : "Which currency should I use for prices?";
      case 3:
        return isEs
            ? "Para servirte mejor, necesito acceder a tu micrófono y enviarte notificaciones."
            : "To serve you better, I need access to your microphone and to send you notifications.";
      case 4:
        return isEs
            ? "¡Todo listo! Disfruta de la experiencia Niña Verde."
            : "All set! Enjoy the Niña Verde experience.";
      default:
        return "";
    }
  }

  Widget _buildLanguageStep(AppState app, bool isEs, ThemeData theme, {bool isLandscape = false}) {
    return Padding(
      padding: EdgeInsets.all(isLandscape ? 16 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Center vertically
        children: [
          if (!isLandscape) const SizedBox(height: 20), // Narrow gap to Angelina
          Text(
            isEs ? 'Selecciona tu idioma' : 'Select your language',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: isLandscape ? 16 : 60), // Push features down
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _LanguageCard(
                  label: 'English',
                  flag: '🇨🇦',
                  selected: app.languageCode.value == 'en',
                  onSelect: () => _updateLang(app, 'en'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _LanguageCard(
                  label: 'Español',
                  flag: '🇳🇮',
                  selected: app.languageCode.value == 'es',
                  onSelect: () => _updateLang(app, 'es'),
                ),
              ),
            ],
          ),
          if (!isLandscape) const Spacer(),
          if (isLandscape) const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: nvGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(isEs ? 'Continuar' : 'Continue'),
          ),
          const SizedBox(height: 20), // Bottom padding
        ],
      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildThemeModeStep(AppState app, bool isEs, ThemeData theme, {bool isLandscape = false}) {
    return Padding(
      padding: EdgeInsets.all(isLandscape ? 16 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isLandscape) const SizedBox(height: 20),
          Text(
            isEs ? 'Elige tu tema' : 'Choose your theme',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: isLandscape ? 16 : 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _ThemeModeCard(
                  label: isEs ? 'Claro' : 'Light',
                  icon: Icons.light_mode,
                  selected: app.themeMode.value == ThemeMode.light || (app.themeMode.value == ThemeMode.system && theme.brightness == Brightness.light),
                  onSelect: () => _updateThemeMode(app, ThemeMode.light),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ThemeModeCard(
                  label: isEs ? 'Oscuro' : 'Dark',
                  icon: Icons.dark_mode,
                  selected: app.themeMode.value == ThemeMode.dark || (app.themeMode.value == ThemeMode.system && theme.brightness == Brightness.dark),
                  onSelect: () => _updateThemeMode(app, ThemeMode.dark),
                ),
              ),
            ],
          ),
          if (!isLandscape) const Spacer(),
          if (isLandscape) const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: nvGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(isEs ? 'Continuar' : 'Continue'),
          ),
          const SizedBox(height: 20), // Bottom padding
        ],
      ).animate().fadeIn().slideX(begin: 0.1, end: 0),
    );
  }

  Widget _buildCurrencyStep(AppState app, bool isEs, ThemeData theme, {bool isLandscape = false}) {
    return Padding(
      padding: EdgeInsets.all(isLandscape ? 16 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isLandscape) const SizedBox(height: 20),
          Text(
            isEs ? 'Selecciona tu moneda' : 'Select your currency',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: isLandscape ? 16 : 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _CurrencyCard(
                  label: 'USD',
                  symbol: '\$',
                  selected: app.currencyCode.value == 'USD',
                  onSelect: () => _updateCurr(app, 'USD'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CurrencyCard(
                  label: 'NIO',
                  symbol: 'C\$',
                  selected: app.currencyCode.value == 'NIO',
                  onSelect: () => _updateCurr(app, 'NIO'),
                ),
              ),
            ],
          ),
          if (!isLandscape) const Spacer(),
          if (isLandscape) const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: nvGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(isEs ? 'Continuar' : 'Continue'),
          ),
          const SizedBox(height: 20), // Bottom padding
        ],
      ).animate().fadeIn().slideX(begin: -0.1, end: 0),
    );
  }

  Widget _buildPermissionsStep(bool isEs, ThemeData theme, {bool isLandscape = false}) {
    return Padding(
      padding: EdgeInsets.all(isLandscape ? 16 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isLandscape) const SizedBox(height: 20),
          Text(
            isEs ? 'Permisos necesarios' : 'Required permissions',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: isLandscape ? 16 : 60),
          _PermissionCard(
            label: isEs ? 'Micrófono' : 'Microphone',
            icon: Icons.mic,
            granted: _micGranted,
            onPressed: _requestMic,
          ),
          const SizedBox(height: 16),
          _PermissionCard(
            label: isEs ? 'Notificaciones' : 'Notifications',
            icon: Icons.notifications,
            granted: _notifGranted,
            onPressed: _requestNotif,
          ),
          if (!isLandscape) const Spacer(),
          if (isLandscape) const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: nvGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(isEs ? 'Continuar' : 'Continue'),
          ),
          const SizedBox(height: 20), // Bottom padding
        ],
      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildCompletionStep(bool isEs, ThemeData theme, {bool isLandscape = false}) {
    return Padding(
      padding: EdgeInsets.all(isLandscape ? 16 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isLandscape) const SizedBox(height: 50),
          const Icon(Icons.check_circle, size: 80, color: nvGreen),
          const SizedBox(height: 24),
          Text(
            isEs ? '¡Estás listo!' : "You're all set!",
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            isEs 
              ? 'Tus preferencias han sido guardadas.' 
              : 'Your preferences have been saved.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          if (!isLandscape) const Spacer(),
          if (isLandscape) const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _next, // Go home
            style: ElevatedButton.styleFrom(
              backgroundColor: nvGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(isEs ? 'Ir al Inicio' : 'Go to Home'),
          ),
          const SizedBox(height: 20), // Bottom padding
        ].animate().fadeIn().scale(),
      ),
    );
  }

  Future<void> _updateLang(AppState app, String code) async {
    app.languageCode.value = code;
    await UserPrefsService.saveLanguage(code);
    setState(() {}); // Rebuild for UI language switch
  }

  Future<void> _updateThemeMode(AppState app, ThemeMode mode) async {
    app.themeMode.value = mode;
    await UserPrefsService.saveThemeMode(mode);
  }

  Future<void> _updateCurr(AppState app, String code) async {
    app.currencyCode.value = code;
    await UserPrefsService.saveCurrency(code);
    setState(() {}); // Rebuild to show selection
  }
}

class _LanguageCard extends StatelessWidget {
  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onSelect;

  const _LanguageCard({
    required this.label,
    required this.flag,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: selected ? nvGreen.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? nvGreen : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(flag, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? nvGreen : null,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 8),
              const Icon(Icons.check_circle, color: nvGreen, size: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelect;

  const _ThemeModeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: selected ? nvGreen.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? nvGreen : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: selected ? nvGreen : Colors.grey),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? nvGreen : null,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 8),
              const Icon(Icons.check_circle, color: nvGreen, size: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrencyCard extends StatelessWidget {
  final String label;
  final String symbol;
  final bool selected;
  final VoidCallback onSelect;

  const _CurrencyCard({
    required this.label,
    required this.symbol,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: selected ? nvGreen.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? nvGreen : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              symbol,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: selected ? nvGreen : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? nvGreen : null,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 8),
              const Icon(Icons.check_circle, color: nvGreen, size: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool granted;
  final VoidCallback onPressed;

  const _PermissionCard({
    required this.label,
    required this.icon,
    required this.granted,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
       shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: granted ? nvGreen : Colors.grey.withValues(alpha: 0.3)),
      ),
      color: granted ? nvGreen.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: Icon(icon, color: granted ? nvGreen : Colors.grey),
        title: Text(label),
        trailing: granted 
          ? const Icon(Icons.check, color: nvGreen)
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Allow'),
            ),
      ),
    );
  }
}
