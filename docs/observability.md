# Observabilidad de ClearBudget

## Política

Crashlytics y Analytics solo se activan para `staging` y `prod`. En `dev`, los
errores se muestran localmente y los eventos no se envían.

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

Después de configurar el proyecto Firebase staging:

1. Ejecutar una build con `APP_ENV=staging`.
2. Provocar un error no fatal sintético.
3. Confirmar recepción en Crashlytics.
4. Completar onboarding y una operación sintética.
5. Confirmar los eventos en Analytics.
6. Revisar que ningún payload contenga información financiera.

No se considera verificado hasta contar con evidencia del proyecto staging.
