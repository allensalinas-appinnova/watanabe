import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('es'), Locale('pt')];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'ClearBudget'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginTitle;

  /// No description provided for @createAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get createAccount;

  /// No description provided for @continueAsGuest.
  ///
  /// In es, this message translates to:
  /// **'Continuar como invitado'**
  String get continueAsGuest;

  /// No description provided for @dashboardTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu dinero, con claridad.'**
  String get dashboardTitle;

  /// No description provided for @setupTitle.
  ///
  /// In es, this message translates to:
  /// **'Configura ClearBudget'**
  String get setupTitle;

  /// No description provided for @personalizeExperience.
  ///
  /// In es, this message translates to:
  /// **'Prepara tu espacio'**
  String get personalizeExperience;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige tus preferencias. Puedes cambiarlas después.'**
  String get onboardingSubtitle;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @country.
  ///
  /// In es, this message translates to:
  /// **'País'**
  String get country;

  /// No description provided for @baseCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda base'**
  String get baseCurrency;

  /// No description provided for @firstAccountName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de tu primera cuenta'**
  String get firstAccountName;

  /// No description provided for @continueAction.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueAction;

  /// No description provided for @home.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get home;

  /// No description provided for @activity.
  ///
  /// In es, this message translates to:
  /// **'Actividad'**
  String get activity;

  /// No description provided for @activitySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Encuentra y revisa tus movimientos'**
  String get activitySubtitle;

  /// No description provided for @activityFilterAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get activityFilterAll;

  /// No description provided for @transferOperationLabel.
  ///
  /// In es, this message translates to:
  /// **'Transferencia'**
  String get transferOperationLabel;

  /// No description provided for @budget.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto'**
  String get budget;

  /// No description provided for @accounts.
  ///
  /// In es, this message translates to:
  /// **'Cuentas'**
  String get accounts;

  /// No description provided for @accountsTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus cuentas'**
  String get accountsTitle;

  /// No description provided for @accountsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Saldos organizados por moneda'**
  String get accountsSubtitle;

  /// No description provided for @addAccount.
  ///
  /// In es, this message translates to:
  /// **'Agregar cuenta'**
  String get addAccount;

  /// No description provided for @cashAccountType.
  ///
  /// In es, this message translates to:
  /// **'Efectivo'**
  String get cashAccountType;

  /// No description provided for @checkingAccountType.
  ///
  /// In es, this message translates to:
  /// **'Cuenta corriente'**
  String get checkingAccountType;

  /// No description provided for @savingsAccountType.
  ///
  /// In es, this message translates to:
  /// **'Cuenta de ahorros'**
  String get savingsAccountType;

  /// No description provided for @addMovement.
  ///
  /// In es, this message translates to:
  /// **'Agregar movimiento'**
  String get addMovement;

  /// No description provided for @genericError.
  ///
  /// In es, this message translates to:
  /// **'Ocurrió un problema. Inténtalo de nuevo.'**
  String get genericError;

  /// No description provided for @createFirstAccount.
  ///
  /// In es, this message translates to:
  /// **'Crea tu primera cuenta para empezar.'**
  String get createFirstAccount;

  /// No description provided for @plannedAmountLabel.
  ///
  /// In es, this message translates to:
  /// **'Total planeado'**
  String get plannedAmountLabel;

  /// No description provided for @timeZone.
  ///
  /// In es, this message translates to:
  /// **'Región horaria'**
  String get timeZone;

  /// No description provided for @timeZoneBogota.
  ///
  /// In es, this message translates to:
  /// **'Bogotá (UTC−5)'**
  String get timeZoneBogota;

  /// No description provided for @timeZoneMexicoCity.
  ///
  /// In es, this message translates to:
  /// **'Ciudad de México (UTC−6)'**
  String get timeZoneMexicoCity;

  /// No description provided for @timeZoneSaoPaulo.
  ///
  /// In es, this message translates to:
  /// **'São Paulo (UTC−3)'**
  String get timeZoneSaoPaulo;

  /// No description provided for @createCategory.
  ///
  /// In es, this message translates to:
  /// **'Crear categoría'**
  String get createCategory;

  /// No description provided for @manageCategories.
  ///
  /// In es, this message translates to:
  /// **'Administrar categorías'**
  String get manageCategories;

  /// No description provided for @editCategory.
  ///
  /// In es, this message translates to:
  /// **'Editar categoría'**
  String get editCategory;

  /// No description provided for @edit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @categoriesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Organiza tus movimientos con nombres conocidos.'**
  String get categoriesSubtitle;

  /// No description provided for @categorySavedDescription.
  ///
  /// In es, this message translates to:
  /// **'El nombre se verá en tus movimientos y presupuestos.'**
  String get categorySavedDescription;

  /// No description provided for @confirmArchiveCategoryTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Archivar esta categoría?'**
  String get confirmArchiveCategoryTitle;

  /// No description provided for @categoryName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get categoryName;

  /// No description provided for @categoryTypeReadOnly.
  ///
  /// In es, this message translates to:
  /// **'Tipo · no se puede cambiar'**
  String get categoryTypeReadOnly;

  /// No description provided for @saveCategoryChanges.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get saveCategoryChanges;

  /// No description provided for @archiveCategoryDetails.
  ///
  /// In es, this message translates to:
  /// **'Dejará de aparecer en nuevos movimientos. Los registros existentes conservarán esta categoría.'**
  String get archiveCategoryDetails;

  /// No description provided for @categoryNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe un nombre para la categoría.'**
  String get categoryNameRequired;

  /// No description provided for @categorySaved.
  ///
  /// In es, this message translates to:
  /// **'Categoría actualizada'**
  String get categorySaved;

  /// No description provided for @newCategory.
  ///
  /// In es, this message translates to:
  /// **'Nueva categoría'**
  String get newCategory;

  /// No description provided for @archive.
  ///
  /// In es, this message translates to:
  /// **'Archivar'**
  String get archive;

  /// No description provided for @confirmArchiveCategory.
  ///
  /// In es, this message translates to:
  /// **'La categoría se archivará y se conservará en tus movimientos anteriores.'**
  String get confirmArchiveCategory;

  /// No description provided for @expenseCategories.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get expenseCategories;

  /// No description provided for @incomeCategories.
  ///
  /// In es, this message translates to:
  /// **'Ingresos'**
  String get incomeCategories;

  /// No description provided for @systemCategory.
  ///
  /// In es, this message translates to:
  /// **'Predeterminada'**
  String get systemCategory;

  /// No description provided for @customCategory.
  ///
  /// In es, this message translates to:
  /// **'Personalizada'**
  String get customCategory;

  /// No description provided for @noCategories.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes categorías para este tipo.'**
  String get noCategories;

  /// No description provided for @categoryType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de categoría'**
  String get categoryType;

  /// No description provided for @newAccount.
  ///
  /// In es, this message translates to:
  /// **'Nueva cuenta'**
  String get newAccount;

  /// No description provided for @accountName.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la cuenta'**
  String get accountName;

  /// No description provided for @initialBalance.
  ///
  /// In es, this message translates to:
  /// **'Saldo inicial'**
  String get initialBalance;

  /// No description provided for @editAccount.
  ///
  /// In es, this message translates to:
  /// **'Editar cuenta'**
  String get editAccount;

  /// No description provided for @confirmArchiveAccount.
  ///
  /// In es, this message translates to:
  /// **'La cuenta se archivará. Tu historial y saldo se conservarán.'**
  String get confirmArchiveAccount;

  /// No description provided for @deleteOperation.
  ///
  /// In es, this message translates to:
  /// **'Eliminar movimiento'**
  String get deleteOperation;

  /// No description provided for @confirmDeleteOperation.
  ///
  /// In es, this message translates to:
  /// **'Este movimiento se eliminará de tu actividad y se recalculará el saldo.'**
  String get confirmDeleteOperation;

  /// No description provided for @editOperation.
  ///
  /// In es, this message translates to:
  /// **'Editar movimiento'**
  String get editOperation;

  /// No description provided for @savedPending.
  ///
  /// In es, this message translates to:
  /// **'Guardamos el movimiento en este dispositivo. Se sincronizará cuando vuelva la conexión.'**
  String get savedPending;

  /// No description provided for @categories.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get categories;

  /// No description provided for @income.
  ///
  /// In es, this message translates to:
  /// **'Ingreso'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In es, this message translates to:
  /// **'Gasto'**
  String get expense;

  /// No description provided for @transfer.
  ///
  /// In es, this message translates to:
  /// **'Transferir'**
  String get transfer;

  /// No description provided for @addIncome.
  ///
  /// In es, this message translates to:
  /// **'Agregar ingreso'**
  String get addIncome;

  /// No description provided for @addExpense.
  ///
  /// In es, this message translates to:
  /// **'Agregar gasto'**
  String get addExpense;

  /// No description provided for @transferMoney.
  ///
  /// In es, this message translates to:
  /// **'Transferir dinero'**
  String get transferMoney;

  /// No description provided for @currentBalance.
  ///
  /// In es, this message translates to:
  /// **'Balance actual'**
  String get currentBalance;

  /// No description provided for @recentActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad reciente'**
  String get recentActivity;

  /// No description provided for @noTransactions.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes movimientos.'**
  String get noTransactions;

  /// No description provided for @amount.
  ///
  /// In es, this message translates to:
  /// **'Monto'**
  String get amount;

  /// No description provided for @type.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get type;

  /// No description provided for @date.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get date;

  /// No description provided for @account.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get account;

  /// No description provided for @category.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get category;

  /// No description provided for @descriptionOptional.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get descriptionOptional;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @sourceAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta origen'**
  String get sourceAccount;

  /// No description provided for @destinationAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta destino'**
  String get destinationAccount;

  /// No description provided for @optionalNote.
  ///
  /// In es, this message translates to:
  /// **'Nota opcional'**
  String get optionalNote;

  /// No description provided for @confirmTransfer.
  ///
  /// In es, this message translates to:
  /// **'Confirmar transferencia'**
  String get confirmTransfer;

  /// No description provided for @reviewTransfer.
  ///
  /// In es, this message translates to:
  /// **'Revisar transferencia'**
  String get reviewTransfer;

  /// No description provided for @invalidTransfer.
  ///
  /// In es, this message translates to:
  /// **'Selecciona cuentas distintas con la misma moneda y un monto válido.'**
  String get invalidTransfer;

  /// No description provided for @completeRequiredFields.
  ///
  /// In es, this message translates to:
  /// **'Completa monto, cuenta y categoría.'**
  String get completeRequiredFields;

  /// No description provided for @budgetTracking.
  ///
  /// In es, this message translates to:
  /// **'Seguimiento · {month}'**
  String budgetTracking(Object month);

  /// No description provided for @noBudgetsThisMonth.
  ///
  /// In es, this message translates to:
  /// **'No hay presupuestos para este mes.'**
  String get noBudgetsThisMonth;

  /// No description provided for @planned.
  ///
  /// In es, this message translates to:
  /// **'Planeado {amount}'**
  String planned(Object amount);

  /// No description provided for @actual.
  ///
  /// In es, this message translates to:
  /// **'Real {amount}'**
  String actual(Object amount);

  /// No description provided for @remaining.
  ///
  /// In es, this message translates to:
  /// **'Restante {amount}'**
  String remaining(Object amount);

  /// No description provided for @exceeded.
  ///
  /// In es, this message translates to:
  /// **'Excedido {amount}'**
  String exceeded(Object amount);

  /// No description provided for @createBudget.
  ///
  /// In es, this message translates to:
  /// **'Crear presupuesto'**
  String get createBudget;

  /// No description provided for @newBudget.
  ///
  /// In es, this message translates to:
  /// **'Nuevo presupuesto'**
  String get newBudget;

  /// No description provided for @budgetItem.
  ///
  /// In es, this message translates to:
  /// **'Item'**
  String get budgetItem;

  /// No description provided for @budgetCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get budgetCategory;

  /// No description provided for @budgetSaved.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto guardado'**
  String get budgetSaved;

  /// No description provided for @signOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get signOut;

  /// No description provided for @sessionExpired.
  ///
  /// In es, this message translates to:
  /// **'Sesión expirada'**
  String get sessionExpired;

  /// No description provided for @loadError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar: {message}'**
  String loadError(Object message);

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @offlinePending.
  ///
  /// In es, this message translates to:
  /// **'Sincronización pendiente'**
  String get offlinePending;

  /// No description provided for @offlineRejected.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sincronizar. Puedes reintentar.'**
  String get offlineRejected;

  /// No description provided for @syncing.
  ///
  /// In es, this message translates to:
  /// **'Sincronizando...'**
  String get syncing;

  /// No description provided for @synced.
  ///
  /// In es, this message translates to:
  /// **'Sincronizado'**
  String get synced;

  /// No description provided for @changeMonth.
  ///
  /// In es, this message translates to:
  /// **'Cambiar mes'**
  String get changeMonth;

  /// No description provided for @byCategory.
  ///
  /// In es, this message translates to:
  /// **'Por categoría'**
  String get byCategory;

  /// No description provided for @plannedSummary.
  ///
  /// In es, this message translates to:
  /// **'Planeado · real · restante'**
  String get plannedSummary;

  /// No description provided for @plannedTotal.
  ///
  /// In es, this message translates to:
  /// **'{amount} planeado'**
  String plannedTotal(Object amount);

  /// No description provided for @usedSummary.
  ///
  /// In es, this message translates to:
  /// **'{currency} · {percent}% utilizado · {remaining} restante'**
  String usedSummary(Object currency, Object percent, Object remaining);

  /// No description provided for @unbudgetedMovements.
  ///
  /// In es, this message translates to:
  /// **'Movimientos sin presupuesto'**
  String get unbudgetedMovements;

  /// No description provided for @reviewCategories.
  ///
  /// In es, this message translates to:
  /// **'Revisar categorías'**
  String get reviewCategories;

  /// No description provided for @viewBudgetDetails.
  ///
  /// In es, this message translates to:
  /// **'Ver detalle del presupuesto'**
  String get viewBudgetDetails;

  /// No description provided for @accountFormCreateSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige cómo quieres organizar este dinero.'**
  String get accountFormCreateSubtitle;

  /// No description provided for @accountFormEditSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Puedes cambiar el nombre; el saldo y el tipo se conservan con tu historial.'**
  String get accountFormEditSubtitle;

  /// No description provided for @accountNameHint.
  ///
  /// In es, this message translates to:
  /// **'Por ejemplo, Gastos diarios'**
  String get accountNameHint;

  /// No description provided for @accountType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de cuenta'**
  String get accountType;

  /// No description provided for @accountCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get accountCurrency;

  /// No description provided for @openingBalanceHelper.
  ///
  /// In es, this message translates to:
  /// **'Ingresa 0 o más. Puedes actualizar el saldo con tus movimientos.'**
  String get openingBalanceHelper;

  /// No description provided for @profileCurrencyHint.
  ///
  /// In es, this message translates to:
  /// **'La moneda de tu perfil es {currency}.'**
  String profileCurrencyHint(Object currency);

  /// No description provided for @accountBalanceReadOnlyHelper.
  ///
  /// In es, this message translates to:
  /// **'El saldo cambia al agregar ingresos, gastos o transferencias.'**
  String get accountBalanceReadOnlyHelper;

  /// No description provided for @accountNameRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe el nombre de la cuenta.'**
  String get accountNameRequired;

  /// No description provided for @invalidInitialBalance.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un saldo válido de 0 o más.'**
  String get invalidInitialBalance;

  /// No description provided for @accountSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos guardar la cuenta. La información sigue aquí; inténtalo de nuevo.'**
  String get accountSaveFailed;

  /// No description provided for @budgetCreateTitle.
  ///
  /// In es, this message translates to:
  /// **'Planea por categoría'**
  String get budgetCreateTitle;

  /// No description provided for @budgetCreateSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Define cada elemento para tu mes.'**
  String get budgetCreateSubtitle;

  /// No description provided for @budgetTrackingTitle.
  ///
  /// In es, this message translates to:
  /// **'Seguimiento'**
  String get budgetTrackingTitle;

  /// No description provided for @viewBudgetTracking.
  ///
  /// In es, this message translates to:
  /// **'Ver seguimiento'**
  String get viewBudgetTracking;

  /// No description provided for @budgetTrackingEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay presupuestos'**
  String get budgetTrackingEmptyTitle;

  /// No description provided for @budgetTrackingEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Crea un presupuesto para comparar lo planeado con tus movimientos del mes.'**
  String get budgetTrackingEmptyMessage;

  /// No description provided for @budgetUsedPercent.
  ///
  /// In es, this message translates to:
  /// **'{percent}% utilizado'**
  String budgetUsedPercent(Object percent);

  /// No description provided for @budgetReceivedPercent.
  ///
  /// In es, this message translates to:
  /// **'{percent}% recibido'**
  String budgetReceivedPercent(Object percent);

  /// No description provided for @unbudgetedCategoryCount.
  ///
  /// In es, this message translates to:
  /// **'{count} categorías tienen movimientos sin presupuesto'**
  String unbudgetedCategoryCount(Object count);

  /// No description provided for @budgetMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get budgetMonth;

  /// No description provided for @budgetSelectMonth.
  ///
  /// In es, this message translates to:
  /// **'Elige un mes'**
  String get budgetSelectMonth;

  /// No description provided for @budgetPlannedItems.
  ///
  /// In es, this message translates to:
  /// **'Elementos planeados'**
  String get budgetPlannedItems;

  /// No description provided for @budgetAddItem.
  ///
  /// In es, this message translates to:
  /// **'Agregar elemento'**
  String get budgetAddItem;

  /// No description provided for @budgetRemoveItem.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get budgetRemoveItem;

  /// No description provided for @budgetItemDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción del elemento'**
  String get budgetItemDescription;

  /// No description provided for @budgetDescriptionRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe una descripción.'**
  String get budgetDescriptionRequired;

  /// No description provided for @budgetAmountPositive.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un monto mayor que cero.'**
  String get budgetAmountPositive;

  /// No description provided for @budgetSelectCategory.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una categoría.'**
  String get budgetSelectCategory;

  /// No description provided for @budgetNoCategories.
  ///
  /// In es, this message translates to:
  /// **'No hay categorías para este tipo. Crea una categoría para continuar.'**
  String get budgetNoCategories;

  /// No description provided for @budgetValidateItems.
  ///
  /// In es, this message translates to:
  /// **'Revisa la descripción, el monto y el día de cada elemento.'**
  String get budgetValidateItems;

  /// No description provided for @budgetAlreadyExists.
  ///
  /// In es, this message translates to:
  /// **'Ya existe un presupuesto para esta categoría y este mes.'**
  String get budgetAlreadyExists;

  /// No description provided for @budgetSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos guardar el presupuesto. Tus datos siguen aquí; inténtalo de nuevo.'**
  String get budgetSaveFailed;

  /// No description provided for @budgetSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar presupuesto'**
  String get budgetSave;

  /// No description provided for @budgetsTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus presupuestos'**
  String get budgetsTitle;

  /// No description provided for @budgetsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Planea y revisa el avance del mes'**
  String get budgetsSubtitle;

  /// No description provided for @budgetsForMonth.
  ///
  /// In es, this message translates to:
  /// **'Presupuestos del mes'**
  String get budgetsForMonth;

  /// No description provided for @budgetFilterAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get budgetFilterAll;

  /// No description provided for @budgetFilterExpenses.
  ///
  /// In es, this message translates to:
  /// **'Gastos'**
  String get budgetFilterExpenses;

  /// No description provided for @budgetFilterIncome.
  ///
  /// In es, this message translates to:
  /// **'Ingresos'**
  String get budgetFilterIncome;

  /// No description provided for @budgetEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes presupuestos'**
  String get budgetEmptyTitle;

  /// No description provided for @budgetEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Crea un presupuesto por categoría para saber cuánto planeas y cuánto te queda durante el mes.'**
  String get budgetEmptyMessage;

  /// No description provided for @budgetFilteredEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'No hay resultados para este filtro'**
  String get budgetFilteredEmptyTitle;

  /// No description provided for @budgetFilteredEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Prueba otro filtro para ver tus presupuestos.'**
  String get budgetFilteredEmptyMessage;

  /// No description provided for @budgetFilterReset.
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get budgetFilterReset;

  /// No description provided for @budgetSpent.
  ///
  /// In es, this message translates to:
  /// **'Gastado'**
  String get budgetSpent;

  /// No description provided for @budgetReceived.
  ///
  /// In es, this message translates to:
  /// **'Recibido'**
  String get budgetReceived;

  /// No description provided for @day.
  ///
  /// In es, this message translates to:
  /// **'Día'**
  String get day;

  /// No description provided for @budgetDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle del presupuesto'**
  String get budgetDetailTitle;

  /// No description provided for @budgetBackToBudgets.
  ///
  /// In es, this message translates to:
  /// **'Presupuestos'**
  String get budgetBackToBudgets;

  /// No description provided for @budgetItemsHeading.
  ///
  /// In es, this message translates to:
  /// **'Elementos planeados · {count}'**
  String budgetItemsHeading(Object count);

  /// No description provided for @budgetEditItemTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar elemento'**
  String get budgetEditItemTitle;

  /// No description provided for @budgetAddItemSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Añade otro elemento a este presupuesto.'**
  String get budgetAddItemSubtitle;

  /// No description provided for @budgetEditItemSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ajusta el detalle, el importe o el día esperado.'**
  String get budgetEditItemSubtitle;

  /// No description provided for @budgetDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get budgetDescription;

  /// No description provided for @budgetPlannedAmount.
  ///
  /// In es, this message translates to:
  /// **'Monto planeado · {currency}'**
  String budgetPlannedAmount(Object currency);

  /// No description provided for @budgetExpectedDay.
  ///
  /// In es, this message translates to:
  /// **'Día esperado'**
  String get budgetExpectedDay;

  /// No description provided for @budgetDayRange.
  ///
  /// In es, this message translates to:
  /// **'Elige un día entre 1 y 31.'**
  String get budgetDayRange;

  /// No description provided for @budgetTotalUpdatesHint.
  ///
  /// In es, this message translates to:
  /// **'Al guardar, el total planeado se actualizará automáticamente.'**
  String get budgetTotalUpdatesHint;

  /// No description provided for @budgetSaveChanges.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get budgetSaveChanges;

  /// No description provided for @budgetEditFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos guardar los cambios. Tus datos siguen aquí; inténtalo de nuevo.'**
  String get budgetEditFailed;

  /// No description provided for @budgetAddItemFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos agregar el elemento. Tus datos siguen aquí; inténtalo de nuevo.'**
  String get budgetAddItemFailed;

  /// No description provided for @budgetDeleteItemTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Quitar este elemento?'**
  String get budgetDeleteItemTitle;

  /// No description provided for @budgetDeleteItemMessage.
  ///
  /// In es, this message translates to:
  /// **'El total planeado bajará en {amount}. Los movimientos registrados no cambiarán.'**
  String budgetDeleteItemMessage(Object amount);

  /// No description provided for @budgetLastItemTitle.
  ///
  /// In es, this message translates to:
  /// **'Conserva al menos un elemento'**
  String get budgetLastItemTitle;

  /// No description provided for @budgetLastItemMessage.
  ///
  /// In es, this message translates to:
  /// **'Un presupuesto necesita al menos un elemento. Para quitarlo, elimina el presupuesto completo.'**
  String get budgetLastItemMessage;

  /// No description provided for @budgetDeleteBudgetAction.
  ///
  /// In es, this message translates to:
  /// **'Eliminar presupuesto'**
  String get budgetDeleteBudgetAction;

  /// No description provided for @budgetDeleteBudgetTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este presupuesto?'**
  String get budgetDeleteBudgetTitle;

  /// No description provided for @budgetDeleteBudgetMessage.
  ///
  /// In es, this message translates to:
  /// **'Se quitará de tus presupuestos activos. Tus movimientos y saldos se conservarán.'**
  String get budgetDeleteBudgetMessage;

  /// No description provided for @budgetArchiveSuccess.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto eliminado de la lista activa.'**
  String get budgetArchiveSuccess;

  /// No description provided for @budgetDeleteFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos eliminar el presupuesto. Inténtalo de nuevo.'**
  String get budgetDeleteFailed;

  /// No description provided for @budgetItemDeleteFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos quitar el elemento. Inténtalo de nuevo.'**
  String get budgetItemDeleteFailed;

  /// No description provided for @budgetItemSaved.
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados.'**
  String get budgetItemSaved;

  /// No description provided for @budgetItemAdded.
  ///
  /// In es, this message translates to:
  /// **'Elemento agregado.'**
  String get budgetItemAdded;

  /// No description provided for @budgetEditAction.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get budgetEditAction;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
