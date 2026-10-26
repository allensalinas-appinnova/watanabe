// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get debtTitle => 'Tarjetas y préstamos';

  @override
  String get debtAdd => 'Agregar tarjeta o préstamo';

  @override
  String get debtMoney => 'Dinero disponible';

  @override
  String get debtCards => 'Tarjetas de crédito';

  @override
  String get debtLoans => 'Créditos y préstamos';

  @override
  String get debtProduct => 'Producto';

  @override
  String get debtPaymentCard => 'Pago de tarjeta';

  @override
  String get debtPaymentLoan => 'Pago de crédito';

  @override
  String get activityFilterDebtPayments => 'Pagos de deudas';

  @override
  String get activityCsvPaymentType => 'Tipo de pago';

  @override
  String get categoryCatalogSyncMessage =>
      'No se pudieron actualizar las categorías predeterminadas.';

  @override
  String get categoryIconInterest => 'Intereses y comisiones';

  @override
  String get debtNewChargesCategory => 'Categoría de los cargos nuevos';

  @override
  String get debtNewChargesExpenseNote =>
      'Solo los cargos nuevos de esta cuota se registran como gasto.';

  @override
  String get debtCreditCard => 'Tarjeta de crédito';

  @override
  String get debtBankLoan => 'Crédito bancario';

  @override
  String get debtPersonalLoan => 'Préstamo personal recibido';

  @override
  String get debtRegistered => 'Deuda registrada';

  @override
  String get debtCreditBalance => 'Saldo a favor en tarjetas';

  @override
  String get debtPosition => 'Posición neta registrada';

  @override
  String get debtPositionNote =>
      'Solo registros seleccionados; no representa tu patrimonio completo.';

  @override
  String get debtOpeningMode => 'Origen del saldo';

  @override
  String get debtExisting => 'Deuda existente (no mueve dinero)';

  @override
  String get debtReceived => 'Préstamo recibido ahora';

  @override
  String get debtReferenceDate => 'Fecha del saldo inicial';

  @override
  String get debtPrincipal => 'Capital pendiente';

  @override
  String get debtCharges => 'Cargos devengados pendientes';

  @override
  String get debtLimit => 'Cupo (opcional)';

  @override
  String get debtCreditor => 'Acreedor (opcional)';

  @override
  String get debtLastFour => 'Últimos 4 dígitos (opcional)';

  @override
  String get debtPay => 'Registrar pago';

  @override
  String get debtPayCard => 'Pagar tarjeta';

  @override
  String get debtDisburse => 'Registrar desembolso';

  @override
  String get debtCharge => 'Registrar cargo';

  @override
  String get debtRefund => 'Devolución de gasto';

  @override
  String get debtAdjust => 'Ajustar deuda';

  @override
  String get debtPurchase => 'Compra con tarjeta';

  @override
  String get debtPreviousCharges => 'Cargos ya registrados que pagas';

  @override
  String get debtNewCharges => 'Cargos nuevos pagados ahora';

  @override
  String get debtOriginalPurchase => 'Compra original';

  @override
  String get debtBank => 'Cuenta de dinero';

  @override
  String get debtReview => 'Revisar antes de confirmar';

  @override
  String get debtOnline => 'Requiere conexión. Tu borrador se conserva si falla el guardado.';

  @override
  String get debtDisabled => 'La función de deudas aún no está activada en el servidor.';

  @override
  String get debtErrorSplit =>
      'Completa el desglose: capital, cargos registrados y cargos nuevos deben sumar el pago.';

  @override
  String get debtErrorComponents =>
      'El cambio dejaría capital o cargos negativos. Revisa el desglose y los movimientos posteriores.';

  @override
  String get debtErrorRefund => 'Revisa la compra original y el importe aún no devuelto.';

  @override
  String get debtErrorDate => 'La fecha no puede ser anterior al saldo inicial.';

  @override
  String get debtErrorArchive => 'Solo puedes archivar una obligación con saldo cero.';

  @override
  String get debtErrorReference =>
      'Revisa la cuenta, moneda, categoría y presupuesto seleccionados.';

  @override
  String get debtOverLimit => 'La deuda supera el cupo registrado. El movimiento se guardó.';

  @override
  String get debtReverse => 'Anular con reversión';

  @override
  String get debtComponents => 'Componentes vinculados';

  @override
  String get debtCommand => 'Comando';

  @override
  String get debtReversal => 'Reversión';

  @override
  String get budgetConnectionRequired =>
      'Necesitas conexión para guardar este presupuesto. Tus cambios siguen aquí; vuelve a intentarlo.';

  @override
  String get budgetCommandArchived =>
      'Este presupuesto o elemento está archivado. Actualiza la lista.';

  @override
  String get budgetCommandNotFound =>
      'Este presupuesto o elemento ya no está disponible. Actualiza la lista.';

  @override
  String get budgetCommandConflict =>
      'La solicitud entra en conflicto con un cambio anterior. Actualiza el presupuesto antes de reintentar.';

  @override
  String get appTitle => 'LumioMoney';

  @override
  String get sessionCheckFailed =>
      'No pudimos verificar tu perfil. Revisa tu conexión e inténtalo de nuevo, o vuelve a iniciar sesión.';

  @override
  String get sessionSignOut => 'Cerrar sesión y volver al acceso';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get continueAsGuest => 'Probar sin crear cuenta';

  @override
  String get guestAccountHint =>
      'Tus datos quedan asociados a esta sesión. Guarda tu cuenta para recuperarlos desde otros dispositivos.';

  @override
  String get guestSaveAccount => 'Guardar mi cuenta';

  @override
  String get guestUpgradeTitle => 'Guardar mi cuenta';

  @override
  String get guestUpgradeSubtitle =>
      'Vincula un correo o Google a esta sesión para proteger tus datos. Se conservarán tu perfil y tus movimientos.';

  @override
  String get guestUpgradeEmailTitle => 'Crear acceso con correo';

  @override
  String get guestUpgradeGoogleButton => 'Vincular con Google';

  @override
  String get guestUpgradeConfirmPassword => 'Confirmar contraseña';

  @override
  String get guestUpgradePasswordMismatch => 'Las contraseñas no coinciden.';

  @override
  String get guestUpgradeSuccess => 'Tu cuenta quedó protegida. Tus datos siguen en esta sesión.';

  @override
  String get guestUpgradeEmailSent =>
      'Cuenta protegida. Enviamos un correo para verificar tu dirección; puedes seguir usando la app.';

  @override
  String get guestUpgradeEmailNotSent =>
      'La cuenta quedó protegida, pero no pudimos enviar el correo de verificación. Puedes reintentarlo.';

  @override
  String get guestUpgradeResendVerification => 'Reenviar verificación';

  @override
  String get guestUpgradeAlreadyProtected => 'Esta sesión ya tiene un método de acceso vinculado.';

  @override
  String get guestUpgradeConflict =>
      'Este correo o cuenta ya pertenece a otra cuenta. Tu sesión de invitado y sus datos no cambiaron. Prueba otra credencial.';

  @override
  String get guestUpgradeProviderLinked => 'Este método ya está vinculado a la sesión actual.';

  @override
  String get guestUpgradeCancelled =>
      'Se canceló la vinculación. Tu sesión de invitado sigue activa.';

  @override
  String get guestUpgradeUnavailable =>
      'Este método de acceso no está disponible ahora. Tu sesión sigue activa.';

  @override
  String get guestUpgradeWeakPassword => 'Elige una contraseña más segura.';

  @override
  String get guestSignOutWarning =>
      'Esta sesión de invitado no tiene acceso de recuperación. Si cierras sesión, podrías perder el acceso a estos datos. Guarda tu cuenta antes para recuperarlos en otro dispositivo.';

  @override
  String get guestUpgradeBackToApp => 'Volver a la aplicación';

  @override
  String get authLoginTab => 'Iniciar sesión';

  @override
  String get authEmailLabel => 'Correo electrónico';

  @override
  String get authEmailHint => 'nombre@ejemplo.com';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authEmailInvalid => 'Escribe un correo electrónico válido.';

  @override
  String get authPasswordTooShort => 'Usa al menos 8 caracteres.';

  @override
  String get authForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get authResetEmailInvalid => 'Escribe un correo válido para recuperar tu contraseña.';

  @override
  String get authPasswordResetSent =>
      'Si existe una cuenta con este correo, enviamos un enlace para restablecer la contraseña.';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get authContinueWithGoogle => 'Continuar con Google';

  @override
  String get authOrContinueWith => 'o continúa con';

  @override
  String get authPrivacyNote => 'Tus datos son privados y están cifrados.';

  @override
  String get authActionFailed =>
      'No pudimos completar la acción. Revisa tus datos e inténtalo de nuevo.';

  @override
  String get authNetworkError => 'No hay conexión. Revisa tu internet e inténtalo de nuevo.';

  @override
  String get authTagline => 'Claridad para cada peso.';

  @override
  String get hideBalances => 'Ocultar importes';

  @override
  String get showBalances => 'Mostrar importes';

  @override
  String get hiddenAmount => 'Importe oculto';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get dashboardTitle => 'Tu dinero, con claridad.';

  @override
  String get homeMenu => 'Más opciones';

  @override
  String get homeTotalBalance => 'Saldo total';

  @override
  String get homeBudgetTitle => 'Presupuesto del mes';

  @override
  String get homeExpenseVsBudget => 'Gasto vs. presupuesto';

  @override
  String get homeIncomeVsBudget => 'Ingreso vs. presupuesto';

  @override
  String homeBudgetComparisonDetails(Object actual, Object planned) {
    return 'Real · $actual / Plan · $planned';
  }

  @override
  String get homeNoBudgetForFlow => 'Sin presupuesto este mes';

  @override
  String homeMonthlySummary(Object month, Object currency) {
    return 'Resumen de $month · $currency';
  }

  @override
  String get seeAll => 'Ver todos';

  @override
  String get setupTitle => 'Configura LumioMoney';

  @override
  String get personalizeExperience => 'Prepara tu espacio';

  @override
  String get onboardingSubtitle => 'Elige tus preferencias. Puedes cambiarlas después.';

  @override
  String get language => 'Idioma';

  @override
  String get country => 'País';

  @override
  String get baseCurrency => 'Moneda base';

  @override
  String get firstAccountName => 'Nombre de tu primera cuenta';

  @override
  String get continueAction => 'Continuar';

  @override
  String get home => 'Inicio';

  @override
  String get activity => 'Actividad';

  @override
  String get activitySubtitle => 'Encuentra y revisa tus movimientos';

  @override
  String get activityFilterAll => 'Todos';

  @override
  String get activityFilterTransfers => 'Transferencias';

  @override
  String get activityBalanceAdjustmentsFilter => 'Ajustes';

  @override
  String get activityBalanceAdjustmentType => 'Ajuste de saldo';

  @override
  String activityBalanceAdjustmentEntry(Object previous, Object target, Object difference) {
    return 'Saldo $previous → $target · diferencia $difference';
  }

  @override
  String get activityBalanceAdjustmentsHeader => 'Ajustes de saldo';

  @override
  String get activityBalanceAdjustmentsEmpty => 'No hay ajustes para estos filtros.';

  @override
  String activityFilterAction(Object account, Object period) {
    return 'Filtros · $account · $period';
  }

  @override
  String get activityFilterTitle => 'Filtrar actividad';

  @override
  String get activityFilterAccount => 'CUENTA';

  @override
  String get activityFilterAllAccounts => 'Todas las cuentas';

  @override
  String get activityFilterPeriod => 'PERIODO';

  @override
  String get activityFilterMonth => 'Mes';

  @override
  String get activityFilterDateRange => 'Rango de fechas';

  @override
  String get activityFilterSelectAccount => 'Elige las cuentas';

  @override
  String get activityFilterMultiSelectHint =>
      'Puedes elegir hasta 10 cuentas. Una transferencia aparece si seleccionas cualquiera de sus cuentas.';

  @override
  String get activityFilterDone => 'Listo';

  @override
  String activityFilterSelectedAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas',
      one: '$count cuenta',
    );
    return '$_temp0';
  }

  @override
  String get activityFilterSelectMonth => 'Elegir mes';

  @override
  String get activityFilterStartDate => 'DESDE';

  @override
  String get activityFilterEndDate => 'HASTA';

  @override
  String get activityFilterTimezoneHint => 'El mes se interpreta según tu zona horaria.';

  @override
  String activityFilterRangeHint(Object month) {
    return 'Elige fechas dentro de $month.';
  }

  @override
  String get activityFilterApply => 'Aplicar filtros';

  @override
  String get activityFilterReset => 'Restablecer';

  @override
  String activityFilterUseMonth(Object month) {
    return 'Usar $month';
  }

  @override
  String get activityFilterUseDate => 'Usar fecha';

  @override
  String get activityFilterAllDates => 'Todas las fechas';

  @override
  String activityFilterSelectedDetails(Object account, Object range) {
    return '$account · $range';
  }

  @override
  String get activityShare => 'Compartir';

  @override
  String get activityShareSubject => 'Actividad de LumioMoney';

  @override
  String get activityShareFailed =>
      'No se pudo preparar o compartir el archivo. Inténtalo de nuevo.';

  @override
  String get activityShareEmpty => 'No hay movimientos para compartir.';

  @override
  String get activityMovements => 'Movimientos';

  @override
  String activityMovementCount(int count) {
    return 'Movimientos · $count';
  }

  @override
  String get activityExportAction => 'Exportar';

  @override
  String get activityExportTitle => 'Exportar CSV';

  @override
  String get activityExportSubtitle => 'Revisa la selección antes de continuar.';

  @override
  String get activityExportAccount => 'Cuenta';

  @override
  String get activityExportPeriod => 'Periodo';

  @override
  String get activityExportType => 'Tipo';

  @override
  String get activityExportCurrencyFormat => 'Moneda · Formato';

  @override
  String activityExportConfirmedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimientos confirmados',
      one: '1 movimiento confirmado',
      zero: '0 movimientos confirmados',
    );
    return '$_temp0';
  }

  @override
  String activityExportIncludedCount(int count) {
    return '$count movimientos incluidos';
  }

  @override
  String activityExportMoreCount(int count) {
    return 'y $count más';
  }

  @override
  String get activityExportIncludePending => 'Incluir pendientes';

  @override
  String activityExportPendingExcluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimientos pendientes excluidos. Activa para incluirlos.',
      one: '1 movimiento pendiente excluido. Activa para incluirlo.',
    );
    return '$_temp0';
  }

  @override
  String activityExportPendingIncluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimientos pendientes se incluirán e identificarán como pendientes.',
      one: '1 movimiento pendiente se incluirá e identificará como pendiente.',
    );
    return '$_temp0';
  }

  @override
  String get activityExportAllResults =>
      'Se exportan todos los resultados de los filtros, no solo los cargados. Se conservan el orden, las fechas y la zona horaria.';

  @override
  String get activityExportNoNotes => 'No incluye notas. Guardar y compartir usan el mismo CSV.';

  @override
  String get activityExportSave => 'Guardar archivo';

  @override
  String get activityExportShare => 'Compartir archivo';

  @override
  String activityExportPreparing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimientos',
      one: '1 movimiento',
    );
    return 'Preparando $_temp0…';
  }

  @override
  String get activityExportErrorTitle => 'No pudimos generar el archivo';

  @override
  String get activityExportErrorMessage =>
      'Ocurrió un problema temporal. Tu selección sigue aquí; puedes intentarlo de nuevo.';

  @override
  String get activityExportCloseHint => 'Al cerrar, se conservan tus filtros y selección.';

  @override
  String get activityTotalsTitle => 'Resumen';

  @override
  String get activityTotalsIncome => 'Ingresos';

  @override
  String get activityTotalsExpenses => 'Egresos';

  @override
  String get activityTotalsNet => 'Resultado';

  @override
  String get activityTotalsMethodNote => 'Ingresos − egresos · Transferencias excluidas';

  @override
  String get activityTransfersTotalsNote =>
      'Las transferencias no se suman a ingresos, egresos ni resultado.';

  @override
  String get activityTotalsEmpty =>
      'No hay ingresos ni egresos confirmados para calcular los totales.';

  @override
  String get activityCsvDate => 'Fecha y hora';

  @override
  String get activityCsvType => 'Tipo';

  @override
  String get activityCsvDescription => 'Descripción';

  @override
  String get activityCsvAccount => 'Cuenta(s)';

  @override
  String get activityCsvCategory => 'Categoría';

  @override
  String get activityCsvAmount => 'Importe';

  @override
  String get activityCsvCurrency => 'Moneda';

  @override
  String get activityCsvStatus => 'Estado';

  @override
  String get activityCsvPending => 'Pendiente';

  @override
  String get activityCsvConfirmed => 'Confirmado';

  @override
  String get activityCsvRejected => 'Rechazado';

  @override
  String get activityCsvUnknownAccount => 'Cuenta desconocida';

  @override
  String get activityCsvUnknownCategory => 'Categoría desconocida';

  @override
  String get transferOperationLabel => 'Transferencia';

  @override
  String get budget => 'Presupuesto';

  @override
  String get accounts => 'Cuentas';

  @override
  String get accountsTitle => 'Cuentas y deudas';

  @override
  String get accountsSubtitle => 'Dinero, tarjetas y préstamos en un solo lugar';

  @override
  String get addAccount => 'Agregar cuenta';

  @override
  String get cashAccountType => 'Efectivo';

  @override
  String get checkingAccountType => 'Cuenta corriente';

  @override
  String get savingsAccountType => 'Cuenta de ahorros';

  @override
  String get addMovement => 'Agregar movimiento';

  @override
  String get addMovementChoiceTitle => '¿Qué quieres agregar?';

  @override
  String get addMovementChoiceSubtitle => 'Elige una opción para continuar';

  @override
  String get moveMoney => 'Mover dinero';

  @override
  String get close => 'Cerrar';

  @override
  String get transferExplanation =>
      'Mover dinero pasa fondos entre tus cuentas propias. No suma ni resta al saldo total.';

  @override
  String incomeRegistered(Object amount) {
    return 'Ingreso registrado · $amount';
  }

  @override
  String expenseRegistered(Object amount) {
    return 'Gasto registrado · $amount';
  }

  @override
  String get transferRegistered => 'Transferencia registrada';

  @override
  String get viewMovement => 'Ver movimiento';

  @override
  String get viewDetails => 'Ver detalle';

  @override
  String get viewPendingOperations => 'Ver pendientes';

  @override
  String get pendingBalanceNote =>
      'Hay movimientos guardados en este dispositivo. El saldo confirmado puede no incluirlos todavía.';

  @override
  String get notVisibleWithCurrentFilters => 'No aparece con los filtros actuales';

  @override
  String get genericError => 'Ocurrió un problema. Inténtalo de nuevo.';

  @override
  String get createFirstAccount => 'Crea tu primera cuenta para empezar.';

  @override
  String get plannedAmountLabel => 'Total planeado';

  @override
  String get timeZone => 'Región horaria';

  @override
  String get timeZoneBogota => 'Bogotá (UTC−5)';

  @override
  String get timeZoneMexicoCity => 'Ciudad de México (UTC−6)';

  @override
  String get timeZoneSaoPaulo => 'São Paulo (UTC−3)';

  @override
  String get createCategory => 'Crear categoría';

  @override
  String get manageCategories => 'Administrar categorías';

  @override
  String get editCategory => 'Editar categoría';

  @override
  String get edit => 'Editar';

  @override
  String get categoriesSubtitle => 'Organiza tus movimientos con nombres conocidos.';

  @override
  String get categorySavedDescription => 'El nombre se verá en tus movimientos y presupuestos.';

  @override
  String get confirmArchiveCategoryTitle => '¿Archivar esta categoría?';

  @override
  String get categoryName => 'Nombre';

  @override
  String get categoryTypeReadOnly => 'Tipo · no se puede cambiar';

  @override
  String get saveCategoryChanges => 'Guardar cambios';

  @override
  String get archiveCategoryDetails =>
      'Dejará de aparecer en nuevos movimientos. Los registros existentes conservarán esta categoría.';

  @override
  String get categoryNameRequired => 'Escribe un nombre para la categoría.';

  @override
  String get categorySaved => 'Categoría actualizada';

  @override
  String get newCategory => 'Nueva categoría';

  @override
  String get archive => 'Archivar';

  @override
  String get adjustAccountBalance => 'Ajustar saldo';

  @override
  String get balanceAdjustmentTitle => 'Ajustar saldos';

  @override
  String get balanceAdjustmentSubtitle => 'El saldo inicial y tus movimientos no cambiarán.';

  @override
  String get balanceAdjustmentTarget => 'Saldo real';

  @override
  String balanceAdjustmentCurrent(Object balance) {
    return 'Saldo actual: $balance';
  }

  @override
  String get balanceAdjustmentPrevious => 'Saldo anterior';

  @override
  String get balanceAdjustmentDifferenceLabel => 'Diferencia';

  @override
  String balanceAdjustmentDifference(Object amount) {
    return 'Diferencia: $amount';
  }

  @override
  String get balanceAdjustmentReason => 'Motivo (opcional)';

  @override
  String get balanceAdjustmentOtherDevicesHint =>
      'Sincroniza primero los movimientos pendientes en tus otros dispositivos; podrían cambiar estos saldos después.';

  @override
  String get balanceAdjustmentPendingHint =>
      'Resuelve los movimientos pendientes, en sincronización o rechazados de las cuentas seleccionadas antes de ajustar.';

  @override
  String get balanceAdjustmentSave => 'Guardar ajustes';

  @override
  String get balanceAdjustmentNoop => 'El saldo objetivo ya coincide con el saldo actual.';

  @override
  String get balanceAdjustmentInvalidAmount =>
      'Ingresa un saldo válido dentro del límite permitido.';

  @override
  String get balanceAdjustmentSuccess => 'Saldos actualizados.';

  @override
  String get confirmArchiveCategory =>
      'La categoría se archivará y se conservará en tus movimientos anteriores.';

  @override
  String get expenseCategories => 'Gastos';

  @override
  String get incomeCategories => 'Ingresos';

  @override
  String get systemCategory => 'Predeterminada';

  @override
  String get customCategory => 'Personalizada';

  @override
  String get noCategories => 'Aún no tienes categorías para este tipo.';

  @override
  String get categoryType => 'Tipo de categoría';

  @override
  String get newAccount => 'Nueva cuenta';

  @override
  String get accountName => 'Nombre de la cuenta';

  @override
  String get initialBalance => 'Saldo inicial';

  @override
  String get editAccount => 'Editar cuenta';

  @override
  String get confirmArchiveAccount =>
      'La cuenta se archivará. Tu historial y saldo se conservarán.';

  @override
  String get deleteOperation => 'Eliminar movimiento';

  @override
  String get confirmDeleteOperation =>
      'Este movimiento se eliminará de tu actividad y se recalculará el saldo.';

  @override
  String get editOperation => 'Editar movimiento';

  @override
  String get savedPending =>
      'Guardamos el movimiento en este dispositivo. Se sincronizará cuando vuelva la conexión.';

  @override
  String get categories => 'Categorías';

  @override
  String get income => 'Ingreso';

  @override
  String get expense => 'Gasto';

  @override
  String get transfer => 'Transferir';

  @override
  String get addIncome => 'Agregar ingreso';

  @override
  String get addExpense => 'Agregar gasto';

  @override
  String get transferMoney => 'Transferir dinero';

  @override
  String get currentBalance => 'Balance actual';

  @override
  String get recentActivity => 'Actividad reciente';

  @override
  String get noTransactions => 'Aún no tienes movimientos.';

  @override
  String get amount => 'Monto';

  @override
  String get amountInvalid => 'Ingresa un monto válido mayor que cero.';

  @override
  String get amountTooLarge => 'El monto no puede superar 1.000.000.000 en esta moneda.';

  @override
  String get operationAccountRequired => 'Selecciona una cuenta.';

  @override
  String get operationCategoryRequired => 'Selecciona una categoría.';

  @override
  String get transferSourceRequired => 'Selecciona la cuenta de origen.';

  @override
  String get transferDestinationRequired => 'Selecciona la cuenta de destino.';

  @override
  String get transferAccountsDifferent => 'Elige dos cuentas distintas con la misma moneda.';

  @override
  String get budgetDayInvalidForMonth => 'Elige un día que exista en el mes seleccionado.';

  @override
  String get onboardingAccountRequired => 'Escribe el nombre de tu primera cuenta.';

  @override
  String get type => 'Tipo';

  @override
  String get date => 'Fecha';

  @override
  String get time => 'Hora';

  @override
  String get account => 'Cuenta';

  @override
  String get category => 'Categoría';

  @override
  String get descriptionOptional => 'Descripción (opcional)';

  @override
  String get save => 'Guardar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get sourceAccount => 'Cuenta origen';

  @override
  String get destinationAccount => 'Cuenta destino';

  @override
  String get optionalNote => 'Nota opcional';

  @override
  String get confirmTransfer => 'Confirmar transferencia';

  @override
  String get reviewTransfer => 'Revisar transferencia';

  @override
  String get invalidTransfer =>
      'Selecciona cuentas distintas con la misma moneda y un monto válido.';

  @override
  String get completeRequiredFields => 'Completa monto, cuenta y categoría.';

  @override
  String budgetTracking(Object month) {
    return 'Seguimiento · $month';
  }

  @override
  String get noBudgetsThisMonth => 'No hay presupuestos para este mes.';

  @override
  String planned(Object amount) {
    return 'Planeado $amount';
  }

  @override
  String actual(Object amount) {
    return 'Real $amount';
  }

  @override
  String remaining(Object amount) {
    return 'Restante $amount';
  }

  @override
  String exceeded(Object amount) {
    return 'Excedido $amount';
  }

  @override
  String get createBudget => 'Crear presupuesto';

  @override
  String get newBudget => 'Nuevo presupuesto';

  @override
  String get budgetItem => 'Item';

  @override
  String get budgetCategory => 'Categoría';

  @override
  String get budgetSaved => 'Presupuesto guardado';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get sessionExpired => 'Sesión expirada';

  @override
  String loadError(Object message) {
    return 'No se pudo cargar: $message';
  }

  @override
  String get retry => 'Reintentar';

  @override
  String get offlinePending => 'Sincronización pendiente';

  @override
  String get offlineRejected => 'No se pudo sincronizar. Puedes reintentar.';

  @override
  String get syncIssueNetwork =>
      'No hay conexión con el servidor. El movimiento sigue guardado aquí; inténtalo cuando vuelva la conexión.';

  @override
  String get syncIssuePermissionDenied =>
      'Firebase rechazó el movimiento. Comprueba tu sesión; si continúa, comparte el código de diagnóstico con soporte.';

  @override
  String get syncIssueInvalidOperation =>
      'El movimiento no coincide con los datos actuales. Revisa la cuenta, categoría o presupuesto antes de reintentar.';

  @override
  String get syncIssueUnexpected =>
      'No pudimos identificar la causa. Comparte el código de diagnóstico con soporte.';

  @override
  String syncDiagnosticCode(Object code) {
    return 'Código de diagnóstico: $code';
  }

  @override
  String get syncing => 'Sincronizando...';

  @override
  String get synced => 'Sincronizado';

  @override
  String get changeMonth => 'Cambiar mes';

  @override
  String get byCategory => 'Por categoría';

  @override
  String get plannedSummary => 'Planeado · real · restante';

  @override
  String plannedTotal(Object amount) {
    return '$amount planeado';
  }

  @override
  String usedSummary(Object currency, Object percent, Object remaining) {
    return '$currency · $percent% utilizado · $remaining restante';
  }

  @override
  String get unbudgetedMovements => 'Movimientos sin presupuesto';

  @override
  String get reviewCategories => 'Revisar categorías';

  @override
  String get viewBudgetDetails => 'Ver detalle del presupuesto';

  @override
  String get accountFormCreateSubtitle => 'Elige cómo quieres organizar este dinero.';

  @override
  String get accountFormEditSubtitle =>
      'Puedes cambiar el nombre; el saldo y el tipo se conservan con tu historial.';

  @override
  String get accountNameHint => 'Por ejemplo, Gastos diarios';

  @override
  String get accountType => 'Tipo de cuenta';

  @override
  String get accountCurrency => 'Moneda';

  @override
  String get openingBalanceHelper =>
      'Ingresa 0 o más. Puedes actualizar el saldo con tus movimientos.';

  @override
  String profileCurrencyHint(Object currency) {
    return 'La moneda de tu perfil es $currency.';
  }

  @override
  String get accountBalanceReadOnlyHelper =>
      'El saldo cambia al agregar ingresos, gastos o transferencias.';

  @override
  String get accountNameRequired => 'Escribe el nombre de la cuenta.';

  @override
  String get invalidInitialBalance => 'Ingresa un saldo válido de 0 o más.';

  @override
  String get accountSaveFailed =>
      'No pudimos guardar la cuenta. La información sigue aquí; inténtalo de nuevo.';

  @override
  String get budgetCreateTitle => 'Planea por categoría';

  @override
  String get budgetCreateSubtitle => 'Define cada elemento para tu mes.';

  @override
  String get budgetTrackingTitle => 'Seguimiento';

  @override
  String get viewBudgetTracking => 'Ver seguimiento';

  @override
  String get budgetTrackingEmptyTitle => 'Aún no hay presupuestos';

  @override
  String get budgetTrackingEmptyMessage =>
      'Crea un presupuesto para comparar lo planeado con tus movimientos del mes.';

  @override
  String budgetUsedPercent(Object percent) {
    return '$percent% utilizado';
  }

  @override
  String budgetReceivedPercent(Object percent) {
    return '$percent% recibido';
  }

  @override
  String unbudgetedCategoryCount(Object count) {
    return '$count categorías tienen movimientos sin presupuesto';
  }

  @override
  String unbudgetedActualAmount(Object amount) {
    return 'Total sin presupuesto · $amount';
  }

  @override
  String get budgetMonth => 'Mes';

  @override
  String get budgetSelectMonth => 'Elige un mes';

  @override
  String get budgetPlannedItems => 'Elementos planeados';

  @override
  String get budgetAddItem => 'Agregar elemento';

  @override
  String get budgetRemoveItem => 'Quitar';

  @override
  String get budgetItemDescription => 'Descripción del elemento';

  @override
  String get budgetDescriptionRequired => 'Escribe una descripción.';

  @override
  String get budgetAmountPositive => 'Ingresa un monto mayor que cero.';

  @override
  String get budgetSelectCategory => 'Selecciona una categoría.';

  @override
  String get budgetNoCategories =>
      'No hay categorías para este tipo. Crea una categoría para continuar.';

  @override
  String get budgetValidateItems => 'Revisa la descripción, el monto y el día de cada elemento.';

  @override
  String get budgetAlreadyExists => 'Ya existe un presupuesto para esta categoría y este mes.';

  @override
  String get budgetSaveFailed =>
      'No pudimos guardar el presupuesto. Tus datos siguen aquí; inténtalo de nuevo.';

  @override
  String get budgetSave => 'Guardar presupuesto';

  @override
  String get budgetsTitle => 'Tus presupuestos';

  @override
  String get budgetsSubtitle => 'Planea y revisa el avance del mes';

  @override
  String get budgetsForMonth => 'Presupuestos del mes';

  @override
  String get budgetFilterAll => 'Todos';

  @override
  String get budgetFilterExpenses => 'Gastos';

  @override
  String get budgetFilterIncome => 'Ingresos';

  @override
  String get budgetEmptyTitle => 'Aún no tienes presupuestos';

  @override
  String get budgetEmptyMessage =>
      'Crea un presupuesto por categoría para saber cuánto planeas y cuánto te queda durante el mes.';

  @override
  String get budgetFilteredEmptyTitle => 'No hay resultados para este filtro';

  @override
  String get budgetFilteredEmptyMessage => 'Prueba otro filtro para ver tus presupuestos.';

  @override
  String get budgetFilterReset => 'Ver todos';

  @override
  String get budgetSpent => 'Gastado';

  @override
  String get budgetReceived => 'Recibido';

  @override
  String get day => 'Día';

  @override
  String get budgetDetailTitle => 'Detalle del presupuesto';

  @override
  String get budgetBackToBudgets => 'Presupuestos';

  @override
  String budgetItemsHeading(Object count) {
    return 'Elementos planeados · $count';
  }

  @override
  String get budgetEditItemTitle => 'Editar elemento';

  @override
  String get budgetAddItemSubtitle => 'Añade otro elemento a este presupuesto.';

  @override
  String get budgetEditItemSubtitle => 'Ajusta el detalle, el importe o el día esperado.';

  @override
  String get budgetDescription => 'Descripción';

  @override
  String budgetPlannedAmount(Object currency) {
    return 'Monto planeado · $currency';
  }

  @override
  String get budgetExpectedDay => 'Día esperado';

  @override
  String get budgetDayRange => 'Elige un día entre 1 y 31.';

  @override
  String get budgetTotalUpdatesHint =>
      'Al guardar, el total planeado se actualizará automáticamente.';

  @override
  String get budgetSaveChanges => 'Guardar cambios';

  @override
  String get budgetEditFailed =>
      'No pudimos guardar los cambios. Tus datos siguen aquí; inténtalo de nuevo.';

  @override
  String get budgetAddItemFailed =>
      'No pudimos agregar el elemento. Tus datos siguen aquí; inténtalo de nuevo.';

  @override
  String get budgetDeleteItemTitle => '¿Quitar este elemento?';

  @override
  String budgetDeleteItemMessage(Object amount) {
    return 'El total planeado bajará en $amount. Los movimientos registrados no cambiarán.';
  }

  @override
  String get budgetLastItemTitle => 'Conserva al menos un elemento';

  @override
  String get budgetLastItemMessage =>
      'Un presupuesto necesita al menos un elemento. Para quitarlo, elimina el presupuesto completo.';

  @override
  String get budgetDeleteBudgetAction => 'Eliminar presupuesto';

  @override
  String get budgetDeleteBudgetTitle => '¿Eliminar este presupuesto?';

  @override
  String get budgetDeleteBudgetMessage =>
      'Se quitará de tus presupuestos activos. Tus movimientos y saldos se conservarán.';

  @override
  String get budgetArchiveSuccess => 'Presupuesto eliminado de la lista activa.';

  @override
  String get budgetDeleteFailed => 'No pudimos eliminar el presupuesto. Inténtalo de nuevo.';

  @override
  String get budgetItemDeleteFailed => 'No pudimos quitar el elemento. Inténtalo de nuevo.';

  @override
  String get budgetItemSaved => 'Cambios guardados.';

  @override
  String get budgetItemAdded => 'Elemento agregado.';

  @override
  String get budgetEditAction => 'Editar';

  @override
  String get categoryIcon => 'Ícono de categoría';

  @override
  String get categoryColor => 'Color de categoría';

  @override
  String get categoryColorDefault => 'Predeterminado';

  @override
  String get categoryColorBlue => 'Azul';

  @override
  String get categoryColorGreen => 'Verde';

  @override
  String get categoryColorOrange => 'Naranja';

  @override
  String get categoryColorPurple => 'Morado';

  @override
  String get categoryColorRed => 'Rojo';

  @override
  String get categoryColorTeal => 'Turquesa';

  @override
  String categoryColorOption(Object color, Object hex) {
    return '$color · $hex';
  }

  @override
  String get changeColor => 'Cambiar';

  @override
  String get useColor => 'Usar color';

  @override
  String get categoryIconLabel => 'Ícono';

  @override
  String get categoryIconUtensils => 'Cubiertos';

  @override
  String get categoryIconHouse => 'Casa';

  @override
  String get categoryIconCar => 'Automóvil';

  @override
  String get categoryIconHeart => 'Corazón';

  @override
  String get categoryIconBook => 'Libro';

  @override
  String get categoryIconBriefcase => 'Maletín';

  @override
  String get categoryIconTag => 'Etiqueta';

  @override
  String get changeIcon => 'Cambiar';

  @override
  String get useIcon => 'Usar ícono';

  @override
  String get budgetConfirmMonth => 'Confirmar mes';

  @override
  String get categoryIconFood => 'Comida';

  @override
  String get categoryIconHousing => 'Vivienda';

  @override
  String get categoryIconTransport => 'Transporte';

  @override
  String get categoryIconHealth => 'Salud';

  @override
  String get categoryIconEducation => 'Educación';

  @override
  String get categoryIconSalary => 'Salario';

  @override
  String get categoryIconOther => 'Otros';

  @override
  String budgetItemActual(Object amount) {
    return 'Registrado: $amount';
  }

  @override
  String get budgetRecordExpense => 'Registrar gasto';

  @override
  String get budgetRecordIncome => 'Registrar ingreso';

  @override
  String budgetItemNoCompatibleAccount(Object currency) {
    return 'Necesitas una cuenta activa en $currency para registrar este movimiento.';
  }

  @override
  String budgetItemMovementContext(Object description) {
    return 'Movimiento para el elemento: $description';
  }

  @override
  String get budgetArchivedItems => 'Elementos retirados';

  @override
  String get budgetItemArchived => 'Retirado · movimientos conservados';

  @override
  String get budgetItemLinkedMovements => 'Movimientos vinculados';

  @override
  String get budgetItemNoLinkedMovements => 'Aún no hay movimientos vinculados.';

  @override
  String get budgetLinkedMovementConfirmed => 'Confirmado';

  @override
  String get budgetLinkedMovementPending => 'Pendiente de sincronizar';

  @override
  String get budgetLinkedMovementRejected => 'Rechazado · no afecta el total';

  @override
  String budgetArchiveNetworkFailure(Object code) {
    return 'No pudimos conectar. El presupuesto sigue activo; revisa tu conexión e inténtalo de nuevo. Código: $code';
  }

  @override
  String budgetArchivePermissionFailure(Object code) {
    return 'Firebase no autorizó el cambio. El presupuesto sigue activo; comprueba tu sesión y comparte este código con soporte: $code';
  }

  @override
  String budgetArchiveConflictFailure(Object code) {
    return 'No se pudo validar el presupuesto. Sigue activo; comparte este código con soporte: $code';
  }

  @override
  String budgetArchiveUnexpectedFailure(Object code) {
    return 'No pudimos eliminar el presupuesto. Sigue activo; inténtalo de nuevo. Código: $code';
  }

  @override
  String get more => 'Más';

  @override
  String get back => 'Volver';

  @override
  String get moreSubtitle => 'Personaliza LumioMoney y gestiona tus preferencias.';

  @override
  String get moreManagement => 'Gestión';

  @override
  String get moreSession => 'Sesión';

  @override
  String get signOutConfirmTitle => '¿Cerrar sesión?';

  @override
  String get signOutConfirmMessage =>
      'Tendrás que volver a iniciar sesión para acceder a tus datos.';

  @override
  String signOutPendingWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# movimientos pendientes de sincronizar',
      one: '# movimiento pendiente de sincronizar',
    );
    return 'Tienes $_temp0. Cerrar sesión no los elimina, pero pueden necesitar que vuelvas a iniciar sesión para sincronizar.';
  }

  @override
  String get discardChangesTitle => '¿Descartar los cambios?';

  @override
  String get discardChangesMessage => 'Los cambios que hiciste todavía no se han guardado.';

  @override
  String get keepEditing => 'Seguir editando';

  @override
  String get discardChanges => 'Descartar';

  @override
  String get accountIncludeInHomeBalance => 'Incluir en el saldo de Inicio';

  @override
  String get accountIncludeInHomeBalanceHint =>
      'Esta cuenta se sumará al saldo consolidado de Inicio.';

  @override
  String get homeNoAccountsIncluded => 'No hay cuentas activas incluidas en el saldo de Inicio.';

  @override
  String get homeCustomizeTitle => 'Personalizar Inicio';

  @override
  String get homeCustomizeSubtitle =>
      'Elige qué información quieres ver en Inicio. Los avisos de sincronización siempre estarán visibles.';

  @override
  String get homeWidgetsSection => 'Tarjetas de Inicio';

  @override
  String get homeBudgetCardsSection => 'Presupuestos por categoría';

  @override
  String get homeWidgetTotalBalance => 'Saldo total';

  @override
  String get homeWidgetIncome => 'Resumen de ingresos';

  @override
  String get homeWidgetExpense => 'Resumen de gastos';

  @override
  String get homeWidgetExpenseBudget => 'Gasto vs. presupuesto';

  @override
  String get homeWidgetIncomeBudget => 'Ingreso vs. presupuesto';

  @override
  String get homeWidgetRecentActivity => 'Actividad reciente';

  @override
  String get homeNoBudgetCards => 'No hay presupuestos activos para personalizar.';

  @override
  String get homePreferencesSaving => 'Guardando preferencia…';

  @override
  String get homePreferencesSaveFailed =>
      'No se pudo guardar. Tu selección se conserva; inténtalo de nuevo.';

  @override
  String get coachTitle => 'Coach y recordatorios';

  @override
  String get coachSettingsIntro =>
      'Organiza tu rutina y elige cuándo quieres revisar tus finanzas.';

  @override
  String get coachDailyTitle => 'Cierre diario';

  @override
  String get coachWeeklyTitle => 'Revisión semanal';

  @override
  String get coachNextStepTitle => 'Tu siguiente paso';

  @override
  String get coachDailyReminder => 'Recordatorio de cierre diario';

  @override
  String get coachWeeklyReminder => 'Recordatorio de revisión semanal';

  @override
  String get coachReminderTime => 'Hora del recordatorio';

  @override
  String get coachReminderDays => 'Días de la semana';

  @override
  String get coachDevice => 'En este dispositivo';

  @override
  String get coachEnableDevice => 'Recibir recordatorios en este dispositivo';

  @override
  String get coachDevicePrivacy => 'Los avisos no muestran importes ni datos de tus cuentas.';

  @override
  String get coachWindowNotice =>
      'Abre la app al menos una vez cada 28 días para renovar los avisos. Los cambios de otros dispositivos se aplican al sincronizar.';

  @override
  String get coachPause => 'Pausar durante siete días';

  @override
  String get coachResume => 'Reactivar recordatorios';

  @override
  String get coachPaused => 'Recordatorios pausados';

  @override
  String get coachPermissionGranted => 'Notificaciones permitidas';

  @override
  String get coachPermissionDenied =>
      'Las notificaciones están bloqueadas en los ajustes del dispositivo.';

  @override
  String get coachPermissionUnknown => 'Activa los avisos para solicitar permiso.';

  @override
  String get coachUnsupported =>
      'En web puedes revisar tu rutina. Los recordatorios están disponibles en Android e iOS.';

  @override
  String get coachOpenSettings => 'Abrir ajustes del dispositivo';

  @override
  String get coachReviewed => 'Revisado';

  @override
  String get coachFinishDaily => 'Ya revisé mis movimientos';

  @override
  String get coachNoMovements => 'Hoy no tuve movimientos';

  @override
  String get coachFinishWeekly => 'Marcar semana como revisada';

  @override
  String get coachNoRecords => 'No hay movimientos registrados en este periodo.';

  @override
  String get coachAllCurrent => 'Tu rutina está al día.';

  @override
  String get coachDailyAction => 'Revisar mis movimientos';

  @override
  String get coachWeeklyAction => 'Revisar mi semana';

  @override
  String get coachReviewIntro =>
      'Revisa lo registrado antes de completar tu cierre. Registrar un movimiento no completa la revisión.';

  @override
  String get coachWeeklyIntro =>
      'Ingresos, gastos y Resultado según tus movimientos confirmados. Transferencias y ajustes no se suman a estos totales.';

  @override
  String get coachConfirmedCount => 'Movimientos confirmados';

  @override
  String get coachPendingCount => 'Pendientes de sincronización';

  @override
  String get coachRejectedCount => 'Movimientos rechazados';

  @override
  String get coachCached =>
      'Datos guardados en este dispositivo; el periodo puede estar incompleto. Conéctate y actualiza para comprobarlo.';

  @override
  String get coachSavePending =>
      'Revisión guardada en este dispositivo; pendiente de sincronización.';

  @override
  String get coachSaveFailed =>
      'No se pudo guardar. Tu selección se conserva; vuelve a intentarlo.';

  @override
  String get coachSaveConfirmed => 'Revisión guardada';

  @override
  String get coachTopCategories => 'Categorías con mayor gasto';

  @override
  String get coachConfigure => 'Configurar mi rutina';

  @override
  String get coachReadFailure => 'No pudimos cargar tu revisión. Vuelve a intentarlo.';

  @override
  String get coachNotificationTitle => 'Un momento para tus finanzas';

  @override
  String get coachNotificationBody => 'Tu revisión está lista. Abre LumioMoney para continuar.';

  @override
  String get coachHomeWidget => 'Tu siguiente paso del coach';

  @override
  String get coachReminderTiming =>
      'Los avisos pueden llegar más tarde según los ajustes y el ahorro de batería del dispositivo.';

  @override
  String get coachPreferencesPending =>
      'Cambios guardados en este dispositivo; pendientes de sincronización.';

  @override
  String get coachScheduleFailed => 'No pudimos programar los avisos. Reintenta la programación.';

  @override
  String get coachViewMovements => 'Ver movimientos del periodo';

  @override
  String get coachNoMovementsUnavailable =>
      'Ahora hay movimientos registrados o faltan datos actualizados. Revisa el día antes de confirmarlo.';

  @override
  String get plan => 'Plan';

  @override
  String get coachTab => 'Coach';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get accountsSectionOverview => 'Resumen';

  @override
  String get accountsSectionMoney => 'Dinero';

  @override
  String get accountsSectionCards => 'Tarjetas';

  @override
  String get accountsSectionLoans => 'Préstamos';

  @override
  String get accountsSectionEmpty => 'No hay cuentas en esta sección todavía.';

  @override
  String get coachHubTitle => 'Tu coach financiero';

  @override
  String get coachHubSubtitle => 'Revisa tus movimientos y construye una rutina financiera clara.';

  @override
  String get coachHistoryTitle => 'Revisiones recientes';

  @override
  String get coachHistoryEmpty => 'Todavía no has completado revisiones.';

  @override
  String get coachSettingsShortcut => 'Configurar recordatorios';

  @override
  String get debtSelectForPayment =>
      'Elige la tarjeta o el préstamo que ya pagaste. Registrar el pago no mueve dinero por ti.';

  @override
  String get accountDetailTitle => 'Detalle de cuenta';

  @override
  String get operationEditTitle => 'Editar movimiento';

  @override
  String get appearanceTitle => 'Apariencia';

  @override
  String get appearanceSubtitle => 'Personaliza los colores de LumioMoney en tus dispositivos.';

  @override
  String get appearanceMode => 'Tema';

  @override
  String get appearanceSystem => 'Sistema';

  @override
  String get appearanceLight => 'Claro';

  @override
  String get appearanceDark => 'Oscuro';

  @override
  String get appearancePalette => 'Paleta de color';

  @override
  String get paletteLumio => 'Lumio';

  @override
  String get paletteClassicBlue => 'Azul clásico';

  @override
  String get paletteOcean => 'Océano';

  @override
  String get palettePlum => 'Ciruela';

  @override
  String get appearanceSaving => 'Guardando preferencia…';

  @override
  String get appearanceSaved => 'Apariencia sincronizada';

  @override
  String get appearanceSaveFailed =>
      'No se pudo sincronizar la apariencia. Tu selección sigue aplicada.';

  @override
  String get appearanceRetry => 'Reintentar';

  @override
  String get accountKindMoney => 'Cuenta de dinero';

  @override
  String get accountKindCreditCard => 'Tarjeta de crédito';

  @override
  String get accountKindBankLoan => 'Crédito bancario';

  @override
  String get accountKindPersonalLoan => 'Préstamo personal recibido';

  @override
  String get selectionChoosePrompt => 'Seleccionar';

  @override
  String get selectionSearchHint => 'Buscar por nombre o tipo';

  @override
  String get selectionClearSearch => 'Borrar búsqueda';

  @override
  String get selectionNoResults => 'No hay resultados';

  @override
  String get accountOptionBalance => 'Saldo';

  @override
  String get accountOptionDebt => 'Deuda';

  @override
  String get accountOptionCreditBalance => 'Saldo a favor';

  @override
  String get selectionFrequent => 'Frecuentes';

  @override
  String get selectionAll => 'Todas las opciones';

  @override
  String get resetSectionTitle => 'Acciones destructivas';

  @override
  String get resetTitle => 'Reiniciar mis datos';

  @override
  String get resetDescription =>
      'Se borrarán tus movimientos, cuentas y deudas, presupuestos, categorías personalizadas, preferencias, revisiones del Coach y datos de importaciones. Esta acción no se puede deshacer.';

  @override
  String get resetPreserveAccess =>
      'Tu acceso a LumioMoney se conservará. Después volverás al inicio de configuración.';

  @override
  String get resetConfirmTitle => 'Confirma el reinicio';

  @override
  String get resetConfirmMessage => 'Para continuar, escribe la palabra que aparece abajo.';

  @override
  String get resetTypePrompt => 'Escribe REINICIAR';

  @override
  String get resetConfirmWord => 'REINICIAR';

  @override
  String get resetFinalTitle => '¿Borrar todos tus datos?';

  @override
  String get resetFinalMessage =>
      'Se bloquearán los demás dispositivos y se eliminarán tus datos de LumioMoney. No se cerrará tu sesión.';

  @override
  String get resetAction => 'Reiniciar datos';

  @override
  String get resetProgressTitle => 'Reinicio en curso';

  @override
  String get resetProgressMessage =>
      'Estamos eliminando tus datos de forma segura. Mantén esta pantalla abierta o vuelve aquí para continuar si se interrumpe.';

  @override
  String get resetWorking => 'Reiniciando…';

  @override
  String get resetResume => 'Continuar reinicio';

  @override
  String get resetFailure =>
      'No pudimos completar el reinicio. Tus datos siguen bloqueados; puedes reintentar de forma segura.';

  @override
  String resetPendingWarning(Object count) {
    return 'Resuelve primero las $count operaciones pendientes, en sincronización o rechazadas. No se borró ningún dato.';
  }

  @override
  String get resetPendingCheckFailure =>
      'No pudimos verificar los movimientos pendientes. Inténtalo de nuevo antes de reiniciar.';
}
