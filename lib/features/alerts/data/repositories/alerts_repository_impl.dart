import '../../domain/entities/alert_entity.dart';
import '../../domain/repositories/alerts_repository.dart';

/// Implementation of [AlertsRepository]. Replace with API/remote later.
class AlertsRepositoryImpl implements AlertsRepository {
  @override
  Future<List<AlertEntity>> getAlerts({bool priorityOnly = false}) async {
    // Mock data – replace with remote or local data source.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return [
      const AlertEntity(
        id: '1',
        category: 'SÉCURITÉ',
        title: 'Bucky a franchi la clôture',
        subtitle: 'Il y a 5 min • Jardin arrière',
        actionLabel: 'Voir la carte',
      ),
      const AlertEntity(
        id: '2',
        category: 'SANTÉ',
        title: 'Fréquence cardiaque élevée',
        subtitle: 'Il y a 15 min • Au repos',
        actionLabel: 'Détails vitaux',
      ),
      const AlertEntity(
        id: '3',
        category: 'ACTIVITÉ',
        title: 'Sommeil inhabituel',
        subtitle: 'Hier soir • Agitation à 3h',
        actionLabel: 'Analyse du sommeil',
      ),
    ];
  }
}
