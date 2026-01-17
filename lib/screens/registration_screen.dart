import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../state/app_state.dart';
import '../widgets/nv_widgets.dart';
import '../widgets/angelina_widget.dart';
import '../services/user_service.dart';
import '../theme/brand_colors.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      
      // Update display name
      if (cred.user != null) {
        await cred.user!.updateDisplayName(_nameCtrl.text.trim());
      }

      await UserService.upsertCurrentUser();
      
      if (!mounted) return;
      // Navigate to Intro/Onboarding instead of Home
      Navigator.pushNamedAndRemoveUntil(context, '/intro', (route) => false);

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(e.message ?? tr(context, en: 'Registration failed', es: 'Registro fallido'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red, 
          content: Text('${tr(context, en: 'Error', es: 'Error')}: $e')
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.grey[900]! : const Color(0xFFF8F9FA); // Off-white/dark
    final cardBg = isDark ? Colors.black54 : Colors.white.withValues(alpha: 0.9);

    final trWelcome = tr(context, 
      en: "Welcome! I'll get you set up in no time.", 
      es: "¡Bienvenido! Te registraré en un momento."
    );

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Background decorative elements (optional gradients)
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: nvAccentOrange.withValues(alpha: 0.1),
                boxShadow: const [
                  BoxShadow(color: Colors.transparent, blurRadius: 60),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Custom App Bar Area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const BackButton(),
                      const Spacer(),
                      const NvLanguageToggle(),
                    ],
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        
                        // Angelina Greeting
                        SizedBox(
                          height: 380,
                          child: AngelinaWidget(
                            pose: AngelinaPose.conciergeWaving,
                            speech: trWelcome,
                            height: 380,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Form Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10)),
                            ],
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  tr(context, en: 'Create Account', es: 'Crear Cuenta'),
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                
                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: InputDecoration(
                                    labelText: tr(context, en: 'Full Name', es: 'Nombre Completo'),
                                    prefixIcon: const Icon(Icons.person_outline),
                                    filled: true,
                                    fillColor: isDark ? Colors.black26 : Colors.grey[50],
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  validator: (v) => v?.isEmpty == true ? tr(context, en: 'Required', es: 'Requerido') : null,
                                ),
                                const SizedBox(height: 16),
                                
                                TextFormField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: tr(context, en: 'Email', es: 'Correo'),
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    filled: true,
                                    fillColor: isDark ? Colors.black26 : Colors.grey[50],
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  validator: (v) => (v == null || !v.contains('@')) ? tr(context, en: 'Invalid email', es: 'Correo inválido') : null,
                                ),
                                const SizedBox(height: 16),
                                
                                TextFormField(
                                  controller: _passCtrl,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    labelText: tr(context, en: 'Password', es: 'Contraseña'),
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                    ),
                                    filled: true,
                                    fillColor: isDark ? Colors.black26 : Colors.grey[50],
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  validator: (v) => (v?.length ?? 0) < 6 ? tr(context, en: 'Min 6 chars', es: 'Mín 6 caracteres') : null,
                                ),
                                const SizedBox(height: 32),

                                FilledButton(
                                  onPressed: _busy ? null : _register,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    backgroundColor: nvGreen, 
                                  ),
                                  child: _busy 
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(
                                        tr(context, en: 'Sign Up', es: 'Registrarse'),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutQuart).fadeIn(),
                        
                         const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
