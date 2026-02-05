import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:k9sync/core/theme/app_theme.dart';
import '../bloc/alerts_bloc.dart';

/// Alerts screen with tab filter and quick settings (Figma design).
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

class _AlertsView extends StatelessWidget {
  const _AlertsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const _TabRow(),
              const SizedBox(height: 20),
              _buildAlertCard(
                context,
                category: 'SÉCURITÉ',
                categoryColor: AppColors.cardSecurity,
                title: 'Bucky a franchi la clôture',
                subtitle: 'Il y a 5 min • Jardin arrière',
                buttonLabel: 'Voir la carte',
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              _buildAlertCard(
                context,
                category: 'SANTÉ',
                categoryColor: AppColors.cardHealth,
                title: 'Fréquence cardiaque élevée',
                subtitle: 'Il y a 15 min • Au repos',
                buttonLabel: 'Détails vitaux',
                onPressed: () {},
                trailing: Icon(Icons.pets, color: Colors.brown.shade300, size: 28),
              ),
              const SizedBox(height: 12),
              _buildAlertCard(
                context,
                category: 'ACTIVITÉ',
                categoryColor: AppColors.cardActivity,
                title: 'Sommeil inhabituel',
                subtitle: 'Hier soir • Agitation à 3h',
                buttonLabel: 'Analyse du sommeil',
                onPressed: () {},
              ),
              const SizedBox(height: 28),
              _buildSectionTitle(context, 'CONFIGURATION RAPIDE'),
              const SizedBox(height: 16),
              const _ConfigToggles(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context, {
    required String category,
    required Color categoryColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: categoryColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                category,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.check_circle_outline, size: 22, color: Colors.grey.shade600),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertsBloc, AlertsState>(
      buildWhen: (prev, curr) => prev.selectedTabIndex != curr.selectedTabIndex,
      builder: (context, state) {
        return Row(
          children: [
            _TabChip(
              label: 'Toutes',
              selected: state.selectedTabIndex == 0,
              onTap: () => context.read<AlertsBloc>().add(const AlertsTabChanged(0)),
            ),
            const SizedBox(width: 12),
            _TabChip(
              label: 'Prioritaires',
              selected: state.selectedTabIndex == 1,
              onTap: () => context.read<AlertsBloc>().add(const AlertsTabChanged(1)),
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

  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigToggles extends StatelessWidget {
  const _ConfigToggles();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlertsBloc, AlertsState>(
      buildWhen: (prev, curr) =>
          prev.silentMode != curr.silentMode || prev.realtimeTracking != curr.realtimeTracking,
      builder: (context, state) {
        return Column(
          children: [
            _ConfigToggle(
              icon: Icons.notifications_off_outlined,
              label: 'Mode Silencieux',
              value: state.silentMode,
              onChanged: (v) => context.read<AlertsBloc>().add(AlertsSilentModeChanged(v)),
            ),
            const SizedBox(height: 12),
            _ConfigToggle(
              icon: Icons.location_on_outlined,
              label: 'Suivi Temps Réel',
              value: state.realtimeTracking,
              onChanged: (v) => context.read<AlertsBloc>().add(AlertsRealtimeTrackingChanged(v)),
            ),
          ],
        );
      },
    );
  }
}

class _ConfigToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ConfigToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
