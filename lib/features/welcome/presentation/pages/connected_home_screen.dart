import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

/// Accueil une fois connecté : tableau de bord (pas l'écran login/register).
/// L'utilisateur peut utiliser la bottom nav pour Carte, Alertes, Santé, Profil.
class ConnectedHomeScreen extends StatefulWidget {
  const ConnectedHomeScreen({super.key});

  @override
  State<ConnectedHomeScreen> createState() => _ConnectedHomeScreenState();
}

class _ConnectedHomeScreenState extends State<ConnectedHomeScreen> {
  String? _firstName;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      if (!getIt.isRegistered<IAuthRepository>()) return;
      final repo = getIt<IAuthRepository>();
      final user = await repo.getCurrentUser();
      if (mounted && user?.firstName != null) {
        setState(() => _firstName = user!.firstName);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _firstName != null && _firstName!.isNotEmpty
        ? 'Bienvenue, $_firstName !'
        : 'Bienvenue !';
    // No Scaffold here — the shell (MainShell) already provides one
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            _buildLogo(),
            const SizedBox(height: 32),
            Text(
              greeting,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Utilise le menu en bas pour accéder à la Carte, Alertes, Santé et Profil.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textMuted,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _quickLink(context, Icons.map_outlined, 'Carte', AppRoutes.homeCarte),
            const SizedBox(height: 12),
            _quickLink(context, Icons.pets, 'Mes chiens', AppRoutes.dogList),
            const SizedBox(height: 12),
            _quickLink(context, Icons.favorite_outline, 'Santé', AppRoutes.homeSante),
            const SizedBox(height: 12),
            _quickLink(context, Icons.person_outline, 'Profil', AppRoutes.homeProfil),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.pets, size: 36, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          'K9 Sync',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  /// Pour les onglets du shell, on utilise goBranch pour que l'index de la bottom nav soit mis à jour.
  void _navigateTo(BuildContext context, String path) {
    final shell = StatefulNavigationShell.maybeOf(context);
    final branchIndex = _shellPathToIndex(path);
    if (shell != null && branchIndex != null) {
      shell.goBranch(branchIndex);
      context.go(path);
    } else {
      context.go(path);
    }
  }

  static int? _shellPathToIndex(String path) {
    switch (path) {
      case AppRoutes.homeAccueil:
        return 0;
      case AppRoutes.homeCarte:
        return 1;
      case AppRoutes.homeAlertes:
        return 2;
      case AppRoutes.homeSante:
        return 3;
      case AppRoutes.homeProfil:
        return 4;
      default:
        return null;
    }
  }

  Widget _quickLink(BuildContext context, IconData icon, String label, String path) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateTo(context, path),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.border, width: 2),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            boxShadow: [AppDimensions.cardShadowSm],
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
