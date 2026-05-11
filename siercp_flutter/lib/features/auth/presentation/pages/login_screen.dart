import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:siercp/core/theme/theme.dart';
import 'package:siercp/features/auth/presentation/providers/auth_provider.dart';
import 'package:siercp/features/auth/data/firebase_auth_service.dart';
import 'package:siercp/l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final loc = AppLocalizations.of(context)!;
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = loc.loginErrorEmptyFields);
      _shakeCtrl.forward(from: 0);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authStateProvider.notifier).login(
            _emailCtrl.text.trim(),
            _passCtrl.text,
          );
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _error = FirebaseAuthService.parseAuthError(e));
      _shakeCtrl.forward(from: 0);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final loc = AppLocalizations.of(context)!;
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = loc.forgotPassErrorEmpty);
      return;
    }
    try {
      await ref
          .read(authStateProvider.notifier)
          .sendPasswordReset(_emailCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.forgotPassSuccess),
            backgroundColor: AppColors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = FirebaseAuthService.parseAuthError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final textP = theme.textTheme.bodyLarge?.color ?? AppColors.textPrimary;
    final textS = theme.textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final surface = theme.colorScheme.surface;
    final border = theme.colorScheme.outline;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 56),

              // ── Logo + Branding ──
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: AppShadows.elevated(isDark),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        child: Image.asset(
                          'assets/images/logov3.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'SIERCP',
                      style: TextStyle(
                        color: textP,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.loginSubtitle,
                      style: TextStyle(color: textS, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                    _shakeCtrl.isAnimating
                        ? (_shakeCtrl.value < 0.5
                            ? _shakeAnim.value
                            : -_shakeAnim.value)
                        : 0,
                    0,
                  ),
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: border, width: 0.5),
                    boxShadow: isDark ? null : AppShadows.card(false),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        loc.loginTitle,
                        style: TextStyle(
                          color: textP,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loc.loginInstruction,
                        style: TextStyle(color: textS, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: textP),
                        decoration: InputDecoration(
                          labelText: loc.emailLabel,
                          hintText: loc.emailHint,
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        onFieldSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        style: TextStyle(color: textP),
                        decoration: InputDecoration(
                          labelText: loc.passwordLabel,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                        onFieldSubmitted: (_) => _login(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: Text(loc.forgotPassword),
                        ),
                      ),

                      // Error banner
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.redBg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppColors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppColors.red, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(loc.loginTitle),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Register link
              Row(
                children: [
                  Expanded(child: Divider(color: border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextButton(
                      onPressed: () => context.push('/register'),
                      child: Text(loc.noAccountRegister),
                    ),
                  ),
                  Expanded(child: Divider(color: border)),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
