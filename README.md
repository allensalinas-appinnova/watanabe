# LumioMoney

Aplicación Flutter de finanzas personales. Este repositorio contiene la
implementación canónica del producto y sus contratos, pruebas y documentación.

## Estado

Producto en construcción con cuentas, ingresos, gastos, transferencias,
presupuestos itemizados, Actividad/exportación, personalización de Inicio,
rutinas del coach y cola offline. La gestión de deuda está implementada en el
checkout; su callable está lista en Cloud Run, pero permanece desactivada hasta
completar la cualificación del cliente. La importación asistida de correo solo
tiene una base parcial de backend y no conecta con Gmail. Consulta el backlog y
las guías de cada feature antes de
interpretar el estado de un despliegue como disponibilidad para usuarios.

## Documentación del proyecto

- [Alcance funcional](docs/functional-scope.md)
- [Arquitectura](docs/architecture.md)
- [UI/UX guidelines](docs/ui-ux-guidelines.md)
- [UI standards and theme](docs/ui-standards-and-theme.md)
- [Localization](docs/localization.md)
- [Testing strategy](docs/testing-strategy.md)
- [Coach y recordatorios](docs/coach.md)
- [Comandos de presupuesto](docs/budget-commands.md)
- [Auditoría y reconstrucción de proyecciones](docs/projection-audit.md)
- [Email import backend foundation and remaining gates](docs/email-imports.md)
- [Debt accounts, command integrity and activation gates](docs/debts.md)
- [Auditoría de preparación para iOS y Android](docs/store-readiness-audit.md)
- [Análisis de mercado y negocio LATAM](docs/market-and-business-analysis.md)
- [Backlog priorizado de implementación](docs/implementation-backlog.md)
- [Estado de cualificación para tiendas](docs/store-readiness-audit.md)

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

Para validar prerequisitos de una build staging sin desplegar:

```bash
./tool/verify_release_config.sh staging android
./tool/verify_release_config.sh staging ios
```

Staging uses separate ignored Dart-define files because Firebase app IDs differ
by platform: `config/firebase.staging.android.json` and
`config/firebase.staging.ios.json`. Start from the matching `.example.json`
files and populate them only after authenticating the Firebase CLI.
