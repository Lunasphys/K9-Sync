import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/interfaces/repositories/i_alert_repository.dart';
import '../../injection.dart';

final alertRepositoryProvider = Provider<IAlertRepository>((ref) => getIt<IAlertRepository>());
