// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'LumioMoney';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get continueAsGuest => 'Continuar como invitado';

  @override
  String get authLoginTab => 'Iniciar sesión';

  @override
  String get authEmailLabel => 'Correo electrónico';

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
  String get activityTotalsTitle => 'Totales confirmados';

  @override
  String get activityTotalsIncome => 'Ingresos';

  @override
  String get activityTotalsExpenses => 'Egresos';

  @override
  String get activityTotalsNet => 'Saldo neto';

  @override
  String get activityTotalsPendingNote =>
      'Los totales incluyen solo movimientos confirmados. No incluyen pendientes ni transferencias.';

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
  String get accountsTitle => 'Tus cuentas';

  @override
  String get accountsSubtitle => 'Saldos organizados por moneda';

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
}
