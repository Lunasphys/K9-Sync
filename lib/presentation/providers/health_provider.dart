import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/interfaces/repositories/i_health_repository.dart';
import '../../injection.dart';

final healthRepositoryProvider = Provider<IHealthRepository>((ref) => getIt<IHealthRepository>());
