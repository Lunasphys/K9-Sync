import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:k9sync/core/debug/debug_logger.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/entities/dog.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/providers/dog_provider.dart';
import 'package:k9sync/presentation/screens/dog/dog_breeds.dart';

/// Dog edit screen — PATCH /dogs/:dogId via [dogProvider.notifier.save].
class DogEditScreen extends ConsumerStatefulWidget {
  final String dogId;
  const DogEditScreen({super.key, required this.dogId});

  @override
  ConsumerState<DogEditScreen> createState() => _DogEditScreenState();
}

class _DogEditScreenState extends ConsumerState<DogEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _customBreedCtrl = TextEditingController();

  String? _selectedBreed;
  double _weight = 10.0;
  DateTime? _birthDate;
  DogSex? _sex;

  File? _newPhoto;
  bool _uploading = false;
  String? _photoUrl;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customBreedCtrl.dispose();
    super.dispose();
  }

  void _initFromDog(Dog dog) {
    if (_initialized) return;
    _nameCtrl.text = dog.name;
    _weight = dog.weight ?? 10.0;
    _birthDate = dog.birthDate;
    _sex = dog.sex;
    _photoUrl = dog.photoUrl;

    if (dog.breed != null) {
      if (DogBreeds.all.contains(dog.breed)) {
        _selectedBreed = dog.breed;
      } else {
        _selectedBreed = 'Autre';
        _customBreedCtrl.text = dog.breed!;
      }
    }
    _initialized = true;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() {
      _newPhoto = File(picked.path);
      _uploading = true;
    });

    try {
      final dio = getIt<Dio>();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(picked.path,
            filename: 'dog_photo.jpg'),
      });
      final response = await dio
          .post<Map<String, dynamic>>('/upload/dog-photo', data: formData);
      setState(() => _photoUrl = response.data?['url'] as String?);
    } catch (e) {
      DebugLogger.log('UPLOAD', 'Photo upload failed: $e',
          level: LogLevel.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur upload photo.'),
          backgroundColor: Colors.red,
        ));
      }
      setState(() => _newPhoto = null);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 3),
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Date de naissance',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.orange,
            onPrimary: Colors.white,
            surface: AppColors.cardBg,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final breed = _selectedBreed == 'Autre'
        ? (_customBreedCtrl.text.trim().isEmpty
            ? null
            : _customBreedCtrl.text.trim())
        : _selectedBreed;

    final ok = await ref.read(dogProvider(widget.dogId).notifier).save(
          name: _nameCtrl.text.trim(),
          breed: breed,
          weight: _weight,
          birthDate: _birthDate,
          sex: _sex?.name,
          photoUrl: _photoUrl,
        );

    if (!mounted) return;
    if (ok) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur lors de la sauvegarde.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dogProvider(widget.dogId));
    final isSaving = state.status == DogLoadStatus.saving;

    if (state.dog != null) _initFromDog(state.dog!);

    if (!_initialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modifier')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Modifier le profil',
            style:
                TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.border),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: isSaving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2)),
                  )
                : TextButton(
                    onPressed: _submit,
                    child: Text('Enregistrer',
                        style: TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w900)),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: _PhotoPicker(
                newPhoto: _newPhoto,
                existingUrl: _photoUrl,
                uploading: _uploading,
                onTap: _pickPhoto,
              ),
            ),
            const SizedBox(height: 24),

            _FormCard(children: [
              _FieldLabel('Nom *'),
              _buildNameField(),
              const SizedBox(height: 16),
              _FieldLabel('Race'),
              _buildBreedDropdown(),
              if (_selectedBreed == 'Autre') ...[
                const SizedBox(height: 10),
                _buildCustomBreedField(),
              ],
            ]),
            const SizedBox(height: 16),

            _FormCard(children: [
              _FieldLabel('Sexe'),
              const SizedBox(height: 8),
              _SexSelector(
                selected: _sex,
                onChanged: (v) => setState(() => _sex = v),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Date de naissance'),
              const SizedBox(height: 8),
              _DatePickerTile(
                date: _birthDate,
                onTap: _pickDate,
              ),
            ]),
            const SizedBox(height: 16),

            _FormCard(children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _FieldLabel('Poids'),
                  Text(
                    '${_weight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _WeightSlider(
                value: _weight,
                onChanged: (v) => setState(() => _weight = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0.5 kg',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                  Text('80 kg',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() => TextFormField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Requis';
          if (v.trim().length < 2) return 'Minimum 2 caractères';
          if (v.trim().length > 30) return 'Maximum 30 caractères';
          final validName = RegExp(r"^[a-zA-ZÀ-ÿ\s'\-]+$");
          if (!validName.hasMatch(v.trim())) return 'Lettres uniquement';
          return null;
        },
        style:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        decoration: _inputDecoration('Ex : Bucky'),
      );

  Widget _buildBreedDropdown() => DropdownButtonFormField<String>(
        value: _selectedBreed,
        hint: Text('Sélectionner une race',
            style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600)),
        decoration: _inputDecoration(''),
        isExpanded: true,
        items: DogBreeds.all
            .map((b) => DropdownMenuItem(
                  value: b,
                  child: Text(b,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ))
            .toList(),
        onChanged: (v) => setState(() {
          _selectedBreed = v;
          if (v != 'Autre') _customBreedCtrl.clear();
        }),
      );

  Widget _buildCustomBreedField() => TextFormField(
        controller: _customBreedCtrl,
        textCapitalization: TextCapitalization.words,
        validator: (v) {
          if (_selectedBreed == 'Autre' &&
              (v == null || v.trim().isEmpty)) {
            return 'Précisez la race';
          }
          return null;
        },
        style:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        decoration: _inputDecoration('Précisez la race...'),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: AppColors.textMuted, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: AppColors.bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusSm,
          borderSide: BorderSide(color: AppColors.border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusSm,
          borderSide: BorderSide(color: AppColors.border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusSm,
          borderSide: BorderSide(color: AppColors.orange, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.borderRadiusSm,
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      );
}

class _PhotoPicker extends StatelessWidget {
  final File? newPhoto;
  final String? existingUrl;
  final bool uploading;
  final VoidCallback onTap;
  const _PhotoPicker({
    required this.newPhoto,
    required this.existingUrl,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.cream,
              border: Border.all(color: AppColors.border, width: 2),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: uploading
                  ? const Center(child: CircularProgressIndicator())
                  : newPhoto != null
                      ? Image.file(newPhoto!, fit: BoxFit.cover)
                      : existingUrl != null && existingUrl!.isNotEmpty
                          ? Image.network(existingUrl!, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                    child: Text('🐕',
                                        style:
                                            TextStyle(fontSize: 36)),
                                  ))
                          : const Center(
                              child: Text('🐕',
                                  style: TextStyle(fontSize: 36))),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt,
                  size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SexSelector extends StatelessWidget {
  final DogSex? selected;
  final ValueChanged<DogSex?> onChanged;
  const _SexSelector(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _SexChip(
        label: '♂ Mâle',
        selected: selected == DogSex.male,
        onTap: () =>
            onChanged(selected == DogSex.male ? null : DogSex.male),
      ),
      const SizedBox(width: 10),
      _SexChip(
        label: '♀ Femelle',
        selected: selected == DogSex.female,
        onTap: () => onChanged(
            selected == DogSex.female ? null : DogSex.female),
      ),
    ]);
  }
}

class _SexChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SexChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : AppColors.bg,
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.text,
            )),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  const _DatePickerTile({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border, width: 2),
          borderRadius: AppDimensions.borderRadiusSm,
        ),
        child: Row(children: [
          Icon(Icons.calendar_today,
              size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              date != null
                  ? '${date!.day.toString().padLeft(2, '0')}/'
                      '${date!.month.toString().padLeft(2, '0')}/'
                      '${date!.year}'
                  : 'Sélectionner une date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: date != null
                    ? AppColors.text
                    : AppColors.textMuted,
              ),
            ),
          ),
          Icon(Icons.chevron_right,
              size: 18, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

class _WeightSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const _WeightSlider(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppColors.orange,
        inactiveTrackColor: AppColors.border,
        thumbColor: AppColors.orange,
        overlayColor: AppColors.orange.withOpacity(0.15),
        thumbShape:
            const RoundSliderThumbShape(enabledThumbRadius: 12),
        trackHeight: 4,
      ),
      child: Slider(
        value: value,
        min: 0.5,
        max: 80,
        divisions: 159,
        onChanged: onChanged,
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: AppDimensions.borderRadius,
        boxShadow: [AppDimensions.cardShadow],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w900)),
      );
}
