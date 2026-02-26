import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user.dart';
import '../../domain/enums/subscription_plan.dart';
import '_parsers.dart';

/// DTO User — Firestore ou REST (Prisma camelCase).
class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String subscriptionPlan;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.subscriptionPlan,
    required this.createdAt,
    required this.updatedAt,
  });

  /// REST API : body user depuis login/register/refresh ou GET /users/me (Prisma camelCase).
  static UserModel fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      phone: json['phone'] as String?,
      subscriptionPlan: (json['subscriptionPlan'] as String?) ?? 'free',
      createdAt: parseDateTimeRequired(json['createdAt']),
      updatedAt: parseDateTimeRequired(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        if (phone != null) 'phone': phone,
        'subscriptionPlan': subscriptionPlan,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static UserModel fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      email: (data['email'] as String?) ?? '',
      firstName: (data['firstName'] as String?) ?? '',
      lastName: (data['lastName'] as String?) ?? '',
      phone: data['phone'] as String?,
      subscriptionPlan: (data['subscriptionPlan'] as String?) ?? 'free',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'subscriptionPlan': subscriptionPlan,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  static UserModel fromEntity(User e) => UserModel(
        id: e.id,
        email: e.email,
        firstName: e.firstName,
        lastName: e.lastName,
        phone: e.phone,
        subscriptionPlan: e.subscriptionPlan.name,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  User toEntity() => User(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        subscriptionPlan: SubscriptionPlan.values.byName(subscriptionPlan),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
