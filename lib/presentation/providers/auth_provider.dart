import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import '../../domain/interfaces/repositories/i_auth_repository.dart';
import '../../injection.dart';

/// Utilisateur connecté (null si non connecté).
final currentUserProvider = FutureProvider<User?>((ref) async {
  return getIt<IAuthRepository>().getCurrentUser();
});

/// Repository auth (GetIt — MVP).
final authRepositoryProvider = Provider<IAuthRepository>((ref) => getIt<IAuthRepository>());
