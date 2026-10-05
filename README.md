# Personal Finance Flutter

Aplicación móvil Flutter de finanzas personales. Se mantiene separada de la versión web ubicada en [`../studio`](../studio), que solo funciona como referencia de dominio y casos de uso.

## Estado

Prototipo funcional con autenticación, dashboard, actividad, cuentas, registro de gastos con comprobantes y edición de límites presupuestarios. La arquitectura base usa Feature-First Clean Architecture. Aún existen brechas de integridad financiera, localización y publicación; consulta la auditoría antes de preparar un release.

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
./tool/run_emulator_e2e.sh
```

Starts Firebase Auth, Firestore and Storage emulators. Requires a running Android
emulator (default device ID `emulator-5554`), Node.js and Java 21+. To select another device, pass its Flutter device ID; set
`FIREBASE_EMULATOR_HOST` if it cannot reach the host at `10.0.2.2`.

## Firebase flavors

Los valores de Firebase se inyectan por `--dart-define` y el entorno se selecciona con `APP_ENV=dev|staging|prod`. Consulta [docs/flavors.md](docs/flavors.md) para ejecutar iOS contra el proyecto Firebase existente o E2E con Emulator Suite. El script `tool/run_ios_firebase.sh` valida el proyecto enlazado antes de usar servicios reales; `tool/run_emulator_e2e.sh` está aislado en `demo-clearbudget`.
