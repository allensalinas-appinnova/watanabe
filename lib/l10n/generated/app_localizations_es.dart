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
