import 'package:flutter/material.dart';

/// Graphique activité (pas, temps actif) — squelette fl_chart.
class ActivityChart extends StatelessWidget {
  const ActivityChart({super.key, this.data});
  final List<double>? data;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: CustomPaint(
        painter: _PlaceholderChartPainter(data: data ?? []),
      ),
    );
  }
}

class _PlaceholderChartPainter extends CustomPainter {
  _PlaceholderChartPainter({required this.data});
  final List<double> data;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
