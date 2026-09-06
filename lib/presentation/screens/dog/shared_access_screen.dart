import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/errors/app_error.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/entities/dog.dart';
import 'package:k9sync/domain/enums/user_dog_role.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/injection.dart';

const _months = [
  'jan.',
  'fév.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Accès partagés : liste réelle (GET /dogs/:dogId/users), révocation
/// (DELETE .../users/:userId) avec confirmation, bouton Inviter.
class SharedAccessScreen extends StatefulWidget {
  const SharedAccessScreen({super.key, this.dogId});
  final String? dogId;

  @override
  State<SharedAccessScreen> createState() => _SharedAccessScreenState();
}

class _SharedAccessScreenState extends State<SharedAccessScreen> {
  bool _loading = true;
  String? _error;
  Dog? _dog;
  List<UserDogAccess> _accesses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dogId = widget.dogId;
    if (dogId == null) {
      setState(() {
        _loading = false;
        _error = 'Chien introuvable.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = getIt<IDogRepository>();
      final dog = await repo.getDogById(dogId);
      final accesses = await repo.getDogUsers(dogId);
      if (!mounted) return;
      setState(() {
        _dog = dog;
        _accesses = accesses.where((a) => a.role != UserDogRole.owner).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AppError
            ? (e.userMessage ?? 'Impossible de charger les accès partagés.')
            : 'Impossible de charger les accès partagés.';
      });
    }
  }

  Future<void> _confirmRevoke(UserDogAccess access) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Révoquer cet accès ?'),
        content: Text(
          '${access.firstName} ${access.lastName} (${access.email}) perdra '
          'immédiatement l\'accès à ce chien.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.redDanger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Révoquer'),
          ),
        ],
      ),
    );

    if (confirmed != true || widget.dogId == null || !mounted) return;

    try {
      await getIt<IDogRepository>().removeUser(widget.dogId!, access.userId);
      if (!mounted) return;
      setState(() => _accesses.removeWhere((a) => a.userId == access.userId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Accès de ${access.firstName} révoqué.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is AppError
          ? (e.userMessage ?? 'Échec de la révocation.')
          : 'Échec de la révocation.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _goInvite() async {
    final dogId = widget.dogId;
    if (dogId == null) return;
    final changed = await context.push<bool>(
      '/dogs/$dogId/invite',
      extra: _dog?.name,
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Semantics(
          button: true,
          label: 'Retour',
          child: IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
            onPressed: () => context.pop(),
          ),
        ),
        title: const Text(
          'Accès partagés',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: 'Inviter quelqu\'un à accéder à ce chien',
            child: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.blueLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: AppColors.blue, size: 20),
              ),
              onPressed: _goInvite,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final family = _accesses
        .where((a) => a.role == UserDogRole.family)
        .toList();
    final sitters = _accesses
        .where((a) => a.role == UserDogRole.dogSitter)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border, width: 1),
                borderRadius: AppDimensions.borderRadiusSm,
                boxShadow: [AppDimensions.cardShadowSm],
              ),
              child: Row(
                children: [
                  const Text('🐕', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dog?.name ?? 'Ce chien',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Gestion des accès partagés',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (family.isEmpty && sitters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Text(
                'Personne d\'autre n\'a accès à ce chien pour l\'instant.',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ),
          if (family.isNotEmpty) ...[
            _sectionLabel('Famille · accès permanent'),
            for (var i = 0; i < family.length; i++) ...[
              _sharedUserTile(family[i]),
              if (i < family.length - 1) _divider(),
            ],
          ],
          if (sitters.isNotEmpty) ...[
            _sectionLabel('Dog-sitters · accès temporaire'),
            for (var i = 0; i < sitters.length; i++) ...[
              _sharedUserTile(sitters[i]),
              if (i < sitters.length - 1) _divider(),
            ],
          ],
          _sectionLabel('Partage vétérinaire'),
          _vetExportTile(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _goInvite,
                child: const Text('+ Inviter quelqu\'un'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _sharedUserTile(UserDogAccess access) {
    final isSitter = access.role == UserDogRole.dogSitter;
    final roleLabel = isSitter ? 'Dog-sitter' : 'Famille';
    final roleColor = isSitter ? AppColors.orange : AppColors.greenStatus;
    final sub = isSitter && access.expiresAt != null
        ? 'Expire le ${_formatDate(access.expiresAt!)}'
        : access.email;

    return Semantics(
      button: true,
      label:
          'Révoquer l\'accès de ${access.firstName} ${access.lastName}, '
          '$roleLabel — action destructive, retire immédiatement l\'accès '
          'à ce chien',
      child: Material(
        color: AppColors.cardBg,
        child: InkWell(
          onTap: () => _confirmRevoke(access),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.blue, AppColors.blueLight],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      access.firstName.isNotEmpty
                          ? access.firstName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${access.firstName} ${access.lastName}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isSitter
                        ? AppColors.orangeLight
                        : AppColors.greenMint,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: roleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.person_remove_outlined,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vetExportTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        button: true,
        enabled: false,
        label: 'Export vétérinaire au format PDF, bientôt disponible',
        child: Material(
          color: AppColors.cardBg,
          borderRadius: AppDimensions.borderRadiusSm,
          child: InkWell(
            onTap: () {},
            borderRadius: AppDimensions.borderRadiusSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, width: 1),
                borderRadius: AppDimensions.borderRadiusSm,
                boxShadow: [AppDimensions.cardShadowSm],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.blueLight,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [AppDimensions.cardShadowSm],
                    ),
                    child: const Icon(
                      Icons.medical_services_outlined,
                      color: AppColors.blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export vétérinaire (PDF)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          'Bientôt disponible',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: AppColors.border,
    );
  }
}
