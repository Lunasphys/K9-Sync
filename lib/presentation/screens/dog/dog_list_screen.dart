import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/entities/dog.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

// Fetch dogs from GET /dogs
final dogsProvider = FutureProvider<List<Dog>>((ref) async {
  return getIt<IDogRepository>().getDogs();
});

class DogListScreen extends ConsumerWidget {
  const DogListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dogsAsync = ref.watch(dogsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: _BackBtn(),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.homeProfil);
            }
          },
        ),
        title: const Text(
          'Mes chiens',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add, color: AppColors.blue, size: 20),
            ),
            onPressed: () {}, // TODO: add dog flow
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dogsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(
          message: e.toString(),
          onRetry: () => ref.invalidate(dogsProvider),
        ),
        data: (dogs) => _DogListBody(dogs: dogs),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _DogListBody extends StatelessWidget {
  final List<Dog> dogs;
  const _DogListBody({required this.dogs});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dogs.isEmpty)
            _EmptyState()
          else ...[
            ...dogs.map((dog) => _DogCard(dog: dog)),
          ],
          _AddDogCard(),
        ],
      ),
    );
  }
}

// ── Dog card ──────────────────────────────────────────────────────────────────

class _DogCard extends StatelessWidget {
  final Dog dog;
  const _DogCard({required this.dog});

  @override
  Widget build(BuildContext context) {
    // Collar online status — not available from /dogs directly, show neutral
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: AppColors.cardBg,
        borderRadius: AppDimensions.borderRadius,
        child: InkWell(
          onTap: () => context.push('/dogs/${dog.id}'),
          borderRadius: AppDimensions.borderRadius,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: AppDimensions.borderRadius,
              boxShadow: [AppDimensions.cardShadowSm],
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 64,
                  height: 64,
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
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('🐕',
                                  style: TextStyle(fontSize: 28)),
                            ),
                          ),
                        )
                      : const Center(
                          child: Text('🐕',
                              style: TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dog.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (dog.breed != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _breedAge(dog),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _breedAge(Dog dog) {
    final parts = <String>[];
    if (dog.breed != null) parts.add(dog.breed!);
    if (dog.birthDate != null) {
      final age = DateTime.now().year - dog.birthDate!.year;
      parts.add('$age ans');
    }
    return parts.join(' · ');
  }
}

// ── Add dog card ──────────────────────────────────────────────────────────────

class _AddDogCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: AppDimensions.borderRadius,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.blueLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                  child: Text('➕', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ajouter un chien',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                  Text('Associer un nouveau collier',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const Text('🐾', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text('Aucun chien pour l\'instant',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Ajoutez votre premier chien ci-dessous',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

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
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class _BackBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.arrow_back,
          size: 18, color: AppColors.textMuted),
    );
  }
}
