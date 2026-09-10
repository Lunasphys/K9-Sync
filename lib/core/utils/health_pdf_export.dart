import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../presentation/providers/health_provider.dart';

const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String _formatDateTime(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year} à '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Builds a vet-facing PDF health report from the readings received during
/// the current session. There is no backend endpoint for historical health
/// data (only GET .../health/latest and POST .../health/sync exist) — the
/// only real source of a multi-point history is [HealthState.history], fed
/// live by MQTT while the Santé screen is open. The report says so
/// explicitly rather than presenting this as a full medical record.
Future<Uint8List> buildHealthPdf({
  required String dogName,
  required List<HealthSnapshot> history,
}) async {
  final doc = pw.Document();
  final sorted = [...history]
    ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final anomalies = sorted.where((s) => s.anomalyDetected).toList();
  final heartRates = sorted.map((s) => s.heartRate).toList();
  final temps = sorted.map((s) => s.temperature).toList();

  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Header(level: 0, text: 'Rapport de santé - $dogName'),
        pw.Text(
          sorted.isEmpty
              ? 'Aucune donnée de santé reçue durant cette session.'
              : 'Période couverte : du ${_formatDateTime(sorted.first.recordedAt)} '
                    'au ${_formatDateTime(sorted.last.recordedAt)} '
                    '(${sorted.length} relevé${sorted.length > 1 ? 's' : ''} '
                    'reçus durant la session en cours)',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 16),
        if (sorted.isNotEmpty) ...[
          pw.Header(level: 1, text: 'Résumé'),
          pw.TableHelper.fromTextArray(
            headers: ['Mesure', 'Moyenne', 'Min', 'Max'],
            data: [
              [
                'Fréquence cardiaque (bpm)',
                (heartRates.reduce((a, b) => a + b) / heartRates.length)
                    .toStringAsFixed(0),
                heartRates.reduce((a, b) => a < b ? a : b).toString(),
                heartRates.reduce((a, b) => a > b ? a : b).toString(),
              ],
              [
                'Température (°C)',
                (temps.reduce((a, b) => a + b) / temps.length)
                    .toStringAsFixed(1),
                temps.reduce((a, b) => a < b ? a : b).toStringAsFixed(1),
                temps.reduce((a, b) => a > b ? a : b).toStringAsFixed(1),
              ],
            ],
          ),
          pw.SizedBox(height: 16),
        ],
        pw.Header(level: 1, text: 'Anomalies détectées'),
        anomalies.isEmpty
            ? pw.Text('Aucune anomalie détectée sur la période.')
            : pw.TableHelper.fromTextArray(
                headers: ['Date', 'Type', 'FC (bpm)', 'Température (°C)'],
                data: anomalies
                    .map(
                      (a) => [
                        _formatDateTime(a.recordedAt),
                        a.anomalyType,
                        a.heartRate.toString(),
                        a.temperature.toStringAsFixed(1),
                      ],
                    )
                    .toList(),
              ),
        if (sorted.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Historique détaillé'),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'FC (bpm)', 'Température (°C)', 'Anomalie'],
            data: sorted
                .map(
                  (s) => [
                    _formatDateTime(s.recordedAt),
                    s.heartRate.toString(),
                    s.temperature.toStringAsFixed(1),
                    s.anomalyDetected ? s.anomalyType : '-',
                  ],
                )
                .toList(),
          ),
        ],
      ],
    ),
  );

  return doc.save();
}

/// Builds the PDF, writes it to a temp file and opens the share sheet —
/// the full export action behind any "Exporter le rapport santé" button.
/// Shows a SnackBar on failure (requires a [ScaffoldMessenger] ancestor).
///
/// [healthProvider] is a single global provider, not scoped per dog or per
/// screen, so any screen that already has the dog's name can call this
/// directly with [HealthState.history] — no need to navigate to the Santé
/// tab first just to reach the data.
Future<void> exportAndShareHealthPdf({
  required BuildContext context,
  required String dogName,
  required List<HealthSnapshot> history,
}) async {
  try {
    final bytes = await buildHealthPdf(dogName: dogName, history: history);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/k9sync-sante-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes);

    if (!context.mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Rapport santé de $dogName',
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Échec de l\'export : $e')));
  }
}
