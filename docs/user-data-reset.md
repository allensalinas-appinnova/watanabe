# Restablecer datos de usuario

## Comportamiento

La opción **Configuración → Reiniciar mis datos** conserva la identidad de Firebase Auth, pero elimina los datos personales bajo `users/{uid}`, incluidas operaciones y proyecciones, cuentas, categorías del usuario, presupuestos, comandos, datos del Coach e importaciones. El catálogo global `categoryCatalog` no se elimina. Al finalizar, el perfil queda en estado de onboarding.

La pantalla requiere escribir la confirmación localizada y confirmarla de nuevo. Bloquea la operación si el outbox local contiene movimientos pendientes, en sincronización o rechazados. Una vez que el servidor acepta la solicitud, el borrado es asíncrono y puede continuar aunque el cliente pierda conexión.

## Generación y reintentos

Los perfiles anteriores sin `dataGeneration` equivalen a generación `0`. `resetUserData` requiere Auth, usa el UID de la sesión y recibe un `requestId` estable junto con la generación esperada. El servidor incrementa la generación antes de borrar, marca el perfil como `resetting` y elimina subcolecciones recursivamente. Solo conserva el estado mínimo de reinicio y la nueva generación. Un reintento del mismo comando puede reanudar una limpieza interrumpida; los comandos concurrentes o de una generación anterior se rechazan.

Las escrituras de cliente y los comandos de servidor comprueban la generación vigente. Los triggers de proyección también la verifican, por lo que eventos retrasados de una generación anterior no deben reconstruir datos borrados. Un cliente antiguo u otro dispositivo con una cola offline no podrá volver a aplicar sus escrituras tras completarse el reinicio. El usuario debe resolver primero los movimientos pendientes conocidos y actualizar el cliente en todos sus dispositivos.

La confirmación no borra el usuario de Auth ni el catálogo compartido. El siguiente onboarding debe crear el perfil y los datos iniciales como los de un usuario nuevo.

## Validación local

Usar exclusivamente los emuladores y el proyecto sintético `demo-clearbudget`:

Iniciar Auth, Firestore y Functions Emulator con la configuración local del proyecto en otra terminal antes de ejecutar pruebas callable.

```sh
export GCLOUD_PROJECT=demo-clearbudget
export FIRESTORE_EMULATOR_HOST=127.0.0.1:59180
export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:59199
npm --prefix functions run test:user-data-reset
npm --prefix functions run test:user-data-generation
FUNCTIONS_EMULATOR=true node --test \
  functions/test/user_data_reset_callable_test.mjs \
  functions/test/budget_callable_test.mjs \
  functions/test/balance_adjustment_callable_test.mjs \
  functions/test/debt_callable_test.mjs \
  functions/test/email_import_callable_test.mjs \
  functions/test/projection_trigger_test.mjs
```

Las pruebas no deben llamar al reinicio en un proyecto real. Antes de cualquier publicación, ejecutar además el conjunto de reglas y las suites Flutter/Functions completas.

## Despliegue y recuperación

Este cambio modifica reglas y el contrato de escritura de las Functions existentes además de añadir `resetUserData`. Desplegar coordinadamente `firestore:rules` y las Functions que aceptan escrituras de usuario (`resetUserData`, `mutateBudget`, `adjustAccountBalances`, `mutateDebt`, `mutateEmailImport` y `processOperation`) desde el mismo checkout. No desplegar solo la callable de reinicio: los comandos antiguos deben validar generación y estado de reinicio.

Si la autenticación del CLI está vencida, volver a iniciar sesión con `firebase login --reauth` y verificar el proyecto activo antes del despliegue. No guardar tokens ni credenciales en el repositorio. Una vez iniciada una limpieza real, no revertir reglas o Functions a versiones que permitan escrituras sin generación: corregir el despliegue hacia delante y mantener bloqueadas las escrituras hasta que el estado sea consistente. La cualificación de este cambio nunca requiere reiniciar datos reales.
