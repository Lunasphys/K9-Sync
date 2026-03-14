import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:k9sync/core/debug/debug_logger.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/entities/user.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _user;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await getIt<IAuthRepository>().getCurrentUser();
      if (mounted) setState(() => _user = user);
    } catch (e) {
      DebugLogger.auth('Failed to load user: $e');
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      if (getIt.isRegistered<IAuthRepository>()) {
        await getIt<IAuthRepository>().logout();
      }
    } catch (e) {
      DebugLogger.auth('Logout error (non-critical): $e');
    } finally {
      if (mounted) context.go(AppRoutes.login);
    }
  }

  void _confirmLogout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 2),
        ),
        title: const Text('Se déconnecter ?',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        content: Text(
          'Vous devrez vous reconnecter pour accéder à vos données.',
          style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _logout();
            },
            child: const Text('Se déconnecter',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.redDanger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text('Paramètres',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900)),
              ),
              _UserCard(user: _user),
              _sectionLabel('Mon chien'),
              _settingsTile(
                icon: '🐕',
                iconBg: AppColors.cream,
                title: 'Mes chiens',
                onTap: () => context.push(AppRoutes.dogList),
              ),
              _settingsTile(
                icon: '👥',
                iconBg: AppColors.blueLight,
                title: 'Accès partagés',
                onTap: () {},
              ),
              _settingsTile(
                icon: '📡',
                iconBg: AppColors.greenMint,
                title: 'Collier GPS',
                trailing: '● En ligne',
                trailingColor: AppColors.greenStatus,
                onTap: () {},
              ),
              _sectionLabel('Notifications'),
              _settingsTile(
                icon: '🔔',
                iconBg: AppColors.yellowLight,
                title: 'Alertes GPS',
                trailingWidget: _buildSwitch(true),
              ),
              _settingsTile(
                icon: '❤️',
                iconBg: AppColors.pinkLight,
                title: 'Alertes santé',
                trailingWidget: _buildSwitch(true),
              ),
              _RgpdCard(),
              _sectionLabel('Compte'),
              _LogoutButton(
                isLoading: _isLoggingOut,
                onTap: _confirmLogout,
              ),
              const SizedBox(height: 8),
              _DeleteButton(),
              const SizedBox(height: 16),
              Center(
                child: Text('K9 Sync v1.0.0-mvp',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textMuted),
      ),
    );
  }

  Widget _settingsTile({
    required String icon,
    required Color iconBg,
    required String title,
    String? trailing,
    Color? trailingColor,
    Widget? trailingWidget,
    VoidCallback? onTap,
  }) {
    final trailingContent = trailingWidget ??
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  trailing,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: trailingColor ?? AppColors.textMuted),
                ),
              ),
            Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Material(
        color: AppColors.cardBg, // explicit — no theme override
        borderRadius: AppDimensions.borderRadiusSm,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDimensions.borderRadiusSm,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: AppDimensions.borderRadiusSm,
              boxShadow: [AppDimensions.cardShadowSm],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg,
                    border:
                        Border.all(color: AppColors.border, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                      child: Text(icon,
                          style: const TextStyle(fontSize: 16))),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text))),
                trailingContent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitch(bool value) {
    return Switch(
      value: value,
      onChanged: (_) {},
      activeTrackColor: AppColors.blue,
    );
  }
}

// ── User card — real data ─────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final User? user;
  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user);
    final name = user != null
        ? '${user!.firstName} ${user!.lastName}'.trim()
        : '…';
    final email = user?.email ?? '…';
    final plan = user?.subscriptionPlan ?? 'free';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orange,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [AppDimensions.cardShadow],
      ),
      child: Row(
        children: [
          // Initials avatar
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border.all(color: AppColors.border, width: 2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.orange),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                Text(email,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              plan == 'premium' ? '⭐ Pro' : 'Free',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orange),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(User? user) {
    if (user == null) return '?';
    final f =
        user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : '';
    final l =
        user.lastName.isNotEmpty ? user.lastName[0].toUpperCase() : '';
    return '$f$l';
  }
}

// ── RGPD card ─────────────────────────────────────────────────────────────────

class _RgpdCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueLight,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadiusSm,
        boxShadow: [AppDimensions.cardShadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔒 Confidentialité & Données',
              style:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            'Gérez vos consentements, téléchargez ou supprimez vos données.',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    textStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800),
                    foregroundColor: AppColors.text,
                    side: BorderSide(color: AppColors.border, width: 2),
                  ),
                  child: const Text('📥 Télécharger'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(AppRoutes.privacy),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    textStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800),
                    foregroundColor: AppColors.text,
                    side: BorderSide(color: AppColors.border, width: 2),
                  ),
                  child: const Text('✏️ Consentements'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Logout button ─────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _LogoutButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [AppDimensions.cardShadowSm],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Se déconnecter',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800,
                          color: AppColors.text)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Delete button ─────────────────────────────────────────────────────────────

class _DeleteButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: AppColors.redLight,
        borderRadius: BorderRadius.circular(50),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(50),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.redLight,
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [AppDimensions.cardShadowSm],
            ),
            child: const Center(
              child: Text('Supprimer mon compte',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.redDanger)),
            ),
          ),
        ),
      ),
    );
  }
}
