import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/presentation/providers/lost_mode_provider.dart';

import '../bloc/alerts_bloc.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AlertsBloc(),
      child: const _AlertsView(),
    );
  }
}

class _AlertsView extends ConsumerWidget {
  const _AlertsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLost = ref.watch(lostModeProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        title: BlocBuilder<AlertsBloc, AlertsState>(
          buildWhen: (p, c) => p.unreadCount != c.unreadCount,
          builder: (context, state) {
            return Row(
              children: [
                const Text('Alertes',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18)),
                if (state.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${state.unreadCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          BlocBuilder<AlertsBloc, AlertsState>(
            buildWhen: (p, c) => p.unreadCount != c.unreadCount,
            builder: (context, state) {
              if (state.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => context
                    .read<AlertsBloc>()
                    .add(const AlertsAllMarkedRead()),
                child: const Text('Tout lire',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isLost) const LostModeBanner(),
            // ── Tab row ──────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _TabRow(),
            ),
            // ── Alert list ───────────────────────────────────────────
            Expanded(
              child: BlocBuilder<AlertsBloc, AlertsState>(
                builder: (context, state) {
                  final alerts = state.visibleAlerts;
                  if (alerts.isEmpty) {
                    return _EmptyState(
                        isPriorityTab: state.selectedTabIndex == 1);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: alerts.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _AlertCard(alert: alerts[index]);
                    },
                  );
                },
              ),
            ),
            // ── Config toggles ───────────────────────────────────────
            const _ConfigSection(),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isPriorityTab;
  const _EmptyState({required this.isPriorityTab});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isPriorityTab ? '✅' : '🔔',
              style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            isPriorityTab
                ? 'Aucune alerte prioritaire'
                : 'Aucune alerte pour l\'instant',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            isPriorityTab
                ? 'Tout va bien !'
                : 'Les alertes MQTT apparaîtront ici.',
            style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Alert card ────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final AlertItem alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(alert.category);

    return GestureDetector(
      onTap: () => context
          .read<AlertsBloc>()
          .add(AlertMarkedRead(alert.id)),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: alert.isRead ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: alert.isRead
                ? AppColors.cardBg
                : colors.bg,
            border: Border.all(
              color: alert.isRead
                  ? AppColors.border
                  : colors.border,
              width: 2,
            ),
            borderRadius: AppDimensions.borderRadius,
            boxShadow: alert.isRead ? [] : [AppDimensions.cardShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.badge,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _labelFor(alert.category),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (alert.isPriority)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('PRIORITAIRE',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  const Spacer(),
                  Text(
                    _ago(alert.triggeredAt),
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600),
                  ),
                  if (!alert.isRead) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                alert.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: alert.isRead
                      ? AppColors.textMuted
                      : AppColors.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                alert.subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Il y a ${diff.inSeconds}s';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
    return 'Il y a ${diff.inHours}h';
  }

  String _labelFor(AlertCategory cat) {
    switch (cat) {
      case AlertCategory.security:
        return 'SÉCURITÉ';
      case AlertCategory.health:
        return 'SANTÉ';
      case AlertCategory.activity:
        return 'ACTIVITÉ';
      case AlertCategory.system:
        return 'SYSTÈME';
    }
  }

  _AlertColors _colorsFor(AlertCategory cat) {
    switch (cat) {
      case AlertCategory.security:
        return _AlertColors(
          bg: const Color(0xFFFFF3E0),
          border: const Color(0xFFFFB74D),
          badge: Colors.orange,
        );
      case AlertCategory.health:
        return _AlertColors(
          bg: const Color(0xFFFFF0F0),
          border: const Color(0xFFEF9A9A),
          badge: Colors.red,
        );
      case AlertCategory.activity:
        return _AlertColors(
          bg: const Color(0xFFE8F5E9),
          border: const Color(0xFF81C784),
          badge: Colors.green,
        );
      case AlertCategory.system:
        return _AlertColors(
          bg: const Color(0xFFE3F2FD),
          border: const Color(0xFF90CAF9),
          badge: Colors.blue,
        );
    }
  }
}

class _AlertColors {
  final Color bg;
  final Color border;
  final Color badge;
  const _AlertColors(
      {required this.bg, required this.border, required this.badge});
}

// ── Tab row ───────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertsBloc, AlertsState>(
      buildWhen: (p, c) => p.selectedTabIndex != c.selectedTabIndex,
      builder: (context, state) {
        return Row(
          children: [
            _TabChip(
              label: 'Toutes',
              selected: state.selectedTabIndex == 0,
              onTap: () => context
                  .read<AlertsBloc>()
                  .add(const AlertsTabChanged(0)),
            ),
            const SizedBox(width: 10),
            _TabChip(
              label: 'Prioritaires',
              selected: state.selectedTabIndex == 1,
              onTap: () => context
                  .read<AlertsBloc>()
                  .add(const AlertsTabChanged(1)),
            ),
          ],
        );
      },
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : AppColors.cardBg,
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}

// ── Config section ────────────────────────────────────────────────────────────

class _ConfigSection extends StatelessWidget {
  const _ConfigSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border:
            Border(top: BorderSide(color: AppColors.border, width: 2)),
      ),
      child: BlocBuilder<AlertsBloc, AlertsState>(
        buildWhen: (p, c) =>
            p.silentMode != c.silentMode ||
            p.realtimeTracking != c.realtimeTracking,
        builder: (context, state) {
          return Column(
            children: [
              _ConfigToggle(
                icon: Icons.notifications_off_outlined,
                label: 'Mode Silencieux',
                subtitle: 'Désactive les nouvelles alertes',
                value: state.silentMode,
                onChanged: (v) => context
                    .read<AlertsBloc>()
                    .add(AlertsSilentModeChanged(v)),
              ),
              const SizedBox(height: 8),
              _ConfigToggle(
                icon: Icons.location_on_outlined,
                label: 'Suivi Temps Réel',
                subtitle: 'Position GPS continue',
                value: state.realtimeTracking,
                onChanged: (v) => context
                    .read<AlertsBloc>()
                    .add(AlertsRealtimeTrackingChanged(v)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConfigToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConfigToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadiusSm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.orange,
          ),
        ],
      ),
    );
  }
}

class LostModeBanner extends ConsumerWidget {
  const LostModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(lostModeProvider);
    if (!isActive) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/lost-mode'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          border: Border.all(color: Colors.red.shade400, width: 2),
          borderRadius: AppDimensions.borderRadiusSm,
        ),
        child: Row(
          children: [
            const Text('🚨', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mode chien perdu actif',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    'Le collier émet un signal. Appuyez pour gérer.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.red.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

