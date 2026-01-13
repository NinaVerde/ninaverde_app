// lib/screens/login_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    as auth_platform;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:video_player/video_player.dart';

import '../main.dart'; // AppState + NvAppBar
import '../services/user_service.dart'; // Firestore upsert on sign-in
import '../theme/brand_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool obscured = true;
  bool busy = false;

  // --- Video & logo config (Firestore: app_config/video) ----
  static const _cfgCol = 'app_config';
  static const _videoDoc = 'video';

  // App-level hardcoded fallbacks for defaults
  static const String _appDefaultYouTubeUrl = 'https://youtu.be/ZczKlWNp5qY';
  static const String _appDefaultLogoUrl =
      'https://raw.githubusercontent.com/example/nv_logo_round.png';

  static const String _googleServerClientId =
      '615971922286-875kbmm3rkhkr1lp75ctql5qadjlqo84.apps.googleusercontent.com';

  // Video Settings
  String _videoSource = 'asset'; 
  String? _videoUrl; 
  String? _videoAsset;
  
  // Logo Settings
  String _logoSource = 'asset';
  String? _logoUrl;
  String? _logoAsset;

  bool _videoLoaded = false;

  // Overlay state to allow unlimited open/close
  bool _isVideoOpen = false;
  OverlayEntry? _videoEntry;

  // Key to find the logo position for the opening animation
  final GlobalKey _logoKey = GlobalKey();

  bool _googleReady = false;
  static const MethodChannel _facebookChannel =
      MethodChannel('native_facebook_auth');

  @override
  void initState() {
    super.initState();
    _loadVideoLogo();
  }

  Future<void> _loadVideoLogo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_cfgCol)
          .doc(_videoDoc)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _videoSource = data['videoSource'] ?? (data['url'] != null ? 'youtube' : 'asset');
        _videoUrl = (data['videoUrl'] ?? data['url'] ?? _appDefaultYouTubeUrl).toString().trim();
        _videoAsset = (data['videoAsset'] ?? 'assets/videos/Nina Verde Delicia Halada (Baila Conmingo).mp4').toString().trim();

        _logoSource = data['logoSource'] ?? (data['logo'] != null ? 'network' : 'asset');
        _logoUrl = (data['logoUrl'] ?? data['logo'] ?? _appDefaultLogoUrl).toString().trim();
        _logoAsset = (data['logoAsset'] ?? 'assets/images/app_icon_foreground.png').toString().trim();
      }
    } catch (_) {
      // Silent; fall back to defaults
    } finally {
      if (mounted) setState(() => _videoLoaded = true);
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    _videoEntry?.remove();
    super.dispose();
  }

  // ---- Tiny ES/EN map ------------------------------------------------------
  String t(BuildContext context, String key) {
    final es = AppState.of(context).languageCode.value == 'es';

    const esMap = {
      'title': 'Iniciar sesion',
      'email': 'Correo',
      'password': 'Contrasena',
      'login': 'Iniciar sesion',
      'forgot': 'Olvidaste tu contrasena?',
      'google': 'Google',
      'facebook': 'Facebook',
      'apple': 'Apple',
      'microsoft': 'Microsoft',
      'guest': 'Continuar como invitado',
      'noAccount': 'No tienes cuenta? Registrate!',
      'contact': 'Contactenos',
      'privacy': 'Politica de Privacidad',
      'deletion': 'Eliminacion de Datos',
      'show': 'Mostrar',
      'hide': 'Ocultar',
      'enter_email': 'Ingresa tu correo',
      'enter_password': 'Ingresa tu contrasena',
      'reset_title': 'Restablecer contrasena',
      'send': 'Enviar',
      'cancel': 'Cancelar',
      'reset_sent': 'Correo de restablecimiento enviado.',
      'err_invalid_email': 'Correo invalido.',
      'err_user_not_found': 'No existe un usuario con ese correo.',
      'err_wrong_password': 'Contrasena incorrecta.',
      'err_network': 'Error de red. Intenta de nuevo.',
      'err_generic': 'Error al iniciar sesion',
      'err_provider_disabled':
          'Este proveedor no esta habilitado. Configuralo en Firebase.',
      'err_provider_unsupported':
          'Este proveedor no es compatible en esta plataforma.',
      'err_oauth_missing':
          'Faltan credenciales OAuth. Configura el proveedor en Firebase.',
      'fb_cancelled': 'Inicio de sesion con Facebook cancelado.',
      'fb_failed': 'Error al iniciar sesion con Facebook.',
      'play_video': 'Reproducir video de introduccion',
      'or_rapid': 'O inicio rapido con',
      'video_url_hint': 'Pega la URL de YouTube (https://youtu.be/ o watch?v=)',
      'logo_url_hint': 'Pega la URL del logo (https:// .png/.jpg)',
      'open_youtube': 'Abrir YouTube',
      'video_unavailable': 'Video no disponible',
      'video_open_hint': 'Abrir en YouTube.',
      // Popup dialog:
      'popup_title': 'Configuracion del popup',
      'yt_label': 'URL de YouTube',
      'logo_label': 'URL del logo (opcional)',
      'save_btn': 'Guardar',
      'saving_btn': 'Guardando',
      'make_default_btn': 'Hacer predeterminado',
      'reset_default_btn': 'Restablecer al predeterminado',
      'saved_ok': 'Guardado',
      'save_failed': 'Error al guardar',
      'insufficient': 'Permisos insuficientes',
    };

    const enMap = {
      'title': 'Login',
      'email': 'Email',
      'password': 'Password',
      'login': 'Log in',
      'forgot': 'Forgot password?',
      'google': 'Google',
      'facebook': 'Facebook',
      'apple': 'Apple',
      'microsoft': 'Microsoft',
      'guest': 'Continue as guest',
      'noAccount': "Don't have an account? Register!",
      'contact': 'Contact Us',
      'privacy': 'Privacy Policy',
      'deletion': 'Data Deletion',
      'show': 'Show',
      'hide': 'Hide',
      'enter_email': 'Enter your email',
      'enter_password': 'Enter your password',
      'reset_title': 'Reset password',
      'send': 'Send',
      'cancel': 'Cancel',
      'reset_sent': 'Password reset email sent.',
      'err_invalid_email': 'Invalid email address.',
      'err_user_not_found': 'No user found for that email.',
      'err_wrong_password': 'Wrong password.',
      'err_network': 'Network error. Try again.',
      'err_generic': 'Sign-in failed',
      'err_provider_disabled':
          'This provider is not enabled. Configure it in Firebase.',
      'err_provider_unsupported':
          'This provider is not supported on this platform.',
      'err_oauth_missing':
          'OAuth credentials are missing. Configure the provider in Firebase.',
      'fb_cancelled': 'Facebook sign-in cancelled.',
      'fb_failed': 'Facebook sign-in failed.',
      'play_video': 'Play intro video',
      'or_rapid': 'Or rapid sign in with',
      'video_url_hint': 'Paste YouTube URL (https://youtu.be/ or watch?v=)',
      'logo_url_hint': 'Paste logo image URL (https:// .png/.jpg)',
      'open_youtube': 'Open YouTube',
      'video_unavailable': 'Video unavailable',
      'video_open_hint': 'Open in YouTube instead.',
      // Popup dialog:
      'popup_title': 'Popup Settings',
      'yt_label': 'YouTube URL',
      'logo_label': 'Logo URL (optional)',
      'save_btn': 'Save',
      'saving_btn': 'Saving',
      'make_default_btn': 'Make default',
      'reset_default_btn': 'Reset to default',
      'saved_ok': 'Saved',
      'save_failed': 'Save failed',
      'insufficient': 'Insufficient permissions',
    };

    return (es ? esMap : enMap)[key]!;
  }

  // --------------------------------------------------------------------------
  // Auth flows (all call UserService.upsertCurrentUser on success)
  // --------------------------------------------------------------------------
  Future<void> _handleAccountExists(FirebaseAuthException e) async {
    final email = e.email;
    final pending = e.credential;
    if (email == null || pending == null) {
      _showError(t(context, 'err_oauth_missing'));
      return;
    }

    final methods = await auth_platform.FirebaseAuthPlatform.instance
        .fetchSignInMethodsForEmail(email);
    if (methods.isEmpty) {
      if (!mounted) return;
      _showError(t(context, 'err_oauth_missing'));
      return;
    }

    UserCredential? existing;
    if (methods.contains('google.com')) {
      final googleCred = await _getGoogleCredential();
      if (googleCred != null) {
        existing =
            await FirebaseAuth.instance.signInWithCredential(googleCred);
      }
    } else if (methods.contains('facebook.com')) {
      final fbToken =
          await _facebookChannel.invokeMethod<String>('logIn');
      if (fbToken != null && fbToken.isNotEmpty) {
        final fbCred = FacebookAuthProvider.credential(fbToken);
        existing =
            await FirebaseAuth.instance.signInWithCredential(fbCred);
      }
    } else if (methods.contains('apple.com')) {
      final appleCred = await _getAppleCredential();
      if (appleCred != null) {
        existing =
            await FirebaseAuth.instance.signInWithCredential(appleCred);
      }
    } else if (methods.contains('microsoft.com')) {
      final provider = OAuthProvider('microsoft.com');
      provider.setCustomParameters({'prompt': 'select_account'});
      provider
        ..addScope('openid')
        ..addScope('profile')
        ..addScope('email')
        ..addScope('User.Read');
      existing = await FirebaseAuth.instance.signInWithProvider(provider);
    }

    if (existing?.user == null) {
      if (!mounted) return;
      _showError(t(context, 'err_oauth_missing'));
      return;
    }

    await existing!.user!.linkWithCredential(pending);
    await UserService.upsertCurrentUser();
    await _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    bool isAdmin = false;

    if (user != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = snap.data();
        if (data != null) {
          isAdmin = data['isAdmin'] == true ||
              (data['role'] as String?)?.toLowerCase() == 'admin';
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (isAdmin) {
      Navigator.pushNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Future<AuthCredential?> _getGoogleCredential() async {
    await _ensureGoogleReady();
    final g = GoogleSignIn.instance;
    final account = await g.authenticate();
    final auth = account.authentication;
    if (auth.idToken == null) return null;
    return GoogleAuthProvider.credential(idToken: auth.idToken);
  }

  Future<AuthCredential?> _getAppleCredential() async {
    if (!(defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS)) {
      return null;
    }
    final rawNonce = _randomNonce();
    final nonce = _sha256ofString(rawNonce);
    final appleCred = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName
      ],
      nonce: nonce,
    );
    if (appleCred.identityToken == null) return null;
    return OAuthProvider('apple.com').credential(
      idToken: appleCred.identityToken,
      rawNonce: rawNonce,
    );
  }

  Future<void> signInEmailPassword() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
      await UserService.upsertCurrentUser();
      await _navigateToHome();
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Google Sign-In (native) -> Firebase
  // FIXED for your current google_sign_in API:
  // - no signIn()/signInSilently()
  // - authentication is NOT a Future
  // - accessToken not available
  Future<void> signInGoogle() async {
    setState(() => busy = true);
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      } else if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final cred = await _getGoogleCredential();
        if (cred == null) {
          throw FirebaseAuthException(
              code: 'missing-client-identifier',
              message: 'Missing Google credential.');
        }
        final current = FirebaseAuth.instance.currentUser;
        if (current != null) {
          try {
            await current.linkWithCredential(cred);
          } on FirebaseAuthException catch (le) {
            if (le.code == 'credential-already-in-use' || le.code == 'provider-already-linked') {
              await FirebaseAuth.instance.signInWithCredential(cred);
            } else {
              rethrow;
            }
          }
        } else {
          await FirebaseAuth.instance.signInWithCredential(cred);
        }
      } else {
        await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
      }
      await UserService.upsertCurrentUser();
      await _navigateToHome();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        await _handleAccountExists(e);
      } else {
        if (e.code == 'provider-already-linked' || e.code == 'credential-already-in-use') {
          await _navigateToHome();
        } else {
          _showError(_firebaseMessage(e));
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _ensureGoogleReady() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );
    _googleReady = true;
  }

  Future<void> signInFacebook() async {
    setState(() => busy = true);
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(FacebookAuthProvider());
      } else if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        final token =
            await _facebookChannel.invokeMethod<String>('logIn');
        if (token == null || token.isEmpty) {
          if (!mounted) return;
          _showSnack(t(context, 'fb_cancelled'));
          return;
        }
        final cred = FacebookAuthProvider.credential(token);
        final current = FirebaseAuth.instance.currentUser;
        if (current != null) {
          try {
            await current.linkWithCredential(cred);
          } on FirebaseAuthException catch (le) {
            if (le.code == 'credential-already-in-use' || le.code == 'provider-already-linked') {
              await FirebaseAuth.instance.signInWithCredential(cred);
            } else {
              rethrow;
            }
          }
        } else {
          await FirebaseAuth.instance.signInWithCredential(cred);
        }
      } else {
        await FirebaseAuth.instance.signInWithProvider(FacebookAuthProvider());
      }

      await UserService.upsertCurrentUser();
      await _navigateToHome();
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'cancelled') {
        _showSnack(t(context, 'fb_cancelled'));
      } else {
        _showError(e.message ?? t(context, 'fb_failed'));
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        await _handleAccountExists(e);
      } else {
        if (e.code == 'provider-already-linked' || e.code == 'credential-already-in-use') {
          await _navigateToHome();
        } else {
          _showError(_firebaseMessage(e));
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Apple Sign-In (Firebase)
  Future<void> signInApple() async {
    setState(() => busy = true);
    try {
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(OAuthProvider('apple.com'));
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final oauth = await _getAppleCredential();
        if (oauth == null) {
          throw FirebaseAuthException(
              code: 'missing-client-identifier',
              message: 'Missing Apple credential.');
        }
        final current = FirebaseAuth.instance.currentUser;
        if (current != null) {
          try {
            await current.linkWithCredential(oauth);
          } on FirebaseAuthException catch (le) {
            if (le.code == 'credential-already-in-use' || le.code == 'provider-already-linked') {
              await FirebaseAuth.instance.signInWithCredential(oauth);
            } else {
              rethrow;
            }
          }
        } else {
          await FirebaseAuth.instance.signInWithCredential(oauth);
        }
      } else {
        await FirebaseAuth.instance
            .signInWithProvider(OAuthProvider('apple.com'));
      }
      await UserService.upsertCurrentUser();
      await _navigateToHome();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        _showError('Apple sign-in failed: ${e.code.name}');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        await _handleAccountExists(e);
      } else {
        if (e.code == 'provider-already-linked' || e.code == 'credential-already-in-use') {
          await _navigateToHome();
        } else {
          _showError(_firebaseMessage(e));
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Microsoft Sign-In (Firebase)
  Future<void> signInMicrosoft() async {
    setState(() => busy = true);
    try {
      final provider = OAuthProvider('microsoft.com');
      provider.setCustomParameters({'prompt': 'select_account'});
      provider
        ..addScope('openid')
        ..addScope('profile')
        ..addScope('email')
        ..addScope('User.Read');

      UserCredential cred;
      if (kIsWeb) {
        cred = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final current = FirebaseAuth.instance.currentUser;
        if (current != null) {
          try {
            cred = await current.linkWithProvider(provider);
          } on FirebaseAuthException catch (le) {
            if (le.code == 'credential-already-in-use' || le.code == 'provider-already-linked') {
              cred = await FirebaseAuth.instance.signInWithProvider(provider);
            } else {
              rethrow;
            }
          }
        } else {
          cred = await FirebaseAuth.instance.signInWithProvider(provider);
        }
      }
      if (cred.user == null) {
        throw FirebaseAuthException(
            code: 'microsoft-error', message: 'No user returned.');
      }
      await UserService.upsertCurrentUser();
      await _navigateToHome();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        await _handleAccountExists(e);
      } else {
        if (e.code == 'provider-already-linked' || e.code == 'credential-already-in-use') {
          await _navigateToHome();
        } else {
          _showError(_firebaseMessage(e));
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Guest sign-in
  Future<void> signInGuest() async {
    setState(() => busy = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
      await UserService.upsertCurrentUser();
      await _navigateToHome();
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e));
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Forgot Password
  Future<void> forgotPasswordDialog() async {
    final c = TextEditingController(text: emailCtrl.text.trim());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(context, 'reset_title')),
        content: TextFormField(
          controller: c,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: t(context, 'email'),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t(context, 'cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t(context, 'send'))),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: c.text.trim());
      if (!mounted) return;
      _showSnack(t(context, 'reset_sent'));
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e));
    } catch (e) {
      _showError(e.toString());
    }
  }

  // ---- Helpers -------------------------------------------------------------
  String _firebaseMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return t(context, 'err_invalid_email');
      case 'user-not-found':
        return t(context, 'err_user_not_found');
      case 'wrong-password':
      case 'invalid-credential':
        return t(context, 'err_wrong_password');
      case 'network-request-failed':
        return t(context, 'err_network');
      case 'operation-not-allowed':
        return t(context, 'err_provider_disabled');
      case 'invalid-oauth-client-id':
      case 'missing-or-invalid-nonce':
      case 'missing-client-identifier':
      case 'unauthorized-domain':
        return t(context, 'err_oauth_missing');
      case 'provider-not-supported':
        return t(context, 'err_provider_unsupported');
      default:
        return '${t(context, 'err_generic')} (${e.code})';
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red.shade700, content: Text(msg)),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Nonce helpers for Apple
  String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final rand = Random.secure();
    return List.generate(length, (_) => charset[rand.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // --------- Animated YouTube overlay (logo centered) ----------
  void _openVideoFromLogo() async {
    if (_isVideoOpen) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final logoContext = _logoKey.currentContext;
    if (logoContext == null) return;
    final box = logoContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final logoOffset = box.localToGlobal(Offset.zero);
    final logoSize = box.size;
    final logoRect = Rect.fromLTWH(
      logoOffset.dx,
      logoOffset.dy,
      logoSize.width,
      logoSize.height,
    );

    final size = MediaQuery.of(context).size;
    final paddingTop = MediaQuery.of(context).padding.top;
    final reservedTop =
        paddingTop + kToolbarHeight + NvAppBar.tickerHeight + 16;

    double width = size.width * 0.85;
    double height = width * 9 / 16;

    final maxHeight = size.height - reservedTop - 60;
    if (height > maxHeight) {
      height = maxHeight;
      width = height * 16 / 9;
    }

    final targetRect = Rect.fromLTWH(
      (size.width - width) / 2,
      reservedTop,
      width,
      height,
    );

    // --- Video Preparation ---
    VideoPlayerController? vp;
    YoutubePlayerController? yt;
    Future<void>? initFuture;

    if (_videoSource == 'asset' || _videoSource == 'url') {
      vp = _videoSource == 'asset'
          ? VideoPlayerController.asset(_videoAsset ?? 'assets/videos/Nina Verde Delicia Halada (Baila Conmingo).mp4')
          : VideoPlayerController.networkUrl(Uri.parse(_videoUrl ?? ''));
      initFuture = vp.initialize().then((_) {
        vp!.setLooping(true);
        vp.play();
      });
    } else {
      final id = _extractYoutubeId(_videoUrl) ?? 'ZczKlWNp5qY';
      yt = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: true,
        params: const YoutubePlayerParams(
          playsInline: true,
          showFullscreenButton: true,
          strictRelatedVideos: true,
          mute: true,
          showVideoAnnotations: false,
          enableJavaScript: true,
        ),
      );
    }

    final animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );

    final rectAnim = RectTween(begin: logoRect, end: targetRect).animate(
      CurvedAnimation(parent: animCtrl, curve: Curves.easeOutBack),
    );

    _isVideoOpen = true;

    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) {
      return AnimatedBuilder(
        animation: rectAnim,
        builder: (ctx, __) {
          final rect = rectAnim.value ?? targetRect;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () async {
                    await animCtrl.reverse();
                    if (vp != null) {
                      await vp.pause();
                      await vp.dispose();
                    }
                    if (yt != null) {
                      yt.close();
                    }
                    entry.remove();
                    animCtrl.dispose();
                    _isVideoOpen = false;
                    _videoEntry = null;
                  },
                  child: Container(color: Colors.black.withValues(alpha: 0.7)),
                ),
              ),
              Positioned(
                left: rect.left,
                top: rect.top,
                child: Material(
                  color: Colors.black,
                  elevation: 20,
                  borderRadius: BorderRadius.circular(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: rect.width,
                      height: rect.height,
                      child: vp != null
                          ? FutureBuilder(
                              future: initFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.done) {
                                  return AspectRatio(
                                    aspectRatio: vp!.value.aspectRatio,
                                    child: VideoPlayer(vp),
                                  );
                                }
                                return const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                );
                              },
                            )
                          : YoutubePlayer(controller: yt!),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: rect.left,
                top: rect.top - 50,
                left: rect.left,
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 32),
                    onPressed: () async {
                      await animCtrl.reverse();
                      if (vp != null) {
                        await vp.pause();
                        await vp.dispose();
                      }
                      if (yt != null) {
                        yt.close();
                      }
                      entry.remove();
                      animCtrl.dispose();
                      _isVideoOpen = false;
                      _videoEntry = null;
                    },
                  ),
                ),
              ),
            ],
          );
        },
      );
    });

    _videoEntry = entry;
    overlay.insert(entry);
    animCtrl.forward();
  }



  String? _extractYoutubeId(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();

    // 1. Direct 11-char ID
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(trimmed)) return trimmed;

    // 2. Try URI parsing
    final u = Uri.tryParse(trimmed);
    if (u != null) {
      if (u.host.contains('youtu.be')) return u.pathSegments.firstWhere((s) => s.isNotEmpty, orElse: () => '');
      if (u.host.contains('youtube.com') || u.host.contains('youtube-nocookie.com')) {
        if (u.queryParameters.containsKey('v')) return u.queryParameters['v'];
        if (u.pathSegments.contains('shorts')) return u.pathSegments[u.pathSegments.indexOf('shorts') + 1];
        if (u.pathSegments.contains('embed')) return u.pathSegments[u.pathSegments.indexOf('embed') + 1];
        if (u.pathSegments.contains('live')) return u.pathSegments[u.pathSegments.indexOf('live') + 1];
        if (u.pathSegments.contains('v')) return u.pathSegments[u.pathSegments.indexOf('v') + 1];
      }
    }

    // 3. Regex fallback
    final reg = RegExp(r'(?:v=|\/|embed\/|shorts\/|live\/|^)([A-Za-z0-9_-]{11})(?:[?&]|$)');
    return reg.firstMatch(trimmed)?.group(1);
  }

  // ---- UI ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final app = AppState.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkColor =
        isDark ? Theme.of(context).colorScheme.primary : nvGreenDark;

    return ValueListenableBuilder<String>(
      valueListenable: app.languageCode,
      builder: (_, __, ___) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: NvAppBar(title: t(context, 'title'), centerTitle: false),
          body: SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 16,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            const SizedBox(height: 12),

                            // ---- HERO LOGO (tap plays, long-press settings) ----
                            Tooltip(
                              message: t(context, 'play_video'),
                              child: Semantics(
                                button: true,
                                label: t(context, 'play_video'),
                                child: GestureDetector(
                                  onTap: () {
                                    if (!_videoLoaded) return;
                                    _openVideoFromLogo();
                                  },
                                  onLongPress: () {
                                    if (AppState.of(context).isManager.value) {
                                      Navigator.pushNamed(context, '/app-settings/intro');
                                    }
                                  },
                                  child: Hero(
                                    tag: 'nv.logo',
                                    child: _buildLogoWidget(),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ---- FORM ---------------------------------------
                            Form(
                              key: formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [
                                      AutofillHints.username
                                    ],
                                    decoration: InputDecoration(
                                      labelText: t(context, 'email'),
                                      prefixIcon:
                                          const Icon(Icons.email_outlined),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return t(context, 'enter_email');
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: passCtrl,
                                    obscureText: obscured,
                                    autofillHints: const [
                                      AutofillHints.password
                                    ],
                                    decoration: InputDecoration(
                                      labelText: t(context, 'password'),
                                      prefixIcon: const Icon(
                                          Icons.lock_outline_rounded),
                                      suffixIcon: IconButton(
                                        tooltip: obscured
                                            ? t(context, 'show')
                                            : t(context, 'hide'),
                                        onPressed: () => setState(
                                            () => obscured = !obscured),
                                        icon: Icon(
                                          obscured
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return t(context, 'enter_password');
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ---- PRIMARY ACTION ------------------------------
                            FilledButton(
                              onPressed: busy ? null : signInEmailPassword,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                shape: const StadiumBorder(),
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(t(context, 'login')),
                            ),

                            const SizedBox(height: 12),

                            // ---- NAV LINKS above Forgot ----------------------
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                      Navigator.pushNamed(context, '/register'),
                              style: TextButton.styleFrom(
                                foregroundColor: linkColor,
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              child: Builder(builder: (ctx) {
                                final s = t(context, 'noAccount');
                                final idx = s.lastIndexOf(' ');
                                if (idx <= 0) return Text(s);
                                final left = s.substring(0, idx + 1);
                                final right = s.substring(idx + 1);
                                return RichText(
                                  text: TextSpan(
                                    style: DefaultTextStyle.of(ctx)
                                        .style
                                        .copyWith(fontWeight: FontWeight.w700),
                                    children: [
                                      TextSpan(text: left),
                                      TextSpan(
                                        text: right,
                                        style:
                                            const TextStyle(color: nvAccentOrange),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: busy ? null : forgotPasswordDialog,
                              style: TextButton.styleFrom(
                                foregroundColor: linkColor,
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              child: Text(t(context, 'forgot')),
                            ),

                            const SizedBox(height: 16),

                            // ----- Divider with centered label ---------------
                            _LabeledDivider(label: t(context, 'or_rapid')),

                            const SizedBox(height: 12),

                            // ---- SOCIAL (2-2 layout) -------------------------
                            Row(
                              children: [
                                Expanded(
                                  child: _GoogleButton(
                                      onPressed: busy ? null : signInGoogle),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SocialButton(
                                    onPressed: busy ? null : signInFacebook,
                                    bg: const Color(0xFF1877F2),
                                    fg: Colors.white,
                                    icon: const FaIcon(
                                        FontAwesomeIcons.facebookF,
                                        size: 22),
                                    label: t(context, 'facebook'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _SocialButton(
                                    onPressed: busy ? null : signInApple,
                                    bg: Colors.black,
                                    fg: Colors.white,
                                    icon: const FaIcon(FontAwesomeIcons.apple,
                                        size: 22),
                                    label: t(context, 'apple'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SocialButton(
                                    onPressed: busy ? null : signInMicrosoft,
                                    bg: Colors.white,
                                    fg: Colors.black87,
                                    icon: const _MicrosoftLogo(size: 22),
                                    label: t(context, 'microsoft'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Guest (full width)
                            _SocialButton(
                              onPressed: busy ? null : signInGuest,
                              bg: Theme.of(context).colorScheme.surfaceContainerHighest,
                              fg: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              icon: const Icon(Icons.person_outline),
                              label: t(context, 'guest'),
                              fullWidth: true,
                              outlinedLook: true,
                            ),

                            const SizedBox(height: 20),

                            // ---- Footer links (wrap to 2 lines if needed) ----
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 18,
                                runSpacing: 6,
                                children: [
                                  TextButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () => Navigator.pushNamed(
                                            context, '/privacy'),
                                    icon: const Icon(Icons.privacy_tip_outlined),
                                    label: Text(t(context, 'privacy')),
                                  ),
                                  TextButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () => Navigator.pushNamed(
                                            context, '/data-deletion'),
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(t(context, 'deletion')),
                                  ),
                                  TextButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () => Navigator.pushNamed(
                                            context, '/contact'),
                                    icon:
                                        const Icon(Icons.support_agent_outlined),
                                    label: Text(t(context, 'contact')),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoWidget() {
    final defaultAsset = 'assets/images/app_icon_foreground.png';
    
    Widget logo;
    if (_logoSource == 'asset') {
      logo = Image.asset(
        _logoAsset ?? defaultAsset,
        key: _logoKey,
        width: 120,
        height: 120,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(defaultAsset, width: 120, height: 120),
      );
    } else {
      logo = Image.network(
        _logoUrl ?? _appDefaultLogoUrl,
        key: _logoKey,
        width: 120,
        height: 120,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(defaultAsset, width: 120, height: 120),
      );
    }
    
    return logo;
  }
}

// -------- Centered text with dividers on both sides -----------------
class _LabeledDivider extends StatelessWidget {
  final String label;
  const _LabeledDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2);
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: style),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Google brand button (white background, multicolor wordmark, bigger G icon)
// ---------------------------------------------------------------------------
class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    // Official Google colors
    const blue = Color(0xFF4285F4);
    const red = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green = Color(0xFF34A853);

    TextSpan wordmark() => const TextSpan(children: [
          TextSpan(
              text: 'G',
              style: TextStyle(color: blue, fontWeight: FontWeight.w700)),
          TextSpan(
              text: 'o',
              style: TextStyle(color: red, fontWeight: FontWeight.w700)),
          TextSpan(
              text: 'o',
              style: TextStyle(color: yellow, fontWeight: FontWeight.w700)),
          TextSpan(
              text: 'g',
              style: TextStyle(color: blue, fontWeight: FontWeight.w700)),
          TextSpan(
              text: 'l',
              style: TextStyle(color: green, fontWeight: FontWeight.w700)),
          TextSpan(
              text: 'e',
              style: TextStyle(color: red, fontWeight: FontWeight.w700)),
        ]);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Double the usual icon size for emphasis
          SizedBox(
            width: 44,
            height: 44,
            child: Image.asset(
              'assets/images/google_g_color.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.g_mobiledata_rounded, size: 44),
            ),
          ),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, letterSpacing: 0.2),
              children: [wordmark()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pretty social button used above
// ---------------------------------------------------------------------------
class _SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color bg;
  final Color fg;
  final Widget icon;
  final String label;
  final bool fullWidth;
  final bool outlinedLook;

  const _SocialButton({
    required this.onPressed,
    required this.bg,
    required this.fg,
    required this.icon,
    required this.label,
    this.fullWidth = false,
    this.outlinedLook = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = const StadiumBorder();
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon,
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ],
    );

    if (outlinedLook) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(fullWidth ? 48 : 44),
          shape: shape,
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: Size.fromHeight(fullWidth ? 52 : 48),
        shape: shape,
        elevation: 1,
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Microsoft colored logo
// ---------------------------------------------------------------------------
class _MicrosoftLogo extends StatelessWidget {
  final double size;
  const _MicrosoftLogo({this.size = 22});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF25022);
    const green = Color(0xFF7FBA00);
    const blue = Color(0xFF00A4EF);
    const yellow = Color(0xFFFFB900);
    final s = size / 2 - 1;

    Widget sq(Color c) => Container(width: s, height: s, color: c);

    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [sq(orange), const SizedBox(width: 2), sq(green)],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [sq(blue), const SizedBox(width: 2), sq(yellow)],
          ),
        ],
      ),
    );
  }
}


