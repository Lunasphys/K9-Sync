import 'package:equatable/equatable.dart';

import '../enums/subscription_plan.dart';

/// Domain entity: user account.
class User extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final SubscriptionPlan subscriptionPlan;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.subscriptionPlan,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, email, firstName, lastName, phone, subscriptionPlan, createdAt, updatedAt];
}
