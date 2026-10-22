# Observabilidad de LumioMoney

## Política

Analytics conserva su política de eventos allowlisted para `staging` y `prod`.
Crashlytics se configura explícitamente: la recolección está deshabilitada en
`dev` y cuando se usa Firebase Emulator, y solo se habilita para `staging` y
`prod`. Los metadatos Android/iOS también dejan la recolección automática
desactivada; `FirebaseObservability` aplica la política tras inicializar
Firebase y antes de instalar los handlers de errores. En `dev`, los errores
permanecen locales.

Los handlers nunca pasan la excepción original a Crashlytics. Envían únicamente
`SafeTechnicalFailure` con códigos técnicos enumerados y una razón fija; no se
adjuntan IDs de usuario, claves personalizadas, logs, montos, monedas, cuentas,
categorías, descripciones, tokens ni texto sin filtrar de Firebase. Los reportes
no fatales también requieren que la política permita recolección. La instancia
permite inyectar el setter y el reportero en pruebas sin enviar telemetría real.

La configuración nativa es local y está excluida de Git:

- Android: `android/app/google-services.json`.
- iOS: `ios/Runner/GoogleService-Info.plist`.
- Firebase project: `lumiomoney`; el registro iOS de Crashlytics debe coincidir
  exactamente con `com.appinnova.lumiomoney.app`.

No se debe copiar esa configuración a archivos versionados, logs o capturas.
Android prepara mapping files con el plugin para cualquier build que active
ofuscación; este cambio no habilita ofuscación ni Crashlytics NDK. Xcode genera
dSYM y ejecuta `Crashlytics/run` para prepararlos para carga/simbolicación.

Los eventos permitidos son nombres fijos y no incluyen montos, monedas,
categorías, descripciones, IDs de cuentas ni contenido de recibos:

- `onboarding_completed`
- `account_created`
- `income_created`
- `expense_created`
- `budget_created`
- `transfer_created`
- `sync_rejected`

La implementación está en `lib/core/firebase/firebase_observability.dart`.
`main.dart` registra errores Flutter y errores asíncronos no capturados. El
wrapper rechaza nombres de eventos no permitidos para evitar enviar datos
financieros accidentalmente.

## Validación staging pendiente

Después de configurar un proyecto Firebase staging distinto de producción:

1. Ejecutar una build con `APP_ENV=staging`.
2. Provocar únicamente un error no fatal sintético en staging.
3. Confirmar recepción y simbolicación en Crashlytics.
4. Completar onboarding y una operación sintética.
5. Confirmar los eventos en Analytics.
6. Revisar que ningún payload contenga información financiera.

No se considera verificado hasta contar con evidencia del proyecto staging.
Actualmente solo existe configuración Firebase para `lumiomoney`; no habilites
la colección en `dev` para compensar que staging aún no esté creado. La
recepción remota y la simbolicación permanecen pendientes hasta tener staging.
