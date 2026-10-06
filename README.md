# Personal Finance Flutter

Aplicación móvil Flutter de finanzas personales. Se mantiene separada de la versión web ubicada en [`../studio`](../studio), que solo funciona como referencia de dominio y casos de uso.

## Estado

Beta funcional en construcción con el modelo financiero canónico: onboarding
localizado, cuentas, ingresos, gastos, transferencias, presupuestos itemizados,
seguimiento y cola offline durable. La validación de Emulator Suite está
automatizada; la cualificación del APK/iOS en dispositivos y la configuración
de staging siguen siendo gates de release.

## Documentación del proyecto

- [Alcance funcional](docs/functional-scope.md)
- [Arquitectura](docs/architecture.md)
- [UI/UX guidelines](docs/ui-ux-guidelines.md)
- [UI standards and theme](docs/ui-standards-and-theme.md)
- [Localization](docs/localization.md)
- [Testing strategy](docs/testing-strategy.md)
- [Auditoría de preparación para iOS y Android](docs/store-readiness-audit.md)
- [Análisis de mercado y negocio LATAM](docs/market-and-business-analysis.md)
- [Backlog priorizado de implementación](docs/implementation-backlog.md)

## Comandos

```bash
flutter pub get
dart run build_runner build
dart format .
dart analyze
flutter test
```

Emulator backed E2E test:

```bash
export JAVA_HOME="$(brew --prefix openjdk@21)"
export PATH="$JAVA_HOME/bin:$PATH"
./tool/run_emulator_e2e.sh
```

Starts Firebase Auth, Firestore and Storage emulators. Requires a running Android
emulator (default device ID `emulator-5554`), Node.js and Java 21+. To select another device, pass its Flutter device ID; set
`FIREBASE_EMULATOR_HOST` if it cannot reach the host at `10.0.2.2`.

For an iOS Simulator use `E2E_PLATFORM=ios ./tool/run_emulator_e2e.sh <simulator-id>`;

Firestore pagination verification with 101 synthetic operations:

```bash
./tool/run_pagination_test.sh
```
the default emulator host is then `127.0.0.1`. The suite uses the reserved
`demo-clearbudget` project and never targets a live Firebase project.

## Firebase flavors

Los valores de Firebase se inyectan por `--dart-define` y el entorno se selecciona con `APP_ENV=dev|staging|prod`. Consulta [docs/flavors.md](docs/flavors.md) para ejecutar iOS contra el proyecto Firebase existente o E2E con Emulator Suite. El script `tool/run_ios_firebase.sh` valida el proyecto enlazado antes de usar servicios reales; `tool/run_emulator_e2e.sh` está aislado en `demo-clearbudget`.
