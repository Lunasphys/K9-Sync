# K9 Sync – Clean Architecture

The project follows **Clean Architecture** with a **feature-based** structure.

## Layers

### `lib/core/`
Shared code used across features:
- **theme/** – App theme and colors
- **router/** – go_router configuration and route constants
- **constants/** – Layout constants (padding, radius)
- **errors/** – Base `Failure` types for domain/data
- **usecases/** – Base `UseCase` contract and `NoParams` / `Result` helpers

### `lib/features/<feature_name>/`
Each feature is self-contained and can have up to three layers:

1. **domain/** (business rules, no Flutter)
   - **entities/** – Domain models
   - **repositories/** – Abstract repository interfaces

2. **data/** (data sources and repository implementations)
   - **datasources/** – Remote/local APIs (add when needed)
   - **models/** – DTOs (add when needed)
   - **repositories/** – Implementations of domain repositories

3. **presentation/** (UI)
   - **bloc/** – BLoC (events, state, bloc class)
   - **pages/** – Full screens
   - **widgets/** – Reusable UI (add when needed)

## Dependency rule

- **Domain** does not depend on anything (no imports from data or presentation).
- **Data** depends only on **domain** (implements repository interfaces, uses entities or mappers).
- **Presentation** may depend on **domain** (e.g. entities) and **data** only via dependency injection (e.g. repository passed to BLoC); prefer using **domain** in the UI when possible.

## Current features

| Feature     | Domain | Data | Presentation      |
|------------|--------|------|-------------------|
| **shell**  | –      | –    | BLoC + MainShell  |
| **welcome**| –      | –    | WelcomeScreen     |
| **pairing**| –      | –    | PairingScreen     |
| **alerts** | Entity + Repository | RepositoryImpl | BLoC + AlertsScreen |
| **placeholder** | – | – | PlaceholderScreen  |

## Adding a new feature

1. Create `lib/features/<name>/` with subfolders as needed (domain, data, presentation).
2. In **domain**: define entities and abstract repository interfaces.
3. In **data**: implement repositories (and datasources/models when you have API or DB).
4. In **presentation**: add BLoC (if stateful) and pages/widgets.
5. Register routes in `core/router/app_router.dart` and add the screen to the shell if it is a tab.

## Use cases (optional)

For more complex flows, add **domain/usecases/** in a feature and implement `UseCase<Type, Params>` from `core/usecases/usecase.dart`. The BLoC then calls use cases instead of repositories directly.
