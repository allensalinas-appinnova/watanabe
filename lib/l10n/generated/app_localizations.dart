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
  /// **'Personaliza tu experiencia'**
  String get personalizeExperience;

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

  /// No description provided for @getStarted.
  ///
  /// In es, this message translates to:
  /// **'Comenzar'**
  String get getStarted;

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
