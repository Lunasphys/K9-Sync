import 'package:equatable/equatable.dart';

/// Domain entity for an alert (Clean Architecture domain layer).
class AlertEntity extends Equatable {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String actionLabel;

  const AlertEntity({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });

  @override
  List<Object?> get props => [id, category, title, subtitle, actionLabel];
}
