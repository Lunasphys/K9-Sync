import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:k9sync/core/errors/app_error.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/domain/interfaces/repositories/i_dog_repository.dart';
import 'package:k9sync/injection.dart';

/// Jumelage du collier GPS par saisie manuelle du numéro de série.
/// Pas de scan Bluetooth (hors périmètre) — appelle
/// POST /dogs/:dogId/collar/pair.
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key, this.dogId});
  final String? dogId;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _serialController = TextEditingController();
  bool _pairing = false;
  String? _error;

  @override
  void dispose() {
    _serialController.dispose();
    super.dispose();
  }

  bool get _serialValid => _serialController.text.trim().length >= 3;
  bool get _canSubmit => _serialValid && widget.dogId != null && !_pairing;

  Future<void> _pair() async {
    final dogId = widget.dogId;
    if (dogId == null || !_serialValid || _pairing) return;

    setState(() {
      _pairing = true;
      _error = null;
    });

    try {
      await getIt<IDogRepository>().pairCollar(
        dogId,
        serialNumber: _serialController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collier jumelé avec succès.')),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pairing = false;
        _error = e is AppError
            ? (e.userMessage ?? 'Échec du jumelage.')
            : 'Échec du jumelage.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: const Text('Jumelage du collier GPS'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildHeader(),
              const SizedBox(height: 32),
              if (widget.dogId == null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Aucun chien sélectionné : impossible de jumeler un collier.',
                    style: TextStyle(color: AppColors.redDanger),
                  ),
                )
              else ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'NUMÉRO DE SÉRIE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _serialController,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Ex : K9S-0042',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.cardBorderWeak),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le numéro de série se trouve sous le collier ou sur sa boîte.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.redLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.redDanger),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _pair : null,
                    child: _pairing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Connecter'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(Icons.watch, size: 64, color: Colors.grey.shade700),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Jumeler un collier existant',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Saisissez le numéro de série imprimé sur le collier.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
