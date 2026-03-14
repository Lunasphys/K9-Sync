import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/entities/dog.dart';
import 'package:k9sync/presentation/providers/dog_provider.dart';

/// Dog profile screen — reads GET /dogs/:dogId via [dogProvider].
/// Navigates to DogEditScreen on the edit button.
class DogProfileScreen extends ConsumerWidget {
  final String? dogId;
  const DogProfileScreen({super.key, required this.dogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (dogId == null) {
      return const _ErrorScaffold(message: 'Identifiant chien manquant.');
    }

    final state = ref.watch(dogProvider(dogId!));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          state.dog?.name ?? 'Profil',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
        actions: [
          if (state.dog != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: () => context.push('/dogs/$dogId/edit'),
                child: Text(
                  'Modifier',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: switch (state.status) {
        DogLoadStatus.initial || DogLoadStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
        DogLoadStatus.error => _ErrorBody(
            message: state.errorMessage ?? 'Erreur inconnue.',
            onRetry: () => ref.read(dogProvider(dogId!).notifier).load(),
          ),
        _ => _ProfileBody(dog: state.dog!),
      },
    );
  }
}

// ── Profile body ──────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final Dog dog;
  const _ProfileBody({required this.dog});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AvatarCard(dog: dog),
        const SizedBox(height: 16),
        _InfoSection(dog: dog),
        const SizedBox(height: 16),
        _AllergiesSection(allergies: dog.allergies),
        const SizedBox(height: 16),
        _ActionsSection(dogId: dog.id),
      ],
    );
  }
}

// ── Avatar card ───────────────────────────────────────────────────────────────

class _AvatarCard extends StatelessWidget {
  final Dog dog;
  const _AvatarCard({required this.dog});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadius,
        boxShadow: [AppDimensions.cardShadow],
      ),
      child: Column(
        children: [
          // Avatar — photo or emoji fallback
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.cream,
              border: Border.all(color: AppColors.border, width: 2),
              shape: BoxShape.circle,
            ),
            child: dog.photoUrl != null && dog.photoUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      dog.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Text('🐕', style: TextStyle(fontSize: 44)),
                      ),
                    ),
                  )
                : const Center(
                    child: Text('🐕', style: TextStyle(fontSize: 44)),
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            dog.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          if (dog.breed != null) ...[
            const SizedBox(height: 4),
            Text(
              dog.breed!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Quick stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _QuickStat(
                label: 'Âge',
                value: dog.birthDate != null
                    ? '${_ageInYears(dog.birthDate!)} ans'
                    : '—',
              ),
              _Divider(),
              _QuickStat(
                label: 'Poids',
                value: dog.weight != null
                    ? '${dog.weight!.toStringAsFixed(1)} kg'
                    : '—',
              ),
              _Divider(),
              _QuickStat(
                label: 'Sexe',
                value: _sexLabel(dog.sex),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _ageInYears(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }

  String _sexLabel(DogSex? sex) {
    return switch (sex) {
      DogSex.male => '♂ Mâle',
      DogSex.female => '♀ Femelle',
      _ => '—',
    };
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  const _QuickStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: AppColors.border);
  }
}

// ── Info section ──────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final Dog dog;
  const _InfoSection({required this.dog});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('Informations'),
          const SizedBox(height: 12),
          _InfoRow('Race', dog.breed ?? '—'),
          _InfoRow(
            'Date de naissance',
            dog.birthDate != null
                ? '${dog.birthDate!.day.toString().padLeft(2, '0')}/'
                    '${dog.birthDate!.month.toString().padLeft(2, '0')}/'
                    '${dog.birthDate!.year}'
                : '—',
          ),
          _InfoRow(
            'Poids',
            dog.weight != null
                ? '${dog.weight!.toStringAsFixed(1)} kg'
                : '—',
          ),
          _InfoRow('Sexe', _sexFull(dog.sex)),
        ],
      ),
    );
  }

  String _sexFull(DogSex? sex) => switch (sex) {
        DogSex.male => 'Mâle',
        DogSex.female => 'Femelle',
        _ => '—',
      };
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Allergies section ─────────────────────────────────────────────────────────

class _AllergiesSection extends StatelessWidget {
  final List<String> allergies;
  const _AllergiesSection({required this.allergies});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('Allergies'),
          const SizedBox(height: 12),
          if (allergies.isEmpty)
            Text(
              'Aucune allergie connue.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allergies
                  .map((a) => _AllergyChip(label: a))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _AllergyChip extends StatelessWidget {
  final String label;
  const _AllergyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        border: Border.all(color: AppColors.orange, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.orange,
        ),
      ),
    );
  }
}

// ── Actions section ───────────────────────────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  final String dogId;
  const _ActionsSection({required this.dogId});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('Actions'),
          const SizedBox(height: 12),
          _ActionTile(
            icon: '📋',
            label: 'Accès partagés',
            subtitle: 'Famille, dog-sitter',
            onTap: () => context.push('/dogs/$dogId/shared-access'),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: '📡',
            label: 'Statut du collier',
            subtitle: 'Batterie, connexion, firmware',
            onTap: () => context.push('/collar/$dogId'),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: '📄',
            label: 'Exporter les données santé',
            subtitle: 'Rapport PDF pour le vétérinaire',
            onTap: () {
              // PDF export — to implement
            },
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: AppDimensions.borderRadiusSm,
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w900)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadius,
        boxShadow: [AppDimensions.cardShadow],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😕', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Center(
        child: Text(message,
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

