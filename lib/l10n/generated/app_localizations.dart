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

  /// No description provided for @debtTitle.
  ///
  /// In es, this message translates to:
  /// **'Tarjetas y préstamos'**
  String get debtTitle;

  /// No description provided for @debtAdd.
  ///
  /// In es, this message translates to:
  /// **'Agregar tarjeta o préstamo'**
  String get debtAdd;

  /// No description provided for @debtMoney.
  ///
  /// In es, this message translates to:
  /// **'Dinero disponible'**
  String get debtMoney;

  /// No description provided for @debtCards.
  ///
  /// In es, this message translates to:
  /// **'Tarjetas de crédito'**
  String get debtCards;

  /// No description provided for @debtLoans.
  ///
  /// In es, this message translates to:
  /// **'Créditos y préstamos'**
  String get debtLoans;

  /// No description provided for @debtProduct.
  ///
  /// In es, this message translates to:
  /// **'Producto'**
  String get debtProduct;

  /// No description provided for @debtPaymentCard.
  ///
  /// In es, this message translates to:
  /// **'Pago de tarjeta'**
  String get debtPaymentCard;

  /// No description provided for @debtPaymentLoan.
  ///
  /// In es, this message translates to:
  /// **'Pago de crédito'**
  String get debtPaymentLoan;

  /// No description provided for @activityFilterDebtPayments.
  ///
  /// In es, this message translates to:
  /// **'Pagos de deudas'**
  String get activityFilterDebtPayments;

  /// No description provided for @activityCsvPaymentType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de pago'**
  String get activityCsvPaymentType;

  /// No description provided for @categoryCatalogSyncMessage.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron actualizar las categorías predeterminadas.'**
  String get categoryCatalogSyncMessage;

  /// No description provided for @categoryIconInterest.
  ///
  /// In es, this message translates to:
  /// **'Intereses y comisiones'**
  String get categoryIconInterest;

  /// No description provided for @debtNewChargesCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría de los cargos nuevos'**
  String get debtNewChargesCategory;

  /// No description provided for @debtNewChargesExpenseNote.
  ///
  /// In es, this message translates to:
  /// **'Solo los cargos nuevos de esta cuota se registran como gasto.'**
  String get debtNewChargesExpenseNote;

  /// No description provided for @debtCreditCard.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta de crédito'**
  String get debtCreditCard;

  /// No description provided for @debtBankLoan.
  ///
  /// In es, this message translates to:
  /// **'Crédito bancario'**
  String get debtBankLoan;

  /// No description provided for @debtPersonalLoan.
  ///
  /// In es, this message translates to:
  /// **'Préstamo personal recibido'**
  String get debtPersonalLoan;

  /// No description provided for @debtRegistered.
  ///
  /// In es, this message translates to:
  /// **'Deuda registrada'**
  String get debtRegistered;

  /// No description provided for @debtCreditBalance.
  ///
  /// In es, this message translates to:
  /// **'Saldo a favor en tarjetas'**
  String get debtCreditBalance;

  /// No description provided for @debtPosition.
  ///
  /// In es, this message translates to:
  /// **'Posición neta registrada'**
  String get debtPosition;

  /// No description provided for @debtPositionNote.
  ///
  /// In es, this message translates to:
  /// **'Solo registros seleccionados; no representa tu patrimonio completo.'**
  String get debtPositionNote;

  /// No description provided for @debtOpeningMode.
  ///
  /// In es, this message translates to:
  /// **'Origen del saldo'**
  String get debtOpeningMode;

  /// No description provided for @debtExisting.
  ///
  /// In es, this message translates to:
  /// **'Deuda existente (no mueve dinero)'**
  String get debtExisting;

  /// No description provided for @debtReceived.
  ///
  /// In es, this message translates to:
  /// **'Préstamo recibido ahora'**
  String get debtReceived;

  /// No description provided for @debtReferenceDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha del saldo inicial'**
  String get debtReferenceDate;

  /// No description provided for @debtPrincipal.
  ///
  /// In es, this message translates to:
  /// **'Capital pendiente'**
  String get debtPrincipal;

  /// No description provided for @debtCharges.
  ///
  /// In es, this message translates to:
  /// **'Cargos devengados pendientes'**
  String get debtCharges;

  /// No description provided for @debtLimit.
  ///
  /// In es, this message translates to:
  /// **'Cupo (opcional)'**
  String get debtLimit;

  /// No description provided for @debtCreditor.
  ///
  /// In es, this message translates to:
  /// **'Acreedor (opcional)'**
  String get debtCreditor;

  /// No description provided for @debtLastFour.
  ///
  /// In es, this message translates to:
  /// **'Últimos 4 dígitos (opcional)'**
  String get debtLastFour;

  /// No description provided for @debtPay.
  ///
  /// In es, this message translates to:
  /// **'Registrar pago'**
  String get debtPay;

  /// No description provided for @debtPayCard.
  ///
  /// In es, this message translates to:
  /// **'Pagar tarjeta'**
  String get debtPayCard;

  /// No description provided for @debtDisburse.
  ///
  /// In es, this message translates to:
  /// **'Registrar desembolso'**
  String get debtDisburse;

  /// No description provided for @debtCharge.
  ///
  /// In es, this message translates to:
  /// **'Registrar cargo'**
  String get debtCharge;

  /// No description provided for @debtRefund.
  ///
  /// In es, this message translates to:
  /// **'Devolución de gasto'**
  String get debtRefund;

  /// No description provided for @debtAdjust.
  ///
  /// In es, this message translates to:
  /// **'Ajustar deuda'**
  String get debtAdjust;

  /// No description provided for @debtPurchase.
  ///
  /// In es, this message translates to:
  /// **'Compra con tarjeta'**
  String get debtPurchase;

  /// No description provided for @debtPreviousCharges.
  ///
  /// In es, this message translates to:
  /// **'Cargos ya registrados que pagas'**
  String get debtPreviousCharges;

  /// No description provided for @debtNewCharges.
  ///
  /// In es, this message translates to:
  /// **'Cargos nuevos pagados ahora'**
  String get debtNewCharges;

  /// No description provided for @debtOriginalPurchase.
  ///
  /// In es, this message translates to:
  /// **'Compra original'**
  String get debtOriginalPurchase;

  /// No description provided for @debtBank.
  ///
  /// In es, this message translates to:
  /// **'Cuenta de dinero'**
  String get debtBank;

  /// No description provided for @debtReview.
  ///
  /// In es, this message translates to:
  /// **'Revisar antes de confirmar'**
  String get debtReview;

  /// No description provided for @debtOnline.
  ///
  /// In es, this message translates to:
  /// **'Requiere conexión. Tu borrador se conserva si falla el guardado.'**
  String get debtOnline;

  /// No description provided for @debtDisabled.
  ///
  /// In es, this message translates to:
  /// **'La función de deudas aún no está activada en el servidor.'**
  String get debtDisabled;

  /// No description provided for @debtErrorSplit.
  ///
  /// In es, this message translates to:
  /// **'Completa el desglose: capital, cargos registrados y cargos nuevos deben sumar el pago.'**
  String get debtErrorSplit;

  /// No description provided for @debtErrorComponents.
  ///
  /// In es, this message translates to:
  /// **'El cambio dejaría capital o cargos negativos. Revisa el desglose y los movimientos posteriores.'**
  String get debtErrorComponents;

  /// No description provided for @debtErrorRefund.
  ///
  /// In es, this message translates to:
  /// **'Revisa la compra original y el importe aún no devuelto.'**
  String get debtErrorRefund;

  /// No description provided for @debtErrorDate.
  ///
  /// In es, this message translates to:
  /// **'La fecha no puede ser anterior al saldo inicial.'**
  String get debtErrorDate;

  /// No description provided for @debtErrorArchive.
  ///
  /// In es, this message translates to:
  /// **'Solo puedes archivar una obligación con saldo cero.'**
  String get debtErrorArchive;

  /// No description provided for @debtErrorReference.
  ///
  /// In es, this message translates to:
  /// **'Revisa la cuenta, moneda, categoría y presupuesto seleccionados.'**
  String get debtErrorReference;

  /// No description provided for @debtOverLimit.
  ///
  /// In es, this message translates to:
  /// **'La deuda supera el cupo registrado. El movimiento se guardó.'**
  String get debtOverLimit;

  /// No description provided for @debtReverse.
  ///
  /// In es, this message translates to:
  /// **'Anular con reversión'**
  String get debtReverse;

  /// No description provided for @debtComponents.
  ///
  /// In es, this message translates to:
  /// **'Componentes vinculados'**
  String get debtComponents;

  /// No description provided for @debtCommand.
  ///
  /// In es, this message translates to:
  /// **'Comando'**
  String get debtCommand;

  /// No description provided for @debtReversal.
  ///
  /// In es, this message translates to:
  /// **'Reversión'**
  String get debtReversal;

  /// No description provided for @budgetConnectionRequired.
  ///
  /// In es, this message translates to:
  /// **'Necesitas conexión para guardar este presupuesto. Tus cambios siguen aquí; vuelve a intentarlo.'**
  String get budgetConnectionRequired;

  /// No description provided for @budgetCommandArchived.
  ///
  /// In es, this message translates to:
  /// **'Este presupuesto o elemento está archivado. Actualiza la lista.'**
  String get budgetCommandArchived;

  /// No description provided for @budgetCommandNotFound.
  ///
  /// In es, this message translates to:
  /// **'Este presupuesto o elemento ya no está disponible. Actualiza la lista.'**
  String get budgetCommandNotFound;

  /// No description provided for @budgetCommandConflict.
  ///
  /// In es, this message translates to:
  /// **'La solicitud entra en conflicto con un cambio anterior. Actualiza el presupuesto antes de reintentar.'**
  String get budgetCommandConflict;

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'LumioMoney'**
  String get appTitle;

  /// No description provided for @sessionCheckFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos verificar tu perfil. Revisa tu conexión e inténtalo de nuevo, o vuelve a iniciar sesión.'**
  String get sessionCheckFailed;

  /// No description provided for @sessionSignOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión y volver al acceso'**
  String get sessionSignOut;

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
  /// **'Probar sin crear cuenta'**
  String get continueAsGuest;

  /// No description provided for @guestAccountHint.
  ///
  /// In es, this message translates to:
  /// **'Tus datos quedan asociados a esta sesión. Guarda tu cuenta para recuperarlos desde otros dispositivos.'**
  String get guestAccountHint;

  /// No description provided for @guestSaveAccount.
  ///
  /// In es, this message translates to:
  /// **'Guardar mi cuenta'**
  String get guestSaveAccount;

  /// No description provided for @guestUpgradeTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardar mi cuenta'**
  String get guestUpgradeTitle;

  /// No description provided for @guestUpgradeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Vincula un correo o Google a esta sesión para proteger tus datos. Se conservarán tu perfil y tus movimientos.'**
  String get guestUpgradeSubtitle;

  /// No description provided for @guestUpgradeEmailTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear acceso con correo'**
  String get guestUpgradeEmailTitle;

  /// No description provided for @guestUpgradeGoogleButton.
  ///
  /// In es, this message translates to:
  /// **'Vincular con Google'**
  String get guestUpgradeGoogleButton;

  /// No description provided for @guestUpgradeConfirmPassword.
  ///
  /// In es, this message translates to:
  /// **'Confirmar contraseña'**
  String get guestUpgradeConfirmPassword;

  /// No description provided for @guestUpgradePasswordMismatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get guestUpgradePasswordMismatch;

  /// No description provided for @guestUpgradeSuccess.
  ///
  /// In es, this message translates to:
  /// **'Tu cuenta quedó protegida. Tus datos siguen en esta sesión.'**
  String get guestUpgradeSuccess;

  /// No description provided for @guestUpgradeEmailSent.
  ///
  /// In es, this message translates to:
  /// **'Cuenta protegida. Enviamos un correo para verificar tu dirección; puedes seguir usando la app.'**
  String get guestUpgradeEmailSent;

  /// No description provided for @guestUpgradeEmailNotSent.
  ///
  /// In es, this message translates to:
  /// **'La cuenta quedó protegida, pero no pudimos enviar el correo de verificación. Puedes reintentarlo.'**
  String get guestUpgradeEmailNotSent;

  /// No description provided for @guestUpgradeResendVerification.
  ///
  /// In es, this message translates to:
  /// **'Reenviar verificación'**
  String get guestUpgradeResendVerification;

  /// No description provided for @guestUpgradeAlreadyProtected.
  ///
  /// In es, this message translates to:
  /// **'Esta sesión ya tiene un método de acceso vinculado.'**
  String get guestUpgradeAlreadyProtected;

  /// No description provided for @guestUpgradeConflict.
  ///
  /// In es, this message translates to:
  /// **'Este correo o cuenta ya pertenece a otra cuenta. Tu sesión de invitado y sus datos no cambiaron. Prueba otra credencial.'**
  String get guestUpgradeConflict;

  /// No description provided for @guestUpgradeProviderLinked.
  ///
  /// In es, this message translates to:
  /// **'Este método ya está vinculado a la sesión actual.'**
  String get guestUpgradeProviderLinked;

  /// No description provided for @guestUpgradeCancelled.
  ///
  /// In es, this message translates to:
  /// **'Se canceló la vinculación. Tu sesión de invitado sigue activa.'**
  String get guestUpgradeCancelled;

  /// No description provided for @guestUpgradeUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Este método de acceso no está disponible ahora. Tu sesión sigue activa.'**
  String get guestUpgradeUnavailable;

  /// No description provided for @guestUpgradeWeakPassword.
  ///
  /// In es, this message translates to:
  /// **'Elige una contraseña más segura.'**
  String get guestUpgradeWeakPassword;

  /// No description provided for @guestSignOutWarning.
  ///
  /// In es, this message translates to:
  /// **'Esta sesión de invitado no tiene acceso de recuperación. Si cierras sesión, podrías perder el acceso a estos datos. Guarda tu cuenta antes para recuperarlos en otro dispositivo.'**
  String get guestSignOutWarning;

  /// No description provided for @guestUpgradeBackToApp.
  ///
  /// In es, this message translates to:
  /// **'Volver a la aplicación'**
  String get guestUpgradeBackToApp;

  /// No description provided for @authLoginTab.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get authLoginTab;

  /// No description provided for @authEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get authEmailLabel;

  /// No description provided for @authEmailHint.
  ///
  /// In es, this message translates to:
  /// **'nombre@ejemplo.com'**
  String get authEmailHint;

  /// No description provided for @authPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get authPasswordLabel;

  /// No description provided for @authEmailInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe un correo electrónico válido.'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In es, this message translates to:
  /// **'Usa al menos 8 caracteres.'**
  String get authPasswordTooShort;

  /// No description provided for @authForgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get authForgotPassword;

  /// No description provided for @authResetEmailInvalid.
  ///
  /// In es, this message translates to:
  /// **'Escribe un correo válido para recuperar tu contraseña.'**
  String get authResetEmailInvalid;

  /// No description provided for @authPasswordResetSent.
  ///
  /// In es, this message translates to:
  /// **'Si existe una cuenta con este correo, enviamos un enlace para restablecer la contraseña.'**
  String get authPasswordResetSent;

  /// No description provided for @authShowPassword.
  ///
  /// In es, this message translates to:
  /// **'Mostrar contraseña'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In es, this message translates to:
  /// **'Ocultar contraseña'**
  String get authHidePassword;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authOrContinueWith.
  ///
  /// In es, this message translates to:
  /// **'o continúa con'**
  String get authOrContinueWith;

  /// No description provided for @authPrivacyNote.
  ///
  /// In es, this message translates to:
  /// **'Tus datos son privados y están cifrados.'**
  String get authPrivacyNote;

  /// No description provided for @authActionFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar la acción. Revisa tus datos e inténtalo de nuevo.'**
  String get authActionFailed;

  /// No description provided for @authNetworkError.
  ///
  /// In es, this message translates to:
  /// **'No hay conexión. Revisa tu internet e inténtalo de nuevo.'**
  String get authNetworkError;

  /// No description provided for @authProviderUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Esta opción de acceso no está disponible. Elige otra o contacta a soporte.'**
  String get authProviderUnavailable;

  /// No description provided for @authTagline.
  ///
  /// In es, this message translates to:
  /// **'Claridad para cada peso.'**
  String get authTagline;

  /// No description provided for @hideBalances.
  ///
  /// In es, this message translates to:
  /// **'Ocultar importes'**
  String get hideBalances;

  /// No description provided for @showBalances.
  ///
  /// In es, this message translates to:
  /// **'Mostrar importes'**
  String get showBalances;

  /// No description provided for @hiddenAmount.
  ///
  /// In es, this message translates to:
  /// **'Importe oculto'**
  String get hiddenAmount;

  /// No description provided for @moreOptions.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get moreOptions;

  /// No description provided for @dashboardTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu dinero, con claridad.'**
  String get dashboardTitle;

  /// No description provided for @homeMenu.
  ///
  /// In es, this message translates to:
  /// **'Más opciones'**
  String get homeMenu;

  /// No description provided for @homeTotalBalance.
  ///
  /// In es, this message translates to:
  /// **'Saldo total'**
  String get homeTotalBalance;

  /// No description provided for @homeBudgetTitle.
  ///
  /// In es, this message translates to:
  /// **'Presupuesto del mes'**
  String get homeBudgetTitle;

  /// No description provided for @homeExpenseVsBudget.
  ///
  /// In es, this message translates to:
  /// **'Gasto vs. presupuesto'**
  String get homeExpenseVsBudget;

  /// No description provided for @homeIncomeVsBudget.
  ///
  /// In es, this message translates to:
  /// **'Ingreso vs. presupuesto'**
  String get homeIncomeVsBudget;

  /// No description provided for @homeBudgetComparisonDetails.
  ///
  /// In es, this message translates to:
  /// **'Real · {actual} / Plan · {planned}'**
  String homeBudgetComparisonDetails(Object actual, Object planned);

  /// No description provided for @homeNoBudgetForFlow.
  ///
  /// In es, this message translates to:
  /// **'Sin presupuesto este mes'**
  String get homeNoBudgetForFlow;

  /// No description provided for @homeMonthlySummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen de {month} · {currency}'**
  String homeMonthlySummary(Object month, Object currency);

  /// No description provided for @seeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get seeAll;

  /// No description provided for @setupTitle.
  ///
  /// In es, this message translates to:
  /// **'Configura LumioMoney'**
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

  /// No description provided for @onboardingPreferencesSection.
  ///
  /// In es, this message translates to:
  /// **'Preferencias'**
  String get onboardingPreferencesSection;

  /// No description provided for @onboardingAccountSection.
  ///
  /// In es, this message translates to:
  /// **'Tu primera cuenta'**
  String get onboardingAccountSection;

  /// No description provided for @onboardingAccountExplanation.
  ///
  /// In es, this message translates to:
  /// **'Una cuenta representa dónde guardas o usas dinero: efectivo, cuenta corriente o ahorros. Puedes agregar más después.'**
  String get onboardingAccountExplanation;

  /// No description provided for @onboardingAccountNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre para identificarla'**
  String get onboardingAccountNameLabel;

  /// No description provided for @onboardingAccountNameHelper.
  ///
  /// In es, this message translates to:
  /// **'Este nombre solo te ayuda a reconocerla. Puedes cambiarlo después.'**
  String get onboardingAccountNameHelper;

  /// No description provided for @onboardingWalletAccountName.
  ///
  /// In es, this message translates to:
  /// **'Mi billetera'**
  String get onboardingWalletAccountName;

  /// No description provided for @onboardingCheckingAccountName.
  ///
  /// In es, this message translates to:
  /// **'Mi cuenta corriente'**
  String get onboardingCheckingAccountName;

  /// No description provided for @onboardingSavingsAccountName.
  ///
  /// In es, this message translates to:
  /// **'Mis ahorros'**
  String get onboardingSavingsAccountName;

  /// No description provided for @onboardingCurrentBalance.
  ///
  /// In es, this message translates to:
  /// **'Saldo actual (opcional)'**
  String get onboardingCurrentBalance;

  /// No description provided for @onboardingCurrentBalanceHelper.
  ///
  /// In es, this message translates to:
  /// **'Es lo que tienes hoy en esta cuenta; no es un ingreso.'**
  String get onboardingCurrentBalanceHelper;

  /// No description provided for @onboardingCreateAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear mi cuenta'**
  String get onboardingCreateAccount;

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

  /// No description provided for @activityFilterTransfers.
  ///
  /// In es, this message translates to:
  /// **'Transferencias'**
  String get activityFilterTransfers;

  /// No description provided for @activityBalanceAdjustmentsFilter.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get activityBalanceAdjustmentsFilter;

  /// No description provided for @activityBalanceAdjustmentType.
  ///
  /// In es, this message translates to:
  /// **'Ajuste de saldo'**
  String get activityBalanceAdjustmentType;

  /// No description provided for @activityBalanceAdjustmentEntry.
  ///
  /// In es, this message translates to:
  /// **'Saldo {previous} → {target} · diferencia {difference}'**
  String activityBalanceAdjustmentEntry(Object previous, Object target, Object difference);

  /// No description provided for @activityBalanceAdjustmentsHeader.
  ///
  /// In es, this message translates to:
  /// **'Ajustes de saldo'**
  String get activityBalanceAdjustmentsHeader;

  /// No description provided for @activityBalanceAdjustmentsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay ajustes para estos filtros.'**
  String get activityBalanceAdjustmentsEmpty;

  /// No description provided for @activityFilterAction.
  ///
  /// In es, this message translates to:
  /// **'Filtros · {account} · {period}'**
  String activityFilterAction(Object account, Object period);

  /// No description provided for @activityFilterTitle.
  ///
  /// In es, this message translates to:
  /// **'Filtrar actividad'**
  String get activityFilterTitle;

  /// No description provided for @activityFilterAccount.
  ///
  /// In es, this message translates to:
  /// **'CUENTA'**
  String get activityFilterAccount;

  /// No description provided for @activityFilterAllAccounts.
  ///
  /// In es, this message translates to:
  /// **'Todas las cuentas'**
  String get activityFilterAllAccounts;

  /// No description provided for @activityFilterPeriod.
  ///
  /// In es, this message translates to:
  /// **'PERIODO'**
  String get activityFilterPeriod;

  /// No description provided for @activityFilterMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get activityFilterMonth;

  /// No description provided for @activityFilterDateRange.
  ///
  /// In es, this message translates to:
  /// **'Rango de fechas'**
  String get activityFilterDateRange;

  /// No description provided for @activityFilterSelectAccount.
  ///
  /// In es, this message translates to:
  /// **'Elige las cuentas'**
  String get activityFilterSelectAccount;

  /// No description provided for @activityFilterMultiSelectHint.
  ///
  /// In es, this message translates to:
  /// **'Puedes elegir hasta 10 cuentas. Una transferencia aparece si seleccionas cualquiera de sus cuentas.'**
  String get activityFilterMultiSelectHint;

  /// No description provided for @activityFilterDone.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get activityFilterDone;

  /// No description provided for @activityFilterSelectedAccountCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{{count} cuenta} other{{count} cuentas}}'**
  String activityFilterSelectedAccountCount(int count);

  /// No description provided for @activityFilterSelectMonth.
  ///
  /// In es, this message translates to:
  /// **'Elegir mes'**
  String get activityFilterSelectMonth;

  /// No description provided for @activityFilterStartDate.
  ///
  /// In es, this message translates to:
  /// **'DESDE'**
  String get activityFilterStartDate;

  /// No description provided for @activityFilterEndDate.
  ///
  /// In es, this message translates to:
  /// **'HASTA'**
  String get activityFilterEndDate;

  /// No description provided for @activityFilterTimezoneHint.
  ///
  /// In es, this message translates to:
  /// **'El mes se interpreta según tu zona horaria.'**
  String get activityFilterTimezoneHint;

  /// No description provided for @activityFilterRangeHint.
  ///
  /// In es, this message translates to:
  /// **'Elige fechas dentro de {month}.'**
  String activityFilterRangeHint(Object month);

  /// No description provided for @activityFilterApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar filtros'**
  String get activityFilterApply;

  /// No description provided for @activityFilterReset.
  ///
  /// In es, this message translates to:
  /// **'Restablecer'**
  String get activityFilterReset;

  /// No description provided for @activityFilterUseMonth.
  ///
  /// In es, this message translates to:
  /// **'Usar {month}'**
  String activityFilterUseMonth(Object month);

  /// No description provided for @activityFilterUseDate.
  ///
  /// In es, this message translates to:
  /// **'Usar fecha'**
  String get activityFilterUseDate;

  /// No description provided for @activityFilterAllDates.
  ///
  /// In es, this message translates to:
  /// **'Todas las fechas'**
  String get activityFilterAllDates;

  /// No description provided for @activityFilterSelectedDetails.
  ///
  /// In es, this message translates to:
  /// **'{account} · {range}'**
  String activityFilterSelectedDetails(Object account, Object range);

  /// No description provided for @activityShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get activityShare;

  /// No description provided for @activityShareSubject.
  ///
  /// In es, this message translates to:
  /// **'Actividad de LumioMoney'**
  String get activityShareSubject;

  /// No description provided for @activityShareFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo preparar o compartir el archivo. Inténtalo de nuevo.'**
  String get activityShareFailed;

  /// No description provided for @activityShareEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay movimientos para compartir.'**
  String get activityShareEmpty;

  /// No description provided for @activityMovements.
  ///
  /// In es, this message translates to:
  /// **'Movimientos'**
  String get activityMovements;

  /// No description provided for @activityMovementCount.
  ///
  /// In es, this message translates to:
  /// **'Movimientos · {count}'**
  String activityMovementCount(int count);

  /// No description provided for @activityExportAction.
  ///
  /// In es, this message translates to:
  /// **'Exportar'**
  String get activityExportAction;

  /// No description provided for @activityExportTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportar CSV'**
  String get activityExportTitle;

  /// No description provided for @activityExportSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa la selección antes de continuar.'**
  String get activityExportSubtitle;

  /// No description provided for @activityExportAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta'**
  String get activityExportAccount;

  /// No description provided for @activityExportPeriod.
  ///
  /// In es, this message translates to:
  /// **'Periodo'**
  String get activityExportPeriod;

  /// No description provided for @activityExportType.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get activityExportType;

  /// No description provided for @activityExportCurrencyFormat.
  ///
  /// In es, this message translates to:
  /// **'Moneda · Formato'**
  String get activityExportCurrencyFormat;

  /// No description provided for @activityExportConfirmedCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{0 movimientos confirmados} one{1 movimiento confirmado} other{{count} movimientos confirmados}}'**
  String activityExportConfirmedCount(int count);

  /// No description provided for @activityExportIncludedCount.
  ///
  /// In es, this message translates to:
  /// **'{count} movimientos incluidos'**
  String activityExportIncludedCount(int count);

  /// No description provided for @activityExportMoreCount.
  ///
  /// In es, this message translates to:
  /// **'y {count} más'**
  String activityExportMoreCount(int count);

  /// No description provided for @activityExportIncludePending.
  ///
  /// In es, this message translates to:
  /// **'Incluir pendientes'**
  String get activityExportIncludePending;

  /// No description provided for @activityExportPendingExcluded.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 movimiento pendiente excluido. Activa para incluirlo.} other{{count} movimientos pendientes excluidos. Activa para incluirlos.}}'**
  String activityExportPendingExcluded(int count);

  /// No description provided for @activityExportPendingIncluded.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 movimiento pendiente se incluirá e identificará como pendiente.} other{{count} movimientos pendientes se incluirán e identificarán como pendientes.}}'**
  String activityExportPendingIncluded(int count);

  /// No description provided for @activityExportAllResults.
  ///
  /// In es, this message translates to:
  /// **'Se exportan todos los resultados de los filtros, no solo los cargados. Se conservan el orden, las fechas y la zona horaria.'**
  String get activityExportAllResults;

  /// No description provided for @activityExportNoNotes.
  ///
  /// In es, this message translates to:
  /// **'No incluye notas. Guardar y compartir usan el mismo CSV.'**
  String get activityExportNoNotes;

  /// No description provided for @activityExportSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar archivo'**
  String get activityExportSave;

  /// No description provided for @activityExportShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir archivo'**
  String get activityExportShare;

  /// No description provided for @activityExportPreparing.
  ///
  /// In es, this message translates to:
  /// **'Preparando {count, plural, one{1 movimiento} other{{count} movimientos}}…'**
  String activityExportPreparing(int count);

  /// No description provided for @activityExportErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos generar el archivo'**
  String get activityExportErrorTitle;

  /// No description provided for @activityExportErrorMessage.
  ///
  /// In es, this message translates to:
  /// **'Ocurrió un problema temporal. Tu selección sigue aquí; puedes intentarlo de nuevo.'**
  String get activityExportErrorMessage;

  /// No description provided for @activityExportCloseHint.
  ///
  /// In es, this message translates to:
  /// **'Al cerrar, se conservan tus filtros y selección.'**
  String get activityExportCloseHint;

  /// No description provided for @activityTotalsTitle.
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get activityTotalsTitle;

  /// No description provided for @activityTotalsIncome.
  ///
  /// In es, this message translates to:
  /// **'Ingresos'**
  String get activityTotalsIncome;

  /// No description provided for @activityTotalsExpenses.
  ///
  /// In es, this message translates to:
  /// **'Egresos'**
  String get activityTotalsExpenses;

  /// No description provided for @activityTotalsNet.
  ///
  /// In es, this message translates to:
  /// **'Resultado'**
  String get activityTotalsNet;

  /// No description provided for @activityTotalsMethodNote.
  ///
  /// In es, this message translates to:
  /// **'Ingresos − egresos · Transferencias excluidas'**
  String get activityTotalsMethodNote;

  /// No description provided for @activityTransfersTotalsNote.
  ///
  /// In es, this message translates to:
  /// **'Las transferencias no se suman a ingresos, egresos ni resultado.'**
  String get activityTransfersTotalsNote;

  /// No description provided for @activityTotalsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay ingresos ni egresos confirmados para calcular los totales.'**
  String get activityTotalsEmpty;

  /// No description provided for @activityCsvDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha y hora'**
  String get activityCsvDate;

  /// No description provided for @activityCsvType.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get activityCsvType;

  /// No description provided for @activityCsvDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get activityCsvDescription;

  /// No description provided for @activityCsvAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta(s)'**
  String get activityCsvAccount;

  /// No description provided for @activityCsvCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría'**
  String get activityCsvCategory;

  /// No description provided for @activityCsvAmount.
  ///
  /// In es, this message translates to:
  /// **'Importe'**
  String get activityCsvAmount;

  /// No description provided for @activityCsvCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get activityCsvCurrency;

  /// No description provided for @activityCsvStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get activityCsvStatus;

  /// No description provided for @activityCsvPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get activityCsvPending;

  /// No description provided for @activityCsvConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Confirmado'**
  String get activityCsvConfirmed;

  /// No description provided for @activityCsvRejected.
  ///
  /// In es, this message translates to:
  /// **'Rechazado'**
  String get activityCsvRejected;

  /// No description provided for @activityCsvUnknownAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta desconocida'**
  String get activityCsvUnknownAccount;

  /// No description provided for @activityCsvUnknownCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría desconocida'**
  String get activityCsvUnknownCategory;

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
  /// **'Cuentas y deudas'**
  String get accountsTitle;

  /// No description provided for @accountsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Dinero, tarjetas y préstamos en un solo lugar'**
  String get accountsSubtitle;

  /// No description provided for @addAccount.
  ///
  /// In es, this message translates to:
  /// **'Agregar cuenta'**
  String get addAccount;

  /// No description provided for @addCreditCard.
  ///
  /// In es, this message translates to:
  /// **'Agregar tarjeta'**
  String get addCreditCard;

  /// No description provided for @accountsAddEntry.
  ///
  /// In es, this message translates to:
  /// **'Agregar cuenta o deuda'**
  String get accountsAddEntry;

  /// No description provided for @addLoan.
  ///
  /// In es, this message translates to:
  /// **'Agregar crédito o préstamo'**
  String get addLoan;

  /// No description provided for @registerMovement.
  ///
  /// In es, this message translates to:
  /// **'Registrar'**
  String get registerMovement;

  /// No description provided for @showAccountBalances.
  ///
  /// In es, this message translates to:
  /// **'Ver saldos por cuenta'**
  String get showAccountBalances;

  /// No description provided for @hideAccountBalances.
  ///
  /// In es, this message translates to:
  /// **'Ocultar saldos por cuenta'**
  String get hideAccountBalances;

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

  /// No description provided for @addMovementChoiceTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Qué quieres agregar?'**
  String get addMovementChoiceTitle;

  /// No description provided for @addMovementChoiceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige una opción para continuar'**
  String get addMovementChoiceSubtitle;

  /// No description provided for @moveMoney.
  ///
  /// In es, this message translates to:
  /// **'Mover dinero'**
  String get moveMoney;

  /// No description provided for @close.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// No description provided for @transferExplanation.
  ///
  /// In es, this message translates to:
  /// **'Mover dinero pasa fondos entre tus cuentas propias. No suma ni resta al saldo total.'**
  String get transferExplanation;

  /// No description provided for @incomeRegistered.
  ///
  /// In es, this message translates to:
  /// **'Ingreso registrado · {amount}'**
  String incomeRegistered(Object amount);

  /// No description provided for @expenseRegistered.
  ///
  /// In es, this message translates to:
  /// **'Gasto registrado · {amount}'**
  String expenseRegistered(Object amount);

  /// No description provided for @transferRegistered.
  ///
  /// In es, this message translates to:
  /// **'Transferencia registrada'**
  String get transferRegistered;

  /// No description provided for @viewMovement.
  ///
  /// In es, this message translates to:
  /// **'Ver movimiento'**
  String get viewMovement;

  /// No description provided for @viewDetails.
  ///
  /// In es, this message translates to:
  /// **'Ver detalle'**
  String get viewDetails;

  /// No description provided for @viewPendingOperations.
  ///
  /// In es, this message translates to:
  /// **'Ver pendientes'**
  String get viewPendingOperations;

  /// No description provided for @pendingBalanceNote.
  ///
  /// In es, this message translates to:
  /// **'Hay movimientos guardados en este dispositivo. El saldo confirmado puede no incluirlos todavía.'**
  String get pendingBalanceNote;

  /// No description provided for @notVisibleWithCurrentFilters.
  ///
  /// In es, this message translates to:
  /// **'No aparece con los filtros actuales'**
  String get notVisibleWithCurrentFilters;

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

  /// No description provided for @adjustAccountBalance.
  ///
  /// In es, this message translates to:
  /// **'Ajustar saldo'**
  String get adjustAccountBalance;

  /// No description provided for @balanceAdjustmentTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustar saldos'**
  String get balanceAdjustmentTitle;

  /// No description provided for @balanceAdjustmentSubtitle.
  ///
  /// In es, this message translates to:
  /// **'El saldo inicial y tus movimientos no cambiarán.'**
  String get balanceAdjustmentSubtitle;

  /// No description provided for @balanceAdjustmentTarget.
  ///
  /// In es, this message translates to:
  /// **'Saldo real'**
  String get balanceAdjustmentTarget;

  /// No description provided for @balanceAdjustmentCurrent.
  ///
  /// In es, this message translates to:
  /// **'Saldo actual: {balance}'**
  String balanceAdjustmentCurrent(Object balance);

  /// No description provided for @balanceAdjustmentPrevious.
  ///
  /// In es, this message translates to:
  /// **'Saldo anterior'**
  String get balanceAdjustmentPrevious;

  /// No description provided for @balanceAdjustmentDifferenceLabel.
  ///
  /// In es, this message translates to:
  /// **'Diferencia'**
  String get balanceAdjustmentDifferenceLabel;

  /// No description provided for @balanceAdjustmentDifference.
  ///
  /// In es, this message translates to:
  /// **'Diferencia: {amount}'**
  String balanceAdjustmentDifference(Object amount);

  /// No description provided for @balanceAdjustmentReason.
  ///
  /// In es, this message translates to:
  /// **'Motivo (opcional)'**
  String get balanceAdjustmentReason;

  /// No description provided for @balanceAdjustmentOtherDevicesHint.
  ///
  /// In es, this message translates to:
  /// **'Sincroniza primero los movimientos pendientes en tus otros dispositivos; podrían cambiar estos saldos después.'**
  String get balanceAdjustmentOtherDevicesHint;

  /// No description provided for @balanceAdjustmentPendingHint.
  ///
  /// In es, this message translates to:
  /// **'Resuelve los movimientos pendientes, en sincronización o rechazados de las cuentas seleccionadas antes de ajustar.'**
  String get balanceAdjustmentPendingHint;

  /// No description provided for @balanceAdjustmentSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar ajustes'**
  String get balanceAdjustmentSave;

  /// No description provided for @balanceAdjustmentNoop.
  ///
  /// In es, this message translates to:
  /// **'El saldo objetivo ya coincide con el saldo actual.'**
  String get balanceAdjustmentNoop;

  /// No description provided for @balanceAdjustmentInvalidAmount.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un saldo válido dentro del límite permitido.'**
  String get balanceAdjustmentInvalidAmount;

  /// No description provided for @balanceAdjustmentSuccess.
  ///
  /// In es, this message translates to:
  /// **'Saldos actualizados.'**
  String get balanceAdjustmentSuccess;

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

  /// No description provided for @amountInvalid.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un monto válido mayor que cero.'**
  String get amountInvalid;

  /// No description provided for @amountTooLarge.
  ///
  /// In es, this message translates to:
  /// **'El monto no puede superar 1.000.000.000 en esta moneda.'**
  String get amountTooLarge;

  /// No description provided for @operationAccountRequired.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una cuenta.'**
  String get operationAccountRequired;

  /// No description provided for @operationCategoryRequired.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una categoría.'**
  String get operationCategoryRequired;

  /// No description provided for @transferSourceRequired.
  ///
  /// In es, this message translates to:
  /// **'Selecciona la cuenta de origen.'**
  String get transferSourceRequired;

  /// No description provided for @transferDestinationRequired.
  ///
  /// In es, this message translates to:
  /// **'Selecciona la cuenta de destino.'**
  String get transferDestinationRequired;

  /// No description provided for @transferAccountsDifferent.
  ///
  /// In es, this message translates to:
  /// **'Elige dos cuentas distintas con la misma moneda.'**
  String get transferAccountsDifferent;

  /// No description provided for @budgetDayInvalidForMonth.
  ///
  /// In es, this message translates to:
  /// **'Elige un día que exista en el mes seleccionado.'**
  String get budgetDayInvalidForMonth;

  /// No description provided for @onboardingAccountRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe el nombre de tu primera cuenta.'**
  String get onboardingAccountRequired;

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

  /// No description provided for @time.
  ///
  /// In es, this message translates to:
  /// **'Hora'**
  String get time;

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

  /// No description provided for @syncIssueNetwork.
  ///
  /// In es, this message translates to:
  /// **'No hay conexión con el servidor. El movimiento sigue guardado aquí; inténtalo cuando vuelva la conexión.'**
  String get syncIssueNetwork;

  /// No description provided for @syncIssuePermissionDenied.
  ///
  /// In es, this message translates to:
  /// **'Firebase rechazó el movimiento. Comprueba tu sesión; si continúa, comparte el código de diagnóstico con soporte.'**
  String get syncIssuePermissionDenied;

  /// No description provided for @syncIssueInvalidOperation.
  ///
  /// In es, this message translates to:
  /// **'El movimiento no coincide con los datos actuales. Revisa la cuenta, categoría o presupuesto antes de reintentar.'**
  String get syncIssueInvalidOperation;

  /// No description provided for @syncIssueUnexpected.
  ///
  /// In es, this message translates to:
  /// **'No pudimos identificar la causa. Comparte el código de diagnóstico con soporte.'**
  String get syncIssueUnexpected;

  /// No description provided for @syncDiagnosticCode.
  ///
  /// In es, this message translates to:
  /// **'Código de diagnóstico: {code}'**
  String syncDiagnosticCode(Object code);

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

  /// No description provided for @unbudgetedActualAmount.
  ///
  /// In es, this message translates to:
  /// **'Total sin presupuesto · {amount}'**
  String unbudgetedActualAmount(Object amount);

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

  /// No description provided for @budgetMovementsTab.
  ///
  /// In es, this message translates to:
  /// **'Movimientos'**
  String get budgetMovementsTab;

  /// No description provided for @budgetMovementsExplanation.
  ///
  /// In es, this message translates to:
  /// **'El progreso incluye todos los movimientos confirmados de esta categoría y periodo, estén asociados o no a un elemento.'**
  String get budgetMovementsExplanation;

  /// No description provided for @budgetMovementFilterAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get budgetMovementFilterAll;

  /// No description provided for @budgetMovementFilterLinked.
  ///
  /// In es, this message translates to:
  /// **'Con elemento'**
  String get budgetMovementFilterLinked;

  /// No description provided for @budgetMovementFilterUnlinked.
  ///
  /// In es, this message translates to:
  /// **'Sin elemento'**
  String get budgetMovementFilterUnlinked;

  /// No description provided for @budgetMovementsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay movimientos confirmados de esta categoría en el periodo.'**
  String get budgetMovementsEmpty;

  /// No description provided for @budgetMovementUnassociated.
  ///
  /// In es, this message translates to:
  /// **'Sin elemento asociado'**
  String get budgetMovementUnassociated;

  /// No description provided for @budgetMovementLinkedTo.
  ///
  /// In es, this message translates to:
  /// **'Asociado a: {item}'**
  String budgetMovementLinkedTo(String item);

  /// No description provided for @budgetMovementArchivedLink.
  ///
  /// In es, this message translates to:
  /// **'Asociado al elemento archivado: {item}'**
  String budgetMovementArchivedLink(String item);

  /// No description provided for @budgetMovementAssociation.
  ///
  /// In es, this message translates to:
  /// **'Cambiar elemento asociado'**
  String get budgetMovementAssociation;

  /// No description provided for @budgetMovementClearAssociation.
  ///
  /// In es, this message translates to:
  /// **'Quitar asociación'**
  String get budgetMovementClearAssociation;

  /// No description provided for @budgetMovementReversal.
  ///
  /// In es, this message translates to:
  /// **'Reversión; no se puede asociar'**
  String get budgetMovementReversal;

  /// No description provided for @budgetMovementAssociationSaved.
  ///
  /// In es, this message translates to:
  /// **'Se actualizó la asociación. El saldo y el gasto total no cambian.'**
  String get budgetMovementAssociationSaved;

  /// No description provided for @budgetMovementAssociationFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cambiar la asociación. No se alteraron los saldos; inténtalo de nuevo.'**
  String get budgetMovementAssociationFailed;

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

  /// No description provided for @categoryIcon.
  ///
  /// In es, this message translates to:
  /// **'Ícono de categoría'**
  String get categoryIcon;

  /// No description provided for @categoryColor.
  ///
  /// In es, this message translates to:
  /// **'Color de categoría'**
  String get categoryColor;

  /// No description provided for @categoryColorDefault.
  ///
  /// In es, this message translates to:
  /// **'Predeterminado'**
  String get categoryColorDefault;

  /// No description provided for @categoryColorBlue.
  ///
  /// In es, this message translates to:
  /// **'Azul'**
  String get categoryColorBlue;

  /// No description provided for @categoryColorGreen.
  ///
  /// In es, this message translates to:
  /// **'Verde'**
  String get categoryColorGreen;

  /// No description provided for @categoryColorOrange.
  ///
  /// In es, this message translates to:
  /// **'Naranja'**
  String get categoryColorOrange;

  /// No description provided for @categoryColorPurple.
  ///
  /// In es, this message translates to:
  /// **'Morado'**
  String get categoryColorPurple;

  /// No description provided for @categoryColorRed.
  ///
  /// In es, this message translates to:
  /// **'Rojo'**
  String get categoryColorRed;

  /// No description provided for @categoryColorTeal.
  ///
  /// In es, this message translates to:
  /// **'Turquesa'**
  String get categoryColorTeal;

  /// No description provided for @categoryColorOption.
  ///
  /// In es, this message translates to:
  /// **'{color} · {hex}'**
  String categoryColorOption(Object color, Object hex);

  /// No description provided for @changeColor.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get changeColor;

  /// No description provided for @useColor.
  ///
  /// In es, this message translates to:
  /// **'Usar color'**
  String get useColor;

  /// No description provided for @categoryIconLabel.
  ///
  /// In es, this message translates to:
  /// **'Ícono'**
  String get categoryIconLabel;

  /// No description provided for @categoryIconUtensils.
  ///
  /// In es, this message translates to:
  /// **'Cubiertos'**
  String get categoryIconUtensils;

  /// No description provided for @categoryIconHouse.
  ///
  /// In es, this message translates to:
  /// **'Casa'**
  String get categoryIconHouse;

  /// No description provided for @categoryIconCar.
  ///
  /// In es, this message translates to:
  /// **'Automóvil'**
  String get categoryIconCar;

  /// No description provided for @categoryIconHeart.
  ///
  /// In es, this message translates to:
  /// **'Corazón'**
  String get categoryIconHeart;

  /// No description provided for @categoryIconBook.
  ///
  /// In es, this message translates to:
  /// **'Libro'**
  String get categoryIconBook;

  /// No description provided for @categoryIconBriefcase.
  ///
  /// In es, this message translates to:
  /// **'Maletín'**
  String get categoryIconBriefcase;

  /// No description provided for @categoryIconTag.
  ///
  /// In es, this message translates to:
  /// **'Etiqueta'**
  String get categoryIconTag;

  /// No description provided for @changeIcon.
  ///
  /// In es, this message translates to:
  /// **'Cambiar'**
  String get changeIcon;

  /// No description provided for @useIcon.
  ///
  /// In es, this message translates to:
  /// **'Usar ícono'**
  String get useIcon;

  /// No description provided for @budgetConfirmMonth.
  ///
  /// In es, this message translates to:
  /// **'Confirmar mes'**
  String get budgetConfirmMonth;

  /// No description provided for @categoryIconFood.
  ///
  /// In es, this message translates to:
  /// **'Comida'**
  String get categoryIconFood;

  /// No description provided for @categoryIconHousing.
  ///
  /// In es, this message translates to:
  /// **'Vivienda'**
  String get categoryIconHousing;

  /// No description provided for @categoryIconTransport.
  ///
  /// In es, this message translates to:
  /// **'Transporte'**
  String get categoryIconTransport;

  /// No description provided for @categoryIconHealth.
  ///
  /// In es, this message translates to:
  /// **'Salud'**
  String get categoryIconHealth;

  /// No description provided for @categoryIconEducation.
  ///
  /// In es, this message translates to:
  /// **'Educación'**
  String get categoryIconEducation;

  /// No description provided for @categoryIconSalary.
  ///
  /// In es, this message translates to:
  /// **'Salario'**
  String get categoryIconSalary;

  /// No description provided for @categoryIconOther.
  ///
  /// In es, this message translates to:
  /// **'Otros'**
  String get categoryIconOther;

  /// No description provided for @budgetItemActual.
  ///
  /// In es, this message translates to:
  /// **'Registrado: {amount}'**
  String budgetItemActual(Object amount);

  /// No description provided for @budgetRecordExpense.
  ///
  /// In es, this message translates to:
  /// **'Registrar gasto'**
  String get budgetRecordExpense;

  /// No description provided for @budgetRecordIncome.
  ///
  /// In es, this message translates to:
  /// **'Registrar ingreso'**
  String get budgetRecordIncome;

  /// No description provided for @budgetItemNoCompatibleAccount.
  ///
  /// In es, this message translates to:
  /// **'Necesitas una cuenta activa en {currency} para registrar este movimiento.'**
  String budgetItemNoCompatibleAccount(Object currency);

  /// No description provided for @budgetItemMovementContext.
  ///
  /// In es, this message translates to:
  /// **'Movimiento para el elemento: {description}'**
  String budgetItemMovementContext(Object description);

  /// No description provided for @budgetArchivedItems.
  ///
  /// In es, this message translates to:
  /// **'Elementos retirados'**
  String get budgetArchivedItems;

  /// No description provided for @budgetItemArchived.
  ///
  /// In es, this message translates to:
  /// **'Retirado · movimientos conservados'**
  String get budgetItemArchived;

  /// No description provided for @budgetItemLinkedMovements.
  ///
  /// In es, this message translates to:
  /// **'Movimientos vinculados'**
  String get budgetItemLinkedMovements;

  /// No description provided for @budgetItemNoLinkedMovements.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay movimientos vinculados.'**
  String get budgetItemNoLinkedMovements;

  /// No description provided for @budgetLinkedMovementConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Confirmado'**
  String get budgetLinkedMovementConfirmed;

  /// No description provided for @budgetLinkedMovementPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente de sincronizar'**
  String get budgetLinkedMovementPending;

  /// No description provided for @budgetLinkedMovementRejected.
  ///
  /// In es, this message translates to:
  /// **'Rechazado · no afecta el total'**
  String get budgetLinkedMovementRejected;

  /// No description provided for @budgetArchiveNetworkFailure.
  ///
  /// In es, this message translates to:
  /// **'No pudimos conectar. El presupuesto sigue activo; revisa tu conexión e inténtalo de nuevo. Código: {code}'**
  String budgetArchiveNetworkFailure(Object code);

  /// No description provided for @budgetArchivePermissionFailure.
  ///
  /// In es, this message translates to:
  /// **'Firebase no autorizó el cambio. El presupuesto sigue activo; comprueba tu sesión y comparte este código con soporte: {code}'**
  String budgetArchivePermissionFailure(Object code);

  /// No description provided for @budgetArchiveConflictFailure.
  ///
  /// In es, this message translates to:
  /// **'No se pudo validar el presupuesto. Sigue activo; comparte este código con soporte: {code}'**
  String budgetArchiveConflictFailure(Object code);

  /// No description provided for @budgetArchiveUnexpectedFailure.
  ///
  /// In es, this message translates to:
  /// **'No pudimos eliminar el presupuesto. Sigue activo; inténtalo de nuevo. Código: {code}'**
  String budgetArchiveUnexpectedFailure(Object code);

  /// No description provided for @more.
  ///
  /// In es, this message translates to:
  /// **'Más'**
  String get more;

  /// No description provided for @back.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get back;

  /// No description provided for @moreSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Personaliza LumioMoney y gestiona tus preferencias.'**
  String get moreSubtitle;

  /// No description provided for @moreManagement.
  ///
  /// In es, this message translates to:
  /// **'Gestión'**
  String get moreManagement;

  /// No description provided for @moreSession.
  ///
  /// In es, this message translates to:
  /// **'Sesión'**
  String get moreSession;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cerrar sesión?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In es, this message translates to:
  /// **'Tendrás que volver a iniciar sesión para acceder a tus datos.'**
  String get signOutConfirmMessage;

  /// No description provided for @signOutPendingWarning.
  ///
  /// In es, this message translates to:
  /// **'Tienes {count, plural, one{# movimiento pendiente de sincronizar} other{# movimientos pendientes de sincronizar}}. Cerrar sesión no los elimina, pero pueden necesitar que vuelvas a iniciar sesión para sincronizar.'**
  String signOutPendingWarning(int count);

  /// No description provided for @discardChangesTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Descartar los cambios?'**
  String get discardChangesTitle;

  /// No description provided for @discardChangesMessage.
  ///
  /// In es, this message translates to:
  /// **'Los cambios que hiciste todavía no se han guardado.'**
  String get discardChangesMessage;

  /// No description provided for @keepEditing.
  ///
  /// In es, this message translates to:
  /// **'Seguir editando'**
  String get keepEditing;

  /// No description provided for @discardChanges.
  ///
  /// In es, this message translates to:
  /// **'Descartar'**
  String get discardChanges;

  /// No description provided for @accountIncludeInHomeBalance.
  ///
  /// In es, this message translates to:
  /// **'Incluir en el saldo de Inicio'**
  String get accountIncludeInHomeBalance;

  /// No description provided for @accountIncludeInHomeBalanceHint.
  ///
  /// In es, this message translates to:
  /// **'Esta cuenta se sumará al saldo consolidado de Inicio.'**
  String get accountIncludeInHomeBalanceHint;

  /// No description provided for @homeNoAccountsIncluded.
  ///
  /// In es, this message translates to:
  /// **'No hay cuentas activas incluidas en el saldo de Inicio.'**
  String get homeNoAccountsIncluded;

  /// No description provided for @homeCustomizeTitle.
  ///
  /// In es, this message translates to:
  /// **'Personalizar Inicio'**
  String get homeCustomizeTitle;

  /// No description provided for @homeCustomizeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige qué información quieres ver en Inicio. Los avisos de sincronización siempre estarán visibles.'**
  String get homeCustomizeSubtitle;

  /// No description provided for @homeWidgetsSection.
  ///
  /// In es, this message translates to:
  /// **'Tarjetas de Inicio'**
  String get homeWidgetsSection;

  /// No description provided for @homeBudgetCardsSection.
  ///
  /// In es, this message translates to:
  /// **'Presupuestos por categoría'**
  String get homeBudgetCardsSection;

  /// No description provided for @homeWidgetTotalBalance.
  ///
  /// In es, this message translates to:
  /// **'Saldo total'**
  String get homeWidgetTotalBalance;

  /// No description provided for @homeWidgetIncome.
  ///
  /// In es, this message translates to:
  /// **'Resumen de ingresos'**
  String get homeWidgetIncome;

  /// No description provided for @homeWidgetExpense.
  ///
  /// In es, this message translates to:
  /// **'Resumen de gastos'**
  String get homeWidgetExpense;

  /// No description provided for @homeWidgetExpenseBudget.
  ///
  /// In es, this message translates to:
  /// **'Gasto vs. presupuesto'**
  String get homeWidgetExpenseBudget;

  /// No description provided for @homeWidgetIncomeBudget.
  ///
  /// In es, this message translates to:
  /// **'Ingreso vs. presupuesto'**
  String get homeWidgetIncomeBudget;

  /// No description provided for @homeWidgetRecentActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad reciente'**
  String get homeWidgetRecentActivity;

  /// No description provided for @homeNoBudgetCards.
  ///
  /// In es, this message translates to:
  /// **'No hay presupuestos activos para personalizar.'**
  String get homeNoBudgetCards;

  /// No description provided for @homePreferencesSaving.
  ///
  /// In es, this message translates to:
  /// **'Guardando preferencia…'**
  String get homePreferencesSaving;

  /// No description provided for @homePreferencesSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar. Tu selección se conserva; inténtalo de nuevo.'**
  String get homePreferencesSaveFailed;

  /// No description provided for @coachTitle.
  ///
  /// In es, this message translates to:
  /// **'Coach y recordatorios'**
  String get coachTitle;

  /// No description provided for @coachSettingsIntro.
  ///
  /// In es, this message translates to:
  /// **'Organiza tu rutina y elige cuándo quieres revisar tus finanzas.'**
  String get coachSettingsIntro;

  /// No description provided for @coachDailyTitle.
  ///
  /// In es, this message translates to:
  /// **'Cierre diario'**
  String get coachDailyTitle;

  /// No description provided for @coachWeeklyTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisión semanal'**
  String get coachWeeklyTitle;

  /// No description provided for @coachNextStepTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu siguiente paso'**
  String get coachNextStepTitle;

  /// No description provided for @coachDailyReminder.
  ///
  /// In es, this message translates to:
  /// **'Recordatorio de cierre diario'**
  String get coachDailyReminder;

  /// No description provided for @coachWeeklyReminder.
  ///
  /// In es, this message translates to:
  /// **'Recordatorio de revisión semanal'**
  String get coachWeeklyReminder;

  /// No description provided for @coachReminderTime.
  ///
  /// In es, this message translates to:
  /// **'Hora del recordatorio'**
  String get coachReminderTime;

  /// No description provided for @coachReminderDays.
  ///
  /// In es, this message translates to:
  /// **'Días de la semana'**
  String get coachReminderDays;

  /// No description provided for @coachDevice.
  ///
  /// In es, this message translates to:
  /// **'En este dispositivo'**
  String get coachDevice;

  /// No description provided for @coachEnableDevice.
  ///
  /// In es, this message translates to:
  /// **'Recibir recordatorios en este dispositivo'**
  String get coachEnableDevice;

  /// No description provided for @coachDevicePrivacy.
  ///
  /// In es, this message translates to:
  /// **'Los avisos no muestran importes ni datos de tus cuentas.'**
  String get coachDevicePrivacy;

  /// No description provided for @coachWindowNotice.
  ///
  /// In es, this message translates to:
  /// **'Abre la app al menos una vez cada 28 días para renovar los avisos. Los cambios de otros dispositivos se aplican al sincronizar.'**
  String get coachWindowNotice;

  /// No description provided for @coachPause.
  ///
  /// In es, this message translates to:
  /// **'Pausar durante siete días'**
  String get coachPause;

  /// No description provided for @coachResume.
  ///
  /// In es, this message translates to:
  /// **'Reactivar recordatorios'**
  String get coachResume;

  /// No description provided for @coachPaused.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios pausados'**
  String get coachPaused;

  /// No description provided for @coachPermissionGranted.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones permitidas'**
  String get coachPermissionGranted;

  /// No description provided for @coachPermissionDenied.
  ///
  /// In es, this message translates to:
  /// **'Las notificaciones están bloqueadas en los ajustes del dispositivo.'**
  String get coachPermissionDenied;

  /// No description provided for @coachPermissionUnknown.
  ///
  /// In es, this message translates to:
  /// **'Activa los avisos para solicitar permiso.'**
  String get coachPermissionUnknown;

  /// No description provided for @coachUnsupported.
  ///
  /// In es, this message translates to:
  /// **'En web puedes revisar tu rutina. Los recordatorios están disponibles en Android e iOS.'**
  String get coachUnsupported;

  /// No description provided for @coachOpenSettings.
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes del dispositivo'**
  String get coachOpenSettings;

  /// No description provided for @coachReviewed.
  ///
  /// In es, this message translates to:
  /// **'Revisado'**
  String get coachReviewed;

  /// No description provided for @coachFinishDaily.
  ///
  /// In es, this message translates to:
  /// **'Ya revisé mis movimientos'**
  String get coachFinishDaily;

  /// No description provided for @coachNoMovements.
  ///
  /// In es, this message translates to:
  /// **'Hoy no tuve movimientos'**
  String get coachNoMovements;

  /// No description provided for @coachFinishWeekly.
  ///
  /// In es, this message translates to:
  /// **'Marcar semana como revisada'**
  String get coachFinishWeekly;

  /// No description provided for @coachNoRecords.
  ///
  /// In es, this message translates to:
  /// **'No hay movimientos registrados en este periodo.'**
  String get coachNoRecords;

  /// No description provided for @coachAllCurrent.
  ///
  /// In es, this message translates to:
  /// **'No hay un paso prioritario ahora.'**
  String get coachAllCurrent;

  /// No description provided for @coachDailyAction.
  ///
  /// In es, this message translates to:
  /// **'Revisar mis movimientos'**
  String get coachDailyAction;

  /// No description provided for @coachWeeklyAction.
  ///
  /// In es, this message translates to:
  /// **'Revisar mi semana'**
  String get coachWeeklyAction;

  /// No description provided for @coachReviewIntro.
  ///
  /// In es, this message translates to:
  /// **'Revisa lo registrado antes de completar tu cierre. Registrar un movimiento no completa la revisión.'**
  String get coachReviewIntro;

  /// No description provided for @coachWeeklyIntro.
  ///
  /// In es, this message translates to:
  /// **'Ingresos, gastos y Resultado según tus movimientos confirmados. Transferencias y ajustes no se suman a estos totales.'**
  String get coachWeeklyIntro;

  /// No description provided for @coachConfirmedCount.
  ///
  /// In es, this message translates to:
  /// **'Movimientos confirmados'**
  String get coachConfirmedCount;

  /// No description provided for @coachPendingCount.
  ///
  /// In es, this message translates to:
  /// **'Pendientes de sincronización'**
  String get coachPendingCount;

  /// No description provided for @coachRejectedCount.
  ///
  /// In es, this message translates to:
  /// **'Movimientos rechazados'**
  String get coachRejectedCount;

  /// No description provided for @coachCached.
  ///
  /// In es, this message translates to:
  /// **'Datos guardados en este dispositivo; el periodo puede estar incompleto. Conéctate y actualiza para comprobarlo.'**
  String get coachCached;

  /// No description provided for @coachSavePending.
  ///
  /// In es, this message translates to:
  /// **'Revisión guardada en este dispositivo; pendiente de sincronización.'**
  String get coachSavePending;

  /// No description provided for @coachSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar. Tu selección se conserva; vuelve a intentarlo.'**
  String get coachSaveFailed;

  /// No description provided for @coachSaveConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Revisión guardada'**
  String get coachSaveConfirmed;

  /// No description provided for @coachTopCategories.
  ///
  /// In es, this message translates to:
  /// **'Categorías con mayor gasto'**
  String get coachTopCategories;

  /// No description provided for @coachConfigure.
  ///
  /// In es, this message translates to:
  /// **'Configurar mi rutina'**
  String get coachConfigure;

  /// No description provided for @coachReadFailure.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tu revisión. Vuelve a intentarlo.'**
  String get coachReadFailure;

  /// No description provided for @coachNotificationTitle.
  ///
  /// In es, this message translates to:
  /// **'Un momento para tus finanzas'**
  String get coachNotificationTitle;

  /// No description provided for @coachNotificationBody.
  ///
  /// In es, this message translates to:
  /// **'Tu revisión está lista. Abre LumioMoney para continuar.'**
  String get coachNotificationBody;

  /// No description provided for @coachHomeWidget.
  ///
  /// In es, this message translates to:
  /// **'Tu siguiente paso del coach'**
  String get coachHomeWidget;

  /// No description provided for @coachReminderTiming.
  ///
  /// In es, this message translates to:
  /// **'Los avisos pueden llegar más tarde según los ajustes y el ahorro de batería del dispositivo.'**
  String get coachReminderTiming;

  /// No description provided for @coachPreferencesPending.
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados en este dispositivo; pendientes de sincronización.'**
  String get coachPreferencesPending;

  /// No description provided for @coachScheduleFailed.
  ///
  /// In es, this message translates to:
  /// **'No pudimos programar los avisos. Reintenta la programación.'**
  String get coachScheduleFailed;

  /// No description provided for @coachViewMovements.
  ///
  /// In es, this message translates to:
  /// **'Ver movimientos del periodo'**
  String get coachViewMovements;

  /// No description provided for @coachNoMovementsUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Ahora hay movimientos registrados o faltan datos actualizados. Revisa el día antes de confirmarlo.'**
  String get coachNoMovementsUnavailable;

  /// No description provided for @plan.
  ///
  /// In es, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @coachTab.
  ///
  /// In es, this message translates to:
  /// **'Coach'**
  String get coachTab;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settingsTitle;

  /// No description provided for @accountsSectionOverview.
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get accountsSectionOverview;

  /// No description provided for @accountsSectionMoney.
  ///
  /// In es, this message translates to:
  /// **'Dinero'**
  String get accountsSectionMoney;

  /// No description provided for @accountsSectionCards.
  ///
  /// In es, this message translates to:
  /// **'Tarjetas'**
  String get accountsSectionCards;

  /// No description provided for @accountsSectionLoans.
  ///
  /// In es, this message translates to:
  /// **'Préstamos'**
  String get accountsSectionLoans;

  /// No description provided for @accountsSectionEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay cuentas en esta sección todavía.'**
  String get accountsSectionEmpty;

  /// No description provided for @coachHubTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu coach financiero'**
  String get coachHubTitle;

  /// No description provided for @coachHubSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa tus movimientos y construye una rutina financiera clara.'**
  String get coachHubSubtitle;

  /// No description provided for @coachHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisiones recientes'**
  String get coachHistoryTitle;

  /// No description provided for @coachHistoryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has completado revisiones.'**
  String get coachHistoryEmpty;

  /// No description provided for @coachSettingsShortcut.
  ///
  /// In es, this message translates to:
  /// **'Configurar recordatorios'**
  String get coachSettingsShortcut;

  /// No description provided for @debtSelectForPayment.
  ///
  /// In es, this message translates to:
  /// **'Elige la tarjeta o el préstamo que ya pagaste. Registrar el pago no mueve dinero por ti.'**
  String get debtSelectForPayment;

  /// No description provided for @accountDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle de cuenta'**
  String get accountDetailTitle;

  /// No description provided for @operationEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar movimiento'**
  String get operationEditTitle;

  /// No description provided for @appearanceTitle.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get appearanceTitle;

  /// No description provided for @appearanceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Personaliza los colores de LumioMoney en tus dispositivos.'**
  String get appearanceSubtitle;

  /// No description provided for @appearanceMode.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get appearanceMode;

  /// No description provided for @appearanceSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get appearanceSystem;

  /// No description provided for @appearanceLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get appearanceDark;

  /// No description provided for @appearancePalette.
  ///
  /// In es, this message translates to:
  /// **'Paleta de color'**
  String get appearancePalette;

  /// No description provided for @paletteLumio.
  ///
  /// In es, this message translates to:
  /// **'Lumio'**
  String get paletteLumio;

  /// No description provided for @paletteClassicBlue.
  ///
  /// In es, this message translates to:
  /// **'Azul clásico'**
  String get paletteClassicBlue;

  /// No description provided for @paletteOcean.
  ///
  /// In es, this message translates to:
  /// **'Océano'**
  String get paletteOcean;

  /// No description provided for @palettePlum.
  ///
  /// In es, this message translates to:
  /// **'Ciruela'**
  String get palettePlum;

  /// No description provided for @appearanceSaving.
  ///
  /// In es, this message translates to:
  /// **'Guardando preferencia…'**
  String get appearanceSaving;

  /// No description provided for @appearanceSaved.
  ///
  /// In es, this message translates to:
  /// **'Apariencia sincronizada'**
  String get appearanceSaved;

  /// No description provided for @appearanceSaveFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo sincronizar la apariencia. Tu selección sigue aplicada.'**
  String get appearanceSaveFailed;

  /// No description provided for @appearanceRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get appearanceRetry;

  /// No description provided for @accountKindMoney.
  ///
  /// In es, this message translates to:
  /// **'Cuenta de dinero'**
  String get accountKindMoney;

  /// No description provided for @accountKindCreditCard.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta de crédito'**
  String get accountKindCreditCard;

  /// No description provided for @accountKindBankLoan.
  ///
  /// In es, this message translates to:
  /// **'Crédito bancario'**
  String get accountKindBankLoan;

  /// No description provided for @accountKindPersonalLoan.
  ///
  /// In es, this message translates to:
  /// **'Préstamo personal recibido'**
  String get accountKindPersonalLoan;

  /// No description provided for @selectionChoosePrompt.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar'**
  String get selectionChoosePrompt;

  /// No description provided for @selectionSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre o tipo'**
  String get selectionSearchHint;

  /// No description provided for @selectionClearSearch.
  ///
  /// In es, this message translates to:
  /// **'Borrar búsqueda'**
  String get selectionClearSearch;

  /// No description provided for @selectionNoResults.
  ///
  /// In es, this message translates to:
  /// **'No hay resultados'**
  String get selectionNoResults;

  /// No description provided for @accountOptionBalance.
  ///
  /// In es, this message translates to:
  /// **'Saldo'**
  String get accountOptionBalance;

  /// No description provided for @accountOptionDebt.
  ///
  /// In es, this message translates to:
  /// **'Deuda'**
  String get accountOptionDebt;

  /// No description provided for @accountOptionCreditBalance.
  ///
  /// In es, this message translates to:
  /// **'Saldo a favor'**
  String get accountOptionCreditBalance;

  /// No description provided for @selectionFrequent.
  ///
  /// In es, this message translates to:
  /// **'Frecuentes'**
  String get selectionFrequent;

  /// No description provided for @selectionAll.
  ///
  /// In es, this message translates to:
  /// **'Todas las opciones'**
  String get selectionAll;

  /// No description provided for @resetSectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Acciones destructivas'**
  String get resetSectionTitle;

  /// No description provided for @resetTitle.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar mis datos'**
  String get resetTitle;

  /// No description provided for @resetDescription.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán tus movimientos, cuentas y deudas, presupuestos, categorías personalizadas, preferencias, revisiones del Coach y datos de importaciones. Esta acción no se puede deshacer.'**
  String get resetDescription;

  /// No description provided for @resetPreserveAccess.
  ///
  /// In es, this message translates to:
  /// **'Tu acceso a LumioMoney se conservará. Después volverás al inicio de configuración.'**
  String get resetPreserveAccess;

  /// No description provided for @resetConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Confirma el reinicio'**
  String get resetConfirmTitle;

  /// No description provided for @resetConfirmMessage.
  ///
  /// In es, this message translates to:
  /// **'Para continuar, escribe la palabra que aparece abajo.'**
  String get resetConfirmMessage;

  /// No description provided for @resetTypePrompt.
  ///
  /// In es, this message translates to:
  /// **'Escribe REINICIAR'**
  String get resetTypePrompt;

  /// No description provided for @resetConfirmWord.
  ///
  /// In es, this message translates to:
  /// **'REINICIAR'**
  String get resetConfirmWord;

  /// No description provided for @resetFinalTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar todos tus datos?'**
  String get resetFinalTitle;

  /// No description provided for @resetFinalMessage.
  ///
  /// In es, this message translates to:
  /// **'Se bloquearán los demás dispositivos y se eliminarán tus datos de LumioMoney. No se cerrará tu sesión.'**
  String get resetFinalMessage;

  /// No description provided for @resetAction.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar datos'**
  String get resetAction;

  /// No description provided for @resetProgressTitle.
  ///
  /// In es, this message translates to:
  /// **'Reinicio en curso'**
  String get resetProgressTitle;

  /// No description provided for @resetProgressMessage.
  ///
  /// In es, this message translates to:
  /// **'Estamos eliminando tus datos de forma segura. Mantén esta pantalla abierta o vuelve aquí para continuar si se interrumpe.'**
  String get resetProgressMessage;

  /// No description provided for @resetWorking.
  ///
  /// In es, this message translates to:
  /// **'Reiniciando…'**
  String get resetWorking;

  /// No description provided for @resetResume.
  ///
  /// In es, this message translates to:
  /// **'Continuar reinicio'**
  String get resetResume;

  /// No description provided for @resetFailure.
  ///
  /// In es, this message translates to:
  /// **'No pudimos completar el reinicio. Tus datos siguen bloqueados; puedes reintentar de forma segura.'**
  String get resetFailure;

  /// No description provided for @resetPendingWarning.
  ///
  /// In es, this message translates to:
  /// **'Resuelve primero las {count} operaciones pendientes, en sincronización o rechazadas. No se borró ningún dato.'**
  String resetPendingWarning(Object count);

  /// No description provided for @resetPendingCheckFailure.
  ///
  /// In es, this message translates to:
  /// **'No pudimos verificar los movimientos pendientes. Inténtalo de nuevo antes de reiniciar.'**
  String get resetPendingCheckFailure;

  /// No description provided for @unallocatedPaymentStatus.
  ///
  /// In es, this message translates to:
  /// **'Registrado · falta desglose'**
  String get unallocatedPaymentStatus;

  /// No description provided for @unallocatedPaymentExplanation.
  ///
  /// In es, this message translates to:
  /// **'La salida de dinero ya está registrada. El saldo del crédito y los gastos se actualizarán cuando completes el desglose.'**
  String get unallocatedPaymentExplanation;

  /// No description provided for @debtPayUnallocated.
  ///
  /// In es, this message translates to:
  /// **'Completaré el desglose después'**
  String get debtPayUnallocated;

  /// No description provided for @debtAllocatePayment.
  ///
  /// In es, this message translates to:
  /// **'Completar desglose'**
  String get debtAllocatePayment;

  /// No description provided for @debtCommitmentsTitle.
  ///
  /// In es, this message translates to:
  /// **'Pagos de deudas'**
  String get debtCommitmentsTitle;

  /// No description provided for @debtCommitmentsTab.
  ///
  /// In es, this message translates to:
  /// **'Pagos de deudas'**
  String get debtCommitmentsTab;

  /// No description provided for @budgetsTab.
  ///
  /// In es, this message translates to:
  /// **'Presupuestos'**
  String get budgetsTab;

  /// No description provided for @debtCommitmentReminders.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios locales'**
  String get debtCommitmentReminders;

  /// No description provided for @debtCommitmentsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no has planificado pagos de deudas.'**
  String get debtCommitmentsEmpty;

  /// No description provided for @debtCommitmentCreate.
  ///
  /// In es, this message translates to:
  /// **'Planificar pago'**
  String get debtCommitmentCreate;

  /// No description provided for @debtCommitmentAmount.
  ///
  /// In es, this message translates to:
  /// **'Importe mensual previsto'**
  String get debtCommitmentAmount;

  /// No description provided for @debtCommitmentDueDay.
  ///
  /// In es, this message translates to:
  /// **'Día de vencimiento'**
  String get debtCommitmentDueDay;

  /// No description provided for @debtCommitmentFirstMonth.
  ///
  /// In es, this message translates to:
  /// **'Primer vencimiento'**
  String get debtCommitmentFirstMonth;

  /// No description provided for @debtCommitmentLastMonth.
  ///
  /// In es, this message translates to:
  /// **'Último mes (opcional)'**
  String get debtCommitmentLastMonth;

  /// No description provided for @debtCommitmentMonthlyPlanned.
  ///
  /// In es, this message translates to:
  /// **'Previsto para este mes'**
  String get debtCommitmentMonthlyPlanned;

  /// No description provided for @debtCommitmentPaid.
  ///
  /// In es, this message translates to:
  /// **'Pagado en cuotas'**
  String get debtCommitmentPaid;

  /// No description provided for @debtCommitmentRemaining.
  ///
  /// In es, this message translates to:
  /// **'Falta por cubrir'**
  String get debtCommitmentRemaining;

  /// No description provided for @debtCommitmentStatusUpcoming.
  ///
  /// In es, this message translates to:
  /// **'Próximo'**
  String get debtCommitmentStatusUpcoming;

  /// No description provided for @debtCommitmentStatusDue.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get debtCommitmentStatusDue;

  /// No description provided for @debtCommitmentStatusPartial.
  ///
  /// In es, this message translates to:
  /// **'Parcialmente pagado'**
  String get debtCommitmentStatusPartial;

  /// No description provided for @debtCommitmentStatusPaid.
  ///
  /// In es, this message translates to:
  /// **'Pagado'**
  String get debtCommitmentStatusPaid;

  /// No description provided for @debtCommitmentStatusMissed.
  ///
  /// In es, this message translates to:
  /// **'Vencido'**
  String get debtCommitmentStatusMissed;

  /// No description provided for @debtCommitmentStatusSkipped.
  ///
  /// In es, this message translates to:
  /// **'Omitido'**
  String get debtCommitmentStatusSkipped;

  /// No description provided for @debtCommitmentStatusPaused.
  ///
  /// In es, this message translates to:
  /// **'Pausado'**
  String get debtCommitmentStatusPaused;

  /// No description provided for @debtPaymentAllocationChoice.
  ///
  /// In es, this message translates to:
  /// **'¿Conoces cómo se distribuye el pago?'**
  String get debtPaymentAllocationChoice;

  /// No description provided for @debtPaymentKnownSplit.
  ///
  /// In es, this message translates to:
  /// **'Sí, ingresaré el desglose'**
  String get debtPaymentKnownSplit;

  /// No description provided for @previousMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes anterior'**
  String get previousMonth;

  /// No description provided for @nextMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes siguiente'**
  String get nextMonth;

  /// No description provided for @debtCommitmentHomeWidget.
  ///
  /// In es, this message translates to:
  /// **'Pagos de deudas'**
  String get debtCommitmentHomeWidget;

  /// No description provided for @debtCommitmentNextDue.
  ///
  /// In es, this message translates to:
  /// **'Próximo vencimiento'**
  String get debtCommitmentNextDue;

  /// No description provided for @debtPaymentsToReview.
  ///
  /// In es, this message translates to:
  /// **'Pagos por revisar'**
  String get debtPaymentsToReview;

  /// No description provided for @unallocatedDebtPayment.
  ///
  /// In es, this message translates to:
  /// **'Pago de crédito sin desglose'**
  String get unallocatedDebtPayment;

  /// No description provided for @debtCommitmentSkip.
  ///
  /// In es, this message translates to:
  /// **'Omitir esta cuota'**
  String get debtCommitmentSkip;

  /// No description provided for @debtCommitmentSkipConfirm.
  ///
  /// In es, this message translates to:
  /// **'Esta cuota se marcará como omitida y no reducirá tus pagos de otros meses.'**
  String get debtCommitmentSkipConfirm;

  /// No description provided for @debtCommitmentPause.
  ///
  /// In es, this message translates to:
  /// **'Pausar futuras'**
  String get debtCommitmentPause;

  /// No description provided for @debtCommitmentResume.
  ///
  /// In es, this message translates to:
  /// **'Reanudar futuras'**
  String get debtCommitmentResume;

  /// No description provided for @debtCommitmentConfirmSkip.
  ///
  /// In es, this message translates to:
  /// **'Omitir cuota'**
  String get debtCommitmentConfirmSkip;

  /// No description provided for @categoryIconGroceries.
  ///
  /// In es, this message translates to:
  /// **'Mercado'**
  String get categoryIconGroceries;

  /// No description provided for @categoryIconCarMaintenance.
  ///
  /// In es, this message translates to:
  /// **'Mantenimiento del vehículo'**
  String get categoryIconCarMaintenance;

  /// No description provided for @categoryIconPhone.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get categoryIconPhone;

  /// No description provided for @categoryIconUtilities.
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get categoryIconUtilities;

  /// No description provided for @categoryIconInsurance.
  ///
  /// In es, this message translates to:
  /// **'Seguros'**
  String get categoryIconInsurance;

  /// No description provided for @categoryIconFamily.
  ///
  /// In es, this message translates to:
  /// **'Familia'**
  String get categoryIconFamily;

  /// No description provided for @categoryIconChildren.
  ///
  /// In es, this message translates to:
  /// **'Hijos'**
  String get categoryIconChildren;

  /// No description provided for @categoryIconParents.
  ///
  /// In es, this message translates to:
  /// **'Padres'**
  String get categoryIconParents;

  /// No description provided for @categoryIconPets.
  ///
  /// In es, this message translates to:
  /// **'Mascotas'**
  String get categoryIconPets;

  /// No description provided for @categoryIconSports.
  ///
  /// In es, this message translates to:
  /// **'Deportes'**
  String get categoryIconSports;

  /// No description provided for @categoryIconHobbies.
  ///
  /// In es, this message translates to:
  /// **'Pasatiempos'**
  String get categoryIconHobbies;

  /// No description provided for @categoryIconSubscriptions.
  ///
  /// In es, this message translates to:
  /// **'Suscripciones'**
  String get categoryIconSubscriptions;

  /// No description provided for @categoryIconEntertainment.
  ///
  /// In es, this message translates to:
  /// **'Entretenimiento'**
  String get categoryIconEntertainment;

  /// No description provided for @categoryIconTravel.
  ///
  /// In es, this message translates to:
  /// **'Viajes'**
  String get categoryIconTravel;

  /// No description provided for @categoryIconShopping.
  ///
  /// In es, this message translates to:
  /// **'Compras'**
  String get categoryIconShopping;

  /// No description provided for @categoryIconClothing.
  ///
  /// In es, this message translates to:
  /// **'Ropa'**
  String get categoryIconClothing;

  /// No description provided for @categoryIconPersonalCare.
  ///
  /// In es, this message translates to:
  /// **'Cuidado personal'**
  String get categoryIconPersonalCare;

  /// No description provided for @categoryIconGift.
  ///
  /// In es, this message translates to:
  /// **'Regalos'**
  String get categoryIconGift;

  /// No description provided for @categoryIconFreelance.
  ///
  /// In es, this message translates to:
  /// **'Trabajo independiente'**
  String get categoryIconFreelance;

  /// No description provided for @categoryIconBusiness.
  ///
  /// In es, this message translates to:
  /// **'Negocio'**
  String get categoryIconBusiness;

  /// No description provided for @categoryIconInvestment.
  ///
  /// In es, this message translates to:
  /// **'Inversiones'**
  String get categoryIconInvestment;

  /// No description provided for @categoryIconSavings.
  ///
  /// In es, this message translates to:
  /// **'Ahorros'**
  String get categoryIconSavings;

  /// No description provided for @categoryIconGroupDaily.
  ///
  /// In es, this message translates to:
  /// **'Vida diaria'**
  String get categoryIconGroupDaily;

  /// No description provided for @categoryIconGroupWellbeing.
  ///
  /// In es, this message translates to:
  /// **'Bienestar y familia'**
  String get categoryIconGroupWellbeing;

  /// No description provided for @categoryIconGroupLifestyle.
  ///
  /// In es, this message translates to:
  /// **'Estilo de vida'**
  String get categoryIconGroupLifestyle;

  /// No description provided for @categoryIconGroupMoney.
  ///
  /// In es, this message translates to:
  /// **'Dinero'**
  String get categoryIconGroupMoney;

  /// No description provided for @categoryIconSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar íconos'**
  String get categoryIconSearchHint;

  /// No description provided for @categoryIconNoResults.
  ///
  /// In es, this message translates to:
  /// **'No hay íconos que coincidan.'**
  String get categoryIconNoResults;

  /// No description provided for @categoryTemplatePrompt.
  ///
  /// In es, this message translates to:
  /// **'Ideas opcionales'**
  String get categoryTemplatePrompt;

  /// No description provided for @categoryTemplateFamily.
  ///
  /// In es, this message translates to:
  /// **'Familia'**
  String get categoryTemplateFamily;

  /// No description provided for @categoryTemplateChildren.
  ///
  /// In es, this message translates to:
  /// **'Hijos'**
  String get categoryTemplateChildren;

  /// No description provided for @categoryTemplateParents.
  ///
  /// In es, this message translates to:
  /// **'Padres'**
  String get categoryTemplateParents;

  /// No description provided for @cardBillingCycle.
  ///
  /// In es, this message translates to:
  /// **'Ciclo de facturación'**
  String get cardBillingCycle;

  /// No description provided for @cardBillingCycleExplanation.
  ///
  /// In es, this message translates to:
  /// **'El corte cierra el periodo del extracto. El día de pago orienta la planificación; confirma la fecha definitiva en tu extracto.'**
  String get cardBillingCycleExplanation;

  /// No description provided for @cardStatementClosingDay.
  ///
  /// In es, this message translates to:
  /// **'Día de corte'**
  String get cardStatementClosingDay;

  /// No description provided for @cardPaymentDueDay.
  ///
  /// In es, this message translates to:
  /// **'Día habitual de pago'**
  String get cardPaymentDueDay;

  /// No description provided for @notConfigured.
  ///
  /// In es, this message translates to:
  /// **'Sin configurar'**
  String get notConfigured;

  /// No description provided for @cardPlanPayment.
  ///
  /// In es, this message translates to:
  /// **'Planificar pago'**
  String get cardPlanPayment;

  /// No description provided for @cardUpcomingDueSuggestion.
  ///
  /// In es, this message translates to:
  /// **'Sugerencia de día de pago: {day}. Revisa tu extracto.'**
  String cardUpcomingDueSuggestion(Object day);

  /// No description provided for @cardUseSuggestedDueDay.
  ///
  /// In es, this message translates to:
  /// **'Usar sugerencia de la tarjeta'**
  String get cardUseSuggestedDueDay;

  /// No description provided for @debtPaymentPlanning.
  ///
  /// In es, this message translates to:
  /// **'Planificación de pagos'**
  String get debtPaymentPlanning;

  /// No description provided for @debtPaymentDueDay.
  ///
  /// In es, this message translates to:
  /// **'Día habitual de pago'**
  String get debtPaymentDueDay;

  /// No description provided for @debtPaymentDayExplanation.
  ///
  /// In es, this message translates to:
  /// **'Es una referencia para planificar. Confirma la fecha de vencimiento en tu contrato o extracto.'**
  String get debtPaymentDayExplanation;

  /// No description provided for @debtUpcomingPaymentSuggestion.
  ///
  /// In es, this message translates to:
  /// **'Día de pago sugerido: {day}. Confirma la fecha con tu entidad.'**
  String debtUpcomingPaymentSuggestion(Object day);

  /// No description provided for @debtUseSuggestedPaymentDay.
  ///
  /// In es, this message translates to:
  /// **'Usar día habitual de pago'**
  String get debtUseSuggestedPaymentDay;

  /// No description provided for @myDevicesTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis dispositivos'**
  String get myDevicesTitle;

  /// No description provided for @myDevicesRegisteredOnly.
  ///
  /// In es, this message translates to:
  /// **'El registro de instalaciones está disponible para cuentas registradas.'**
  String get myDevicesRegisteredOnly;

  /// No description provided for @myDevicesDescription.
  ///
  /// In es, this message translates to:
  /// **'Estas son las instalaciones de la app usadas recientemente con tu cuenta. Una instalación no siempre equivale a un dispositivo físico distinto.'**
  String get myDevicesDescription;

  /// No description provided for @myDevicesRetention.
  ///
  /// In es, this message translates to:
  /// **'Las instalaciones se eliminan después de 90 días sin actividad. Quitar una de esta lista no cierra su sesión; podría aparecer de nuevo si se usa la app.'**
  String get myDevicesRetention;

  /// No description provided for @myDevicesActiveCount.
  ///
  /// In es, this message translates to:
  /// **'Instalaciones activas: {count}'**
  String myDevicesActiveCount(int count);

  /// No description provided for @myDevicesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay instalaciones activas registradas.'**
  String get myDevicesEmpty;

  /// No description provided for @myDevicesLastSeen.
  ///
  /// In es, this message translates to:
  /// **'Última actividad: {date}'**
  String myDevicesLastSeen(String date);

  /// No description provided for @myDevicesAndroid.
  ///
  /// In es, this message translates to:
  /// **'Android'**
  String get myDevicesAndroid;

  /// No description provided for @myDevicesIos.
  ///
  /// In es, this message translates to:
  /// **'iPhone o iPad'**
  String get myDevicesIos;

  /// No description provided for @myDevicesWeb.
  ///
  /// In es, this message translates to:
  /// **'Navegador web'**
  String get myDevicesWeb;

  /// No description provided for @myDevicesUnknown.
  ///
  /// In es, this message translates to:
  /// **'Plataforma desconocida'**
  String get myDevicesUnknown;

  /// No description provided for @myDevicesRemove.
  ///
  /// In es, this message translates to:
  /// **'Quitar'**
  String get myDevicesRemove;

  /// No description provided for @myDevicesRemoveTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Quitar esta instalación?'**
  String get myDevicesRemoveTitle;

  /// No description provided for @myDevicesRemoveWarning.
  ///
  /// In es, this message translates to:
  /// **'Esto solo elimina su registro de la lista. No cierra la sesión de forma remota. Si se vuelve a usar, podría registrarse otra vez.'**
  String get myDevicesRemoveWarning;

  /// No description provided for @myDevicesRemoved.
  ///
  /// In es, this message translates to:
  /// **'Instalación quitada de la lista.'**
  String get myDevicesRemoved;

  /// No description provided for @myDevicesLoadError.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar tus instalaciones.'**
  String get myDevicesLoadError;

  /// No description provided for @coachScreenSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Un paso a la vez para entender tu dinero.'**
  String get coachScreenSubtitle;

  /// No description provided for @coachDataCached.
  ///
  /// In es, this message translates to:
  /// **'Algunos datos vienen de este dispositivo y podrían estar incompletos.'**
  String get coachDataCached;

  /// No description provided for @coachDataFresh.
  ///
  /// In es, this message translates to:
  /// **'Datos actualizados'**
  String get coachDataFresh;

  /// No description provided for @coachWhyThis.
  ///
  /// In es, this message translates to:
  /// **'¿Por qué lo veo?'**
  String get coachWhyThis;

  /// No description provided for @coachActionSyncTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa un movimiento rechazado'**
  String get coachActionSyncTitle;

  /// No description provided for @coachActionSyncBody.
  ///
  /// In es, this message translates to:
  /// **'Un movimiento no se pudo sincronizar. Revísalo antes de volver a intentar.'**
  String get coachActionSyncBody;

  /// No description provided for @coachActionDueTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu cuota de {account} requiere atención'**
  String coachActionDueTitle(String account);

  /// No description provided for @coachActionDueBody.
  ///
  /// In es, this message translates to:
  /// **'La cuota tiene un importe pendiente de registrar. Esto no confirma una mora con tu entidad.'**
  String get coachActionDueBody;

  /// No description provided for @coachActionUpcomingTitle.
  ///
  /// In es, this message translates to:
  /// **'Se acerca la cuota de {account}'**
  String coachActionUpcomingTitle(String account);

  /// No description provided for @coachActionUnallocatedTitle.
  ///
  /// In es, this message translates to:
  /// **'Completa la información de un pago'**
  String get coachActionUnallocatedTitle;

  /// No description provided for @coachActionUnallocatedBody.
  ///
  /// In es, this message translates to:
  /// **'La salida de dinero ya está registrada. Falta distribuir el pago para actualizar el crédito y sus gastos.'**
  String get coachActionUnallocatedBody;

  /// No description provided for @coachActionBudgetTitle.
  ///
  /// In es, this message translates to:
  /// **'Un presupuesto de gastos llegó al límite'**
  String get coachActionBudgetTitle;

  /// No description provided for @coachActionBudgetBody.
  ///
  /// In es, this message translates to:
  /// **'Los movimientos vinculados a este presupuesto alcanzaron el importe previsto.'**
  String get coachActionBudgetBody;

  /// No description provided for @coachActionBudgetProgress.
  ///
  /// In es, this message translates to:
  /// **'Los movimientos vinculados suman {actual} frente a {planned} previstos.'**
  String coachActionBudgetProgress(String actual, String planned);

  /// No description provided for @coachReviewBudget.
  ///
  /// In es, this message translates to:
  /// **'Revisar presupuesto'**
  String get coachReviewBudget;

  /// No description provided for @coachActionWeeklyTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa la semana que terminó'**
  String get coachActionWeeklyTitle;

  /// No description provided for @coachActionDailyTitle.
  ///
  /// In es, this message translates to:
  /// **'Haz el cierre de hoy'**
  String get coachActionDailyTitle;

  /// No description provided for @coachActionConfigureTitle.
  ///
  /// In es, this message translates to:
  /// **'Elige una rutina que te funcione'**
  String get coachActionConfigureTitle;

  /// No description provided for @coachActionCurrentBody.
  ///
  /// In es, this message translates to:
  /// **'Puedes revisar tus movimientos o la semana cuando quieras.'**
  String get coachActionCurrentBody;

  /// No description provided for @coachActionExplain.
  ///
  /// In es, this message translates to:
  /// **'Esta sugerencia se basa en tus registros confirmados y en la rutina que elegiste. No realiza pagos ni cambia tus datos.'**
  String get coachActionExplain;

  /// No description provided for @coachPaymentsSection.
  ///
  /// In es, this message translates to:
  /// **'Pagos que conviene revisar'**
  String get coachPaymentsSection;

  /// No description provided for @coachSeeMore.
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get coachSeeMore;

  /// No description provided for @coachPaymentDue.
  ///
  /// In es, this message translates to:
  /// **'Vence {date}'**
  String coachPaymentDue(String date);

  /// No description provided for @coachPaymentRecordedDate.
  ///
  /// In es, this message translates to:
  /// **'Pago registrado el {date}'**
  String coachPaymentRecordedDate(String date);

  /// No description provided for @coachCommitmentProgress.
  ///
  /// In es, this message translates to:
  /// **'Tienes {paid} registrados de {planned} previstos para esta cuota.'**
  String coachCommitmentProgress(String paid, String planned);

  /// No description provided for @coachPaymentRemaining.
  ///
  /// In es, this message translates to:
  /// **'Falta registrar {amount}'**
  String coachPaymentRemaining(String amount);

  /// No description provided for @coachReviewPayment.
  ///
  /// In es, this message translates to:
  /// **'Revisar cuota'**
  String get coachReviewPayment;

  /// No description provided for @coachActionDueBudgetTitle.
  ///
  /// In es, this message translates to:
  /// **'Atiende: {item}'**
  String coachActionDueBudgetTitle(String item);

  /// No description provided for @coachActionUpcomingBudgetTitle.
  ///
  /// In es, this message translates to:
  /// **'Próximo gasto: {item}'**
  String coachActionUpcomingBudgetTitle(String item);

  /// No description provided for @coachBudgetExpenseDueBody.
  ///
  /// In es, this message translates to:
  /// **'Es un gasto planeado sin suficiente movimiento asociado. La fecha no confirma que siga pendiente fuera de la app.'**
  String get coachBudgetExpenseDueBody;

  /// No description provided for @coachBudgetExpenseUpcomingBody.
  ///
  /// In es, this message translates to:
  /// **'Revisa este gasto planeado y sus movimientos asociados. No se registrará automáticamente.'**
  String get coachBudgetExpenseUpcomingBody;

  /// No description provided for @coachReviewPlannedExpense.
  ///
  /// In es, this message translates to:
  /// **'Revisar gasto planeado'**
  String get coachReviewPlannedExpense;

  /// No description provided for @coachUpcomingPlan.
  ///
  /// In es, this message translates to:
  /// **'Próximos en tu plan'**
  String get coachUpcomingPlan;

  /// No description provided for @coachNoUpcomingPlan.
  ///
  /// In es, this message translates to:
  /// **'No hay gastos o cuotas por atender en los próximos siete días.'**
  String get coachNoUpcomingPlan;

  /// No description provided for @planningDueDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha prevista: {date}'**
  String planningDueDate(String date);

  /// No description provided for @planningDebtTotal.
  ///
  /// In es, this message translates to:
  /// **'Cuotas de deuda previstas: {amount}'**
  String planningDebtTotal(String amount);

  /// No description provided for @coachCompleteAllocation.
  ///
  /// In es, this message translates to:
  /// **'Completar desglose'**
  String get coachCompleteAllocation;

  /// No description provided for @coachWeeklyUnderstanding.
  ///
  /// In es, this message translates to:
  /// **'Entiende tu semana'**
  String get coachWeeklyUnderstanding;

  /// No description provided for @coachWeeklyCategoryInsight.
  ///
  /// In es, this message translates to:
  /// **'La categoría con mayor gasto neto fue {category}: {amount}.'**
  String coachWeeklyCategoryInsight(String category, String amount);

  /// No description provided for @coachIncompleteInfo.
  ///
  /// In es, this message translates to:
  /// **'Hay información pendiente de sincronizar o pagos sin desglose; tus totales podrían estar incompletos.'**
  String get coachIncompleteInfo;

  /// No description provided for @coachSourcesIncomplete.
  ///
  /// In es, this message translates to:
  /// **'Parte de la información todavía no está disponible. Esta recomendación es provisional; podría aparecer una acción más urgente.'**
  String get coachSourcesIncomplete;

  /// No description provided for @coachProvisionalRecommendation.
  ///
  /// In es, this message translates to:
  /// **'Esta recomendación es provisional. Podrían existir acciones más urgentes cuando termine la carga.'**
  String get coachProvisionalRecommendation;

  /// No description provided for @coachNoReliableRecommendation.
  ///
  /// In es, this message translates to:
  /// **'Aún no tenemos información suficiente para recomendar un siguiente paso. Puedes volver a intentarlo.'**
  String get coachNoReliableRecommendation;

  /// No description provided for @coachPaymentsIncomplete.
  ///
  /// In es, this message translates to:
  /// **'No pudimos cargar todos los pagos; esta lista podría estar incompleta.'**
  String get coachPaymentsIncomplete;

  /// No description provided for @coachReviewFullWeek.
  ///
  /// In es, this message translates to:
  /// **'Revisar semana completa'**
  String get coachReviewFullWeek;

  /// No description provided for @coachRoutineTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu rutina'**
  String get coachRoutineTitle;

  /// No description provided for @coachRoutineInvite.
  ///
  /// In es, this message translates to:
  /// **'Activa una o ambas rutinas para llevar seguimiento. Puedes hacer las revisiones aquí sin activar notificaciones.'**
  String get coachRoutineInvite;

  /// No description provided for @coachRoutineDaily.
  ///
  /// In es, this message translates to:
  /// **'Quiero revisar mis movimientos cada día'**
  String get coachRoutineDaily;

  /// No description provided for @coachRoutineWeekly.
  ///
  /// In es, this message translates to:
  /// **'Quiero revisar mis finanzas cada semana'**
  String get coachRoutineWeekly;

  /// No description provided for @coachRoutineStart.
  ///
  /// In es, this message translates to:
  /// **'Activar seguimiento'**
  String get coachRoutineStart;

  /// No description provided for @coachRoutineLater.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get coachRoutineLater;

  /// No description provided for @coachRoutineOff.
  ///
  /// In es, this message translates to:
  /// **'No hay rutinas activas; puedes revisar cuando quieras.'**
  String get coachRoutineOff;

  /// No description provided for @coachRoutineOn.
  ///
  /// In es, this message translates to:
  /// **'Seguimiento activo. Los recordatorios se configuran por separado.'**
  String get coachRoutineOn;

  /// No description provided for @coachRoutineNotDue.
  ///
  /// In es, this message translates to:
  /// **'Todavía no corresponde; la revisión manual sigue disponible.'**
  String get coachRoutineNotDue;

  /// No description provided for @coachRoutineNotConfigured.
  ///
  /// In es, this message translates to:
  /// **'Rutina no configurada; puedes revisar cuando quieras.'**
  String get coachRoutineNotConfigured;

  /// No description provided for @coachOpenDaily.
  ///
  /// In es, this message translates to:
  /// **'Abrir cierre diario'**
  String get coachOpenDaily;

  /// No description provided for @coachOpenWeekly.
  ///
  /// In es, this message translates to:
  /// **'Abrir revisión semanal'**
  String get coachOpenWeekly;

  /// No description provided for @coachRoutineSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar tu rutina. Conservamos tu selección; vuelve a intentarlo.'**
  String get coachRoutineSaveError;

  /// No description provided for @coachNoPaymentsToReview.
  ///
  /// In es, this message translates to:
  /// **'No hay pagos próximos o pendientes de desglose.'**
  String get coachNoPaymentsToReview;

  /// No description provided for @coachReportIncomplete.
  ///
  /// In es, this message translates to:
  /// **'La semana puede estar incompleta porque hay datos guardados en caché o pendientes de sincronización.'**
  String get coachReportIncomplete;

  /// No description provided for @coachToggleAmounts.
  ///
  /// In es, this message translates to:
  /// **'Mostrar u ocultar importes'**
  String get coachToggleAmounts;

  /// No description provided for @coachAmountsHidden.
  ///
  /// In es, this message translates to:
  /// **'Importes ocultos'**
  String get coachAmountsHidden;

  /// No description provided for @planningAgenda.
  ///
  /// In es, this message translates to:
  /// **'Agenda'**
  String get planningAgenda;

  /// No description provided for @planningPlan.
  ///
  /// In es, this message translates to:
  /// **'Planificar'**
  String get planningPlan;

  /// No description provided for @planningPendingOnly.
  ///
  /// In es, this message translates to:
  /// **'Por atender'**
  String get planningPendingOnly;

  /// No description provided for @planningAll.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get planningAll;

  /// No description provided for @planningAllTypes.
  ///
  /// In es, this message translates to:
  /// **'Todos los tipos'**
  String get planningAllTypes;

  /// No description provided for @planningAllCurrencies.
  ///
  /// In es, this message translates to:
  /// **'Todas las monedas'**
  String get planningAllCurrencies;

  /// No description provided for @planningNoEntries.
  ///
  /// In es, this message translates to:
  /// **'No hay elementos planeados para este mes.'**
  String get planningNoEntries;

  /// No description provided for @planningNoPendingEntries.
  ///
  /// In es, this message translates to:
  /// **'Todo lo planeado tiene movimientos asociados.'**
  String get planningNoPendingEntries;

  /// No description provided for @planningSourceExplanation.
  ///
  /// In es, this message translates to:
  /// **'Los movimientos asociados se muestran frente a cada elemento planeado. Las cuotas no ejecutan pagos automáticamente.'**
  String get planningSourceExplanation;

  /// No description provided for @planningRecorded.
  ///
  /// In es, this message translates to:
  /// **'Registrado'**
  String get planningRecorded;

  /// No description provided for @planningPendingAmount.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get planningPendingAmount;

  /// No description provided for @debtLinkExistingPayment.
  ///
  /// In es, this message translates to:
  /// **'Asociar un pago existente'**
  String get debtLinkExistingPayment;

  /// No description provided for @debtNoExistingPayments.
  ///
  /// In es, this message translates to:
  /// **'No hay pagos compatibles sin asociar.'**
  String get debtNoExistingPayments;

  /// No description provided for @planningTotalsUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los totales del mes.'**
  String get planningTotalsUnavailable;

  /// No description provided for @planningDebtCount.
  ///
  /// In es, this message translates to:
  /// **'{count} pagos planeados · {pending} pendientes'**
  String planningDebtCount(int count, int pending);

  /// No description provided for @debtCommitmentsExcluded.
  ///
  /// In es, this message translates to:
  /// **'Omitidos o pausados'**
  String get debtCommitmentsExcluded;

  /// No description provided for @thisMonth.
  ///
  /// In es, this message translates to:
  /// **'Este mes'**
  String get thisMonth;

  /// No description provided for @showLess.
  ///
  /// In es, this message translates to:
  /// **'Ver menos'**
  String get showLess;
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
