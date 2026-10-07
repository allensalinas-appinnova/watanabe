// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'ClearBudget';

  @override
  String get loginTitle => 'Iniciar sesión';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get continueAsGuest => 'Continuar como invitado';

  @override
  String get dashboardTitle => 'Tu dinero, con claridad.';

  @override
  String get setupTitle => 'Configura ClearBudget';

  @override
  String get personalizeExperience => 'Personaliza tu experiencia';

  @override
  String get language => 'Idioma';

  @override
  String get country => 'País';

  @override
  String get baseCurrency => 'Moneda base';

  @override
  String get firstAccountName => 'Nombre de tu primera cuenta';

  @override
  String get getStarted => 'Comenzar';

  @override
  String get home => 'Inicio';

  @override
  String get activity => 'Actividad';

  @override
  String get budget => 'Presupuesto';

  @override
  String get accounts => 'Cuentas';

  @override
  String get addMovement => 'Agregar movimiento';

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
}
