# Auditoría UX/UI: LumioMoney en Android — 29 de octubre de 2026

## Alcance y método

Emulador Android `emulator-5554`, compilación debug, Firebase Auth/Firestore/Functions Emulator, proyecto `demo-clearbudget`. Se generó una identidad sintética con 14 cuentas monetarias, 27 movimientos (ingresos, gastos y una transferencia) y un presupuesto. Los datos se crearon mediante repositorios y funciones de la aplicación; no se introdujeron mediante los formularios. La ejecución visual terminó con `All tests passed`: comprueba que se abrieron las rutas y se capturaron imágenes, no que todos los flujos de usuario pasaron sus validaciones.

La revisión se realizó a tamaño y escala predeterminados del dispositivo y con interfaz en inglés; el onboarding de prueba se preparó en español. Las categorías se sembraron en español intencionalmente, por lo que la mezcla de idiomas de esas categorías no es evidencia de un defecto de traducción. La cinta DEBUG pertenece a la compilación de prueba.

La prueba funcional existente `integration_test/diagnostic_flow_test.dart` también pasó en Android con Firebase Emulator: completa el contexto, proyecta efectivo, guarda reservas, registra un pago y verifica la actualización. Este resultado funcional no sustituye una inspección visual del diagnóstico cargado.

## Hallazgos

1. **Media — Ayuda del saldo inicial cortada.** En Nueva cuenta, el texto bajo «Starting balance» termina en «You can update the balance with tra…». El usuario no puede leer la indicación completa desde el estado capturado. Reproducir: Cuentas → añadir cuenta → observar el texto de ayuda bajo el saldo inicial. Recomendación: permitir que la ayuda se ajuste en varias líneas y verificar textos extensos en los tres idiomas y con texto ampliado. [Captura](evidence/ux-2026-10-29/16_new_account.png).
2. **Media — El resumen de ingresos puede interpretarse como contradictorio.** En Seguimiento presupuestal aparece «Received · COP 0» y, más abajo, «Unbudgeted total · COP 1,220,000». Ambos datos pueden ser coherentes si el primer importe solo incluye ingresos presupuestados, pero la etiqueta «Received» no lo explica y puede interpretarse como ausencia de ingresos. Recomendación: precisar «Ingresos recibidos con presupuesto» y presentar el total sin presupuesto como complemento. [Captura](evidence/ux-2026-10-29/13_budget_tracking.png). Es un hallazgo de claridad, no una validación independiente de las fórmulas.
3. **Baja — La información financiera principal queda por debajo de contenido de configuración.** En Inicio, la tarjeta para configurar la rutina y el acceso a deuda preceden al saldo; con esta altura el saldo comienza al final de la zona visible. Esto exige desplazarse para consultar detalles frecuentes. Recomendación: evaluar mostrar el saldo o un resumen compacto antes de la invitación a configurar la rutina, o reducir esa invitación una vez mostrada. [Captura](evidence/ux-2026-10-29/03_home.png).
4. **Baja — Listas extensas requieren exploración adicional.** Con 14 cuentas, la vista inicial muestra unas pocas tarjetas antes de la barra fija. En la captura no aparece búsqueda u ordenación. Recomendación: evaluar búsqueda o filtros si las pruebas con usuarios confirman que localizar una cuenta concreta es difícil. No se verificó si existen controles fuera de la zona visible. [Captura](evidence/ux-2026-10-29/05_accounts.png).

## Evidencia revisada

- Acceso y primer uso: [inicio de sesión](evidence/ux-2026-10-29/01_login.png), [configuración inicial](evidence/ux-2026-10-29/02_onboarding.png).
- Navegación principal: [Inicio](evidence/ux-2026-10-29/03_home.png), [Actividad con 27 movimientos](evidence/ux-2026-10-29/04_activity.png), [Cuentas](evidence/ux-2026-10-29/05_accounts.png), [Plan](evidence/ux-2026-10-29/06_plan.png), [Coach](evidence/ux-2026-10-29/07_coach.png).
- Planificación: [seguimiento](evidence/ux-2026-10-29/13_budget_tracking.png), [agenda](evidence/ux-2026-10-29/14_agenda.png), [pagos de deuda](evidence/ux-2026-10-29/15_debt_payments.png).
- Formularios y ajustes: [categorías](evidence/ux-2026-10-29/09_categories.png), [ingreso](evidence/ux-2026-10-29/10_income.png), [transferencia](evidence/ux-2026-10-29/12_transfer.png), [cuenta](evidence/ux-2026-10-29/16_new_account.png), [tarjeta o préstamo](evidence/ux-2026-10-29/17_new_debt.png), [ajustes](evidence/ux-2026-10-29/18_settings.png), [apariencia](evidence/ux-2026-10-29/19_appearance.png), [personalización de Inicio](evidence/ux-2026-10-29/20_home_preferences.png), [recordatorios de Coach](evidence/ux-2026-10-29/21_coach_settings.png), [filtros de actividad](evidence/ux-2026-10-29/22_activity_filters.png).

## Límites y pendientes

- La captura de [diagnóstico](evidence/ux-2026-10-29/08_diagnosis.png) muestra carga; la prueba visual no esperó una señal de datos listos. Una repetición con espera adicional se detuvo antes de llegar a esa pantalla. No se concluye que exista carga infinita ni se evaluaron visualmente sus resultados.
- La captura etiquetada gasto conserva el formulario de ingreso después de cambiar consecutivamente el parámetro de la misma ruta. Es necesario reproducir desde navegación normal antes de atribuirlo a la experiencia del usuario; no se considera verificada la pantalla de gasto.
- Las rutas se abrieron programáticamente; no se completó un recorrido de punta a punta de todos los botones ni la creación de las 14 cuentas y 27 movimientos mediante UI. No se probaron las últimas posiciones de las listas, búsqueda, teclado, lectores de pantalla, tamaños de texto, contraste medido, modo oscuro, errores, pantalla pequeña, portugués, ni localización completa en español.
- El primer intento de automatización falló porque su selector de un icono ya no coincide con la navegación actual; el recorrido corregido pasó. Una repetición posterior se interrumpió al quedar esperando una captura. Estas incidencias pertenecen al arnés de prueba; por sí solas no acreditan defectos visuales.
- No se ejecutó el recorrido en iOS en esta auditoría y no se modificaron datos financieros reales.

## Seguimiento de correcciones

- La ayuda de saldo inicial se presenta en varias líneas; [captura Android](evidence/ux-regresion-2026-10-29/06_new_account.png). Se verificó también con texto ampliado en español, inglés y portugués mediante pruebas de widgets.
- El seguimiento identifica los importes de categorías presupuestadas; [captura Android](evidence/ux-regresion-2026-10-29/08_budget_tracking.png). Se probaron ingresos no presupuestados, gastos y múltiples monedas sin modificar las fórmulas.
- Inicio presenta el saldo antes de Coach y accesos a deuda; el orden se verificó mediante pruebas de widgets. La captura del dispositivo no quedó sincronizada y no se utiliza como evidencia.
- Se agregó búsqueda de cuentas que ignora mayúsculas y acentos; [captura de búsqueda](evidence/ux-regresion-2026-10-29/05_accounts_search.png). El recorrido usó 14 cuentas y datos sintéticos. Se corrigió un desbordamiento detectado cuando se abría la creación con el teclado activo.
- El formulario de gasto se abrió correctamente desde la acción normal de registro; [captura](evidence/ux-regresion-2026-10-29/07_expense.png).
- La prueba Android de regresión funcional pasó contra `demo-clearbudget`. La suite completa de Flutter pasó con 459 pruebas, y el análisis estático no encontró problemas. La revisión visual del diagnóstico cargado sigue pendiente: la prueba funcional aislada pasó anteriormente, pero en el recorrido poblado no se encontró el control de configuración durante la espera. Esto no demuestra por sí solo una carga infinita.
- La prueba reproducible es `integration_test/ux_visual_regression_test.dart` y requiere `USE_FIREBASE_EMULATORS=true` y el proyecto `demo-clearbudget`. Para capturas Flutter se puede usar `test_driver/ux_visual_regression_driver.dart` con `CAPTURE_VISUAL=true`; para capturas externas coordinadas se puede usar `MANUAL_CAPTURE=true`. En esta ejecución se usó captura externa porque el mecanismo de Flutter se bloqueó.
- En el simulador iPhone 17 el recorrido funcional de regresión también pasó contra `demo-clearbudget`, sin excepciones tras ajustar la limpieza de la prueba. No se obtuvieron capturas iOS para certificar la apariencia visual.
