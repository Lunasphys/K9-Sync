import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

/// Initial screen — checks auth token then redirects.
/// Shows for at least 1.5s to avoid flash.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    // Wait for first frame before navigating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    _resolveDestination();
  }

  // Destination is only ever /home/accueil or /login here — if the session
  // is logged in but hasn't accepted the mandatory consent yet, GoRouter's
  // redirect (authGuard) intercepts this and sends it to /consent instead.
  // That check lives in exactly one place so every entry point (this one,
  // interactive login, a future deep link) is covered without duplicating it.
  Future<void> _resolveDestination() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      final isLoggedIn = getIt<IAuthRepository>().isLoggedIn;
      if (!mounted) return;
      context.go(isLoggedIn ? AppRoutes.homeAccueil : AppRoutes.login);
    } catch (_) {
      if (mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          // Logo/title block is centered on the full screen via [Center]
          // rather than living inside a Column flanked by two equal
          // Spacers — with the loading spinner as a sibling fixed-height
          // element below (not mirrored above), the old Column layout
          // wasn't actually symmetric: the spinner's height shifted the
          // logo block above true center, more so on shorter screens.
          // Centering it directly and pinning the spinner independently
          // keeps both correct regardless of screen size.
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.border, width: 2),
                        boxShadow: [AppDimensions.cardShadow],
                      ),
                      child: const Center(
                        child: Text('🐾', style: TextStyle(fontSize: 48)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text(
                      'K9 Sync',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Le compagnon connecté de votre chien',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.orange,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
