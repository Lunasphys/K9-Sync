import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:k9sync/core/debug/debug_logger.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/entities/dog.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/injection.dart';
import 'package:k9sync/presentation/router/route_guards.dart';
import 'package:k9sync/presentation/screens/dog/dog_breeds.dart';

/// Post-register onboarding — creates the first dog profile.
class DogSetupScreen extends StatefulWidget {
  const DogSetupScreen({super.key});

  @override
  State<DogSetupScreen> createState() => _DogSetupScreenState();
}

class _DogSetupScreenState extends State<DogSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  String? _selectedBreed;
  String? _customBreed;
  final _customBreedCtrl = TextEditingController();

  double _weight = 10.0;
  DateTime? _birthDate;
  DogSex? _sex;

  File? _photo;
  bool _uploading = false;
  bool _saving = false;
  String? _photoUrl;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _customBreedCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() {
      _photo = File(picked.path);
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
      _photoUrl = response.data?['url'] as String?;
    } catch (e) {
      DebugLogger.log('UPLOAD', 'Photo upload failed: $e',
          level: LogLevel.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur upload photo.'),
          backgroundColor: Colors.red,
        ));
      }
      setState(() => _photo = null);
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

    setState(() => _saving = true);
    try {
      await getIt<IDogRepository>().createDog(CreateDogParams(
        name: _nameCtrl.text.trim(),
        breed: breed,
        birthDate: _birthDate,
        weight: _weight,
        sex: _sex,
        photoUrl: _photoUrl,
      ));
      if (mounted) context.go(AppRoutes.homeAccueil);
    } catch (e) {
      DebugLogger.log('DOG_SETUP', 'Create dog failed: $e',
          level: LogLevel.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erreur lors de la création du profil.'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.homeAccueil),
            child: Text('Passer',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('🐾', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('Votre compagnon',
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'Créez le profil de votre chien pour commencer le suivi.',
                style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    height: 1.4),
              ),
              const SizedBox(height: 28),

              Center(
                child: _PhotoPicker(
                  photo: _photo,
                  uploading: _uploading,
                  onTap: _pickPhoto,
                ),
              ),
              const SizedBox(height: 28),

              _FormCard(children: [
                _FieldLabel('Nom du chien *'),
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

              _saving
                  ? const Center(child: CircularProgressIndicator())
                  : GestureDetector(
                      onTap: _submit,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          border: Border.all(
                              color: AppColors.border, width: 2),
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [AppDimensions.cardShadow],
                        ),
                        child: const Center(
                          child: Text('Créer le profil',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameCtrl,
      textCapitalization: TextCapitalization.words,
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Le nom est requis';
        if (v.trim().length < 2) return 'Minimum 2 caractères';
        if (v.trim().length > 30) return 'Maximum 30 caractères';
        final validName = RegExp(r"^[a-zA-ZÀ-ÿ\s'\-]+$");
        if (!validName.hasMatch(v.trim())) {
          return 'Lettres uniquement';
        }
        return null;
      },
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      decoration: _inputDecoration('Ex : Bucky'),
    );
  }

  Widget _buildBreedDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedBreed,
      hint: Text('Sélectionner une race',
          style: TextStyle(
              color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      decoration: _inputDecoration(''),
      isExpanded: true,
      items: DogBreeds.all
          .map((breed) => DropdownMenuItem(
                value: breed,
                child: Text(breed,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ))
          .toList(),
      onChanged: (v) => setState(() {
        _selectedBreed = v;
        if (v != 'Autre') _customBreedCtrl.clear();
      }),
    );
  }

  Widget _buildCustomBreedField() {
    return TextFormField(
      controller: _customBreedCtrl,
      textCapitalization: TextCapitalization.words,
      validator: (v) {
        if (_selectedBreed == 'Autre' &&
            (v == null || v.trim().isEmpty)) {
          return 'Précisez la race';
        }
        return null;
      },
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      decoration: _inputDecoration('Précisez la race...'),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
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
}

class _PhotoPicker extends StatelessWidget {
  final File? photo;
  final bool uploading;
  final VoidCallback onTap;
  const _PhotoPicker(
      {required this.photo,
      required this.uploading,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: uploading ? null : onTap,
      child: Stack(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.cream,
              border: Border.all(color: AppColors.border, width: 2),
              shape: BoxShape.circle,
              boxShadow: [AppDimensions.cardShadow],
            ),
            child: ClipOval(
              child: uploading
                  ? const Center(child: CircularProgressIndicator())
                  : photo != null
                      ? Image.file(photo!, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🐕',
                                style: TextStyle(fontSize: 36)),
                            const SizedBox(height: 4),
                            Text('Photo',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt,
                  size: 14, color: Colors.white),
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
    return Row(
      children: [
        _SexChip(
          label: '♂ Mâle',
          selected: selected == DogSex.male,
          onTap: () => onChanged(
              selected == DogSex.male ? null : DogSex.male),
        ),
        const SizedBox(width: 10),
        _SexChip(
          label: '♀ Femelle',
          selected: selected == DogSex.female,
          onTap: () => onChanged(
              selected == DogSex.female ? null : DogSex.female),
        ),
      ],
    );
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
        child: Row(
          children: [
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
                  color:
                      date != null ? AppColors.text : AppColors.textMuted,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ],
        ),
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}
