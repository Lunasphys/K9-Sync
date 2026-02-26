import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/interfaces/repositories/i_gps_repository.dart';
import '../../injection.dart';

final gpsRepositoryProvider = Provider<IGpsRepository>((ref) => getIt<IGpsRepository>());
