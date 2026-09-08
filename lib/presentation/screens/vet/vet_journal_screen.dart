import 'package:flutter/material.dart';
import 'package:k9sync/core/errors/app_error.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/entities/vet_record.dart';
import 'package:k9sync/domain/enums/user_dog_role.dart';
import 'package:k9sync/domain/interfaces/repositories/i_auth_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/domain/interfaces/repositories/i_vet_record_repository.dart';
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

/// Journal vétérinaire — rendez-vous et rappels génériques (pas de type
/// vaccin/antiparasitaire/etc., pas de récurrence). Owner/family gèrent le
/// carnet, un dog_sitter y a un accès lecture seule (cohérent avec le
/// backend — voir requireDogAccess.excludeDogSitter).
class VetJournalScreen extends StatefulWidget {
  const VetJournalScreen({super.key});

  @override
  State<VetJournalScreen> createState() => _VetJournalScreenState();
}

class _VetJournalScreenState extends State<VetJournalScreen> {
  bool _loading = true;
  String? _error;
  String? _dogId;
  String _dogName = 'ce chien';
  UserDogRole? _myRole;
  List<VetRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _canManage => _myRole != UserDogRole.dogSitter;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await getIt<IAuthRepository>().getCurrentUser();
      if (user == null) throw StateError('not authenticated');

      final dogRepo = getIt<IDogRepository>();
      final dogs = await dogRepo.getDogs();
      if (dogs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Aucun chien enregistré.';
        });
        return;
      }
      final dogId = dogs.first.id;

      final accesses = await dogRepo.getDogUsers(dogId);
      UserDogRole? myRole;
      for (final a in accesses) {
        if (a.userId == user.id) {
          myRole = a.role;
          break;
        }
      }

      final records = await getIt<IVetRecordRepository>().getVetRecords(
        dogId,
      );

      if (!mounted) return;
      setState(() {
        _dogId = dogId;
        _dogName = dogs.first.name;
        _myRole = myRole ?? UserDogRole.dogSitter; // fail-safe: unknown → read-only
        _records = records;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AppError
            ? (e.userMessage ?? 'Impossible de charger le carnet vétérinaire.')
            : 'Impossible de charger le carnet vétérinaire.';
      });
    }
  }

  Future<void> _openAddSheet() async {
    final dogId = _dogId;
    if (dogId == null) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddVetRecordSheet(dogId: dogId),
    );
    if (created == true) _load();
  }

  Future<void> _openRecordSheet(VetRecord record) async {
    final dogId = _dogId;
    if (dogId == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VetRecordActionsSheet(
        dogId: dogId,
        record: record,
        canManage: _canManage,
      ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Journal vét.',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
            Text(
              _dogName,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          if (_canManage)
            Semantics(
              button: true,
              label: 'Ajouter un rendez-vous ou rappel vétérinaire',
              child: IconButton(
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    border: Border.all(color: AppColors.border, width: 2),
                    shape: BoxShape.circle,
                    boxShadow: [AppDimensions.cardShadowSm],
                  ),
                  child: const Icon(Icons.add),
                ),
                onPressed: _openAddSheet,
              ),
            ),
          const SizedBox(width: 16),
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

    if (_records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏥', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                'Carnet vide pour l\'instant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                _canManage
                    ? 'Appuie sur + pour ajouter un rendez-vous ou un rappel.'
                    : 'Aucun rendez-vous ni rappel enregistré pour le moment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sections = VetJournalSections.from(_records);
    final upcoming = sections.upcoming;
    final history = sections.history;
    final nextUp = upcoming.isNotEmpty ? upcoming.first : null;
    final restUp = upcoming.length > 1
        ? upcoming.sublist(1)
        : const <VetRecord>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (nextUp != null)
            _NextAppointmentCard(
              record: nextUp,
              onTap: () => _openRecordSheet(nextUp),
            )
          else
            _emptyHint('Aucun rendez-vous à venir.'),
          if (restUp.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionTitle('Autres rendez-vous à venir'),
            const SizedBox(height: 8),
            for (final r in restUp)
              _VetEntryTile(
                record: r,
                upcoming: true,
                onTap: () => _openRecordSheet(r),
              ),
          ],
          const SizedBox(height: 20),
          _sectionTitle('Historique'),
          const SizedBox(height: 8),
          if (history.isEmpty)
            _emptyHint('Aucun historique pour l\'instant.')
          else
            for (final r in history)
              _VetEntryTile(
                record: r,
                upcoming: false,
                onTap: () => _openRecordSheet(r),
              ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w900,
      color: AppColors.text,
    ),
  );

  Widget _emptyHint(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      color: AppColors.textMuted,
      fontWeight: FontWeight.w600,
    ),
  );
}

// ── "Prochain RDV" hero card ─────────────────────────────────────────────────

class _NextAppointmentCard extends StatelessWidget {
  final VetRecord record;
  final VoidCallback onTap;
  const _NextAppointmentCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'Prochain rendez-vous : ${record.title}, le ${_formatDate(record.date)}. '
          'Voir les détails',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.greenMint,
              border: Border.all(color: AppColors.border, width: 2),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [AppDimensions.cardShadow],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    border: Border.all(color: AppColors.border, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🏥', style: TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prochain RDV',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        record.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _formatDate(record.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Entry tile (upcoming or history) ─────────────────────────────────────────

class _VetEntryTile extends StatelessWidget {
  final VetRecord record;
  final bool upcoming;
  final VoidCallback onTap;

  const _VetEntryTile({
    required this.record,
    required this.upcoming,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = upcoming ? AppColors.blue : AppColors.greenStatus;
    final statusLabel = upcoming ? 'à venir' : 'fait';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label:
            '${record.title}, ${_formatDate(record.date)}, $statusLabel'
            '${record.notes != null && record.notes!.isNotEmpty ? ", notes : ${record.notes}" : ''}. '
            'Voir les détails',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppDimensions.borderRadiusSm,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                border: Border.all(color: AppColors.border, width: 2),
                borderRadius: AppDimensions.borderRadiusSm,
                boxShadow: [AppDimensions.cardShadowSm],
              ),
              child: Row(
                children: [
                  Icon(
                    upcoming
                        ? Icons.event_outlined
                        : Icons.check_circle_outline,
                    color: accent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatDate(record.date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (record.notes != null && record.notes!.isNotEmpty)
                          Text(
                            record.notes!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Add-record bottom sheet ───────────────────────────────────────────────────

class _AddVetRecordSheet extends StatefulWidget {
  final String dogId;
  const _AddVetRecordSheet({required this.dogId});

  @override
  State<_AddVetRecordSheet> createState() => _AddVetRecordSheetState();
}

class _AddVetRecordSheetState extends State<_AddVetRecordSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _submitting = false;
  String? _error;

  bool get _canSubmit => _titleController.text.trim().isNotEmpty && !_submitting;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final notes = _notesController.text.trim();
    try {
      await getIt<IVetRecordRepository>().createVetRecord(
        widget.dogId,
        title: _titleController.text.trim(),
        date: _date,
        notes: notes.isEmpty ? null : notes,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is AppError
            ? (e.userMessage ?? 'Échec de la création.')
            : 'Échec de la création.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Nouveau rendez-vous',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            _label('TITRE'),
            Semantics(
              textField: true,
              label: 'Titre du rendez-vous ou rappel',
              child: TextField(
                controller: _titleController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ex. Vaccin annuel, Contrôle dentaire...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: AppDimensions.borderRadiusSm,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _label('DATE'),
            Semantics(
              button: true,
              label: 'Date du rendez-vous : ${_formatDate(_date)}. Modifier',
              child: InkWell(
                onTap: _pickDate,
                borderRadius: AppDimensions.borderRadiusSm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border, width: 1.5),
                    borderRadius: AppDimensions.borderRadiusSm,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _formatDate(_date),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _label('NOTES (OPTIONNEL)'),
            Semantics(
              textField: true,
              label: 'Notes optionnelles',
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Détails, remarques...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: AppDimensions.borderRadiusSm,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: AppColors.redDanger, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            Semantics(
              button: true,
              enabled: _canSubmit,
              label: _canSubmit
                  ? 'Enregistrer le rendez-vous'
                  : 'Enregistrer — indisponible tant que le titre n\'est pas renseigné',
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    ),
  );
}

// ── Entry detail / actions bottom sheet ───────────────────────────────────────

class _VetRecordActionsSheet extends StatefulWidget {
  final String dogId;
  final VetRecord record;
  final bool canManage;

  const _VetRecordActionsSheet({
    required this.dogId,
    required this.record,
    required this.canManage,
  });

  @override
  State<_VetRecordActionsSheet> createState() =>
      _VetRecordActionsSheetState();
}

class _VetRecordActionsSheetState extends State<_VetRecordActionsSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _markDone() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await getIt<IVetRecordRepository>().updateVetRecord(
        widget.dogId,
        widget.record.id,
        done: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AppError
            ? (e.userMessage ?? 'Échec de la mise à jour.')
            : 'Échec de la mise à jour.';
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette entrée ?'),
        content: Text(
          '« ${widget.record.title} » sera définitivement supprimée du carnet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.redDanger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await getIt<IVetRecordRepository>().deleteVetRecord(
        widget.dogId,
        widget.record.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AppError
            ? (e.userMessage ?? 'Échec de la suppression.')
            : 'Échec de la suppression.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            r.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            r.done
                ? '${_formatDate(r.date)} · fait'
                : '${_formatDate(r.date)} · à venir',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (r.notes != null && r.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border, width: 1),
                borderRadius: AppDimensions.borderRadiusSm,
              ),
              child: Text(
                r.notes!,
                style: TextStyle(fontSize: 13, color: AppColors.text),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: AppColors.redDanger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 18),
          if (widget.canManage) ...[
            if (!r.done)
              Semantics(
                button: true,
                label: 'Marquer « ${r.title} » comme fait',
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _markDone,
                    icon: const Icon(Icons.check),
                    label: const Text('Marquer comme fait'),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label:
                  'Supprimer « ${r.title} » du carnet — action irréversible',
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _confirmDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.redDanger,
                  ),
                  label: const Text(
                    'Supprimer',
                    style: TextStyle(color: AppColors.redDanger),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.redDanger),
                  ),
                ),
              ),
            ),
          ] else
            Text(
              'Accès en lecture seule — seuls le propriétaire et la famille '
              'peuvent modifier le carnet vétérinaire.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}
