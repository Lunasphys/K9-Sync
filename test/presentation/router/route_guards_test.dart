import 'package:flutter_test/flutter_test.dart';

import 'package:k9sync/presentation/router/route_guards.dart';

void main() {
  setUp(resetConsentCache);
  tearDown(resetConsentCache);

  group('authGuard — consent gate (regression: login bypassing consent)', () {
    test(
      'inscription puis reconnexion sans consentement validé redirige vers /consent, pas /home/accueil',
      () async {
        // Reproduit exactement le scénario trouvé lors de la répétition
        // générale : un compte est créé, l'utilisateur ne valide jamais
        // l'écran de consentement, se déconnecte puis se reconnecte. Le
        // formulaire de connexion appelle context.go(AppRoutes.homeAccueil)
        // — c'est cette navigation que authGuard doit intercepter.
        final result = await authGuard(
          true,
          AppRoutes.homeAccueil,
          hasAcceptedConsent: () async => false,
        );

        expect(result, AppRoutes.consent);
      },
    );

    test(
      'un deep link direct vers une route protégée est aussi bloqué si le consentement manque',
      () async {
        final result = await authGuard(
          true,
          AppRoutes.homeSante,
          hasAcceptedConsent: () async => false,
        );

        expect(result, AppRoutes.consent);
      },
    );

    test(
      'revenir sur une route publique (ex. /login) alors que déjà connecté sans consentement redirige vers /consent, pas /home/accueil',
      () async {
        final result = await authGuard(
          true,
          AppRoutes.signIn,
          hasAcceptedConsent: () async => false,
        );

        expect(result, AppRoutes.consent);
      },
    );

    test(
      'consentement déjà validé laisse passer vers une route protégée',
      () async {
        final result = await authGuard(
          true,
          AppRoutes.homeAccueil,
          hasAcceptedConsent: () async => true,
        );

        expect(result, isNull);
      },
    );

    test(
      '/consent lui-même n\'est jamais bloqué par son propre garde-fou',
      () async {
        final result = await authGuard(
          true,
          AppRoutes.consent,
          hasAcceptedConsent: () async => false,
        );

        expect(result, isNull);
      },
    );

    test(
      'le statut de consentement est mis en cache : un seul appel réseau pour plusieurs navigations',
      () async {
        var callCount = 0;
        Future<bool> check() async {
          callCount++;
          return true;
        }

        await authGuard(true, AppRoutes.homeAccueil, hasAcceptedConsent: check);
        await authGuard(true, AppRoutes.homeCarte, hasAcceptedConsent: check);
        await authGuard(true, AppRoutes.homeSante, hasAcceptedConsent: check);

        expect(callCount, 1);
      },
    );

    test(
      'markConsentAccepted() évite un nouvel appel réseau juste après la soumission du consentement',
      () async {
        var callCount = 0;
        Future<bool> check() async {
          callCount++;
          return false;
        }

        markConsentAccepted();
        final result = await authGuard(
          true,
          AppRoutes.homeAccueil,
          hasAcceptedConsent: check,
        );

        expect(result, isNull);
        expect(callCount, 0);
      },
    );

    test(
      'resetConsentCache() force une nouvelle vérification réseau',
      () async {
        var callCount = 0;
        Future<bool> check() async {
          callCount++;
          return true;
        }

        await authGuard(true, AppRoutes.homeAccueil, hasAcceptedConsent: check);
        resetConsentCache();
        await authGuard(true, AppRoutes.homeAccueil, hasAcceptedConsent: check);

        expect(callCount, 2);
      },
    );
  });

  group('authGuard — comportement existant (non régression)', () {
    test('non connecté sur une route protégée redirige vers /login', () async {
      final result = await authGuard(
        false,
        AppRoutes.homeAccueil,
        hasAcceptedConsent: () async => true,
      );

      expect(result, AppRoutes.login);
    });

    test('non connecté sur une route publique ne redirige pas', () async {
      final result = await authGuard(
        false,
        AppRoutes.login,
        hasAcceptedConsent: () async => true,
      );

      expect(result, isNull);
    });

    test(
      'une session qui devient déconnectée réinitialise le cache de consentement',
      () async {
        var callCount = 0;
        Future<bool> check() async {
          callCount++;
          return true;
        }

        await authGuard(true, AppRoutes.homeAccueil, hasAcceptedConsent: check);
        await authGuard(
          false,
          AppRoutes.homeAccueil,
          hasAcceptedConsent: check,
        );
        await authGuard(true, AppRoutes.homeAccueil, hasAcceptedConsent: check);

        expect(callCount, 2);
      },
    );
  });
}
