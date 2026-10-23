// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get debtTitle => 'Cartões e empréstimos';

  @override
  String get debtAdd => 'Adicionar cartão ou empréstimo';

  @override
  String get debtMoney => 'Dinheiro disponível';

  @override
  String get debtCards => 'Cartões de crédito';

  @override
  String get debtLoans => 'Créditos e empréstimos';

  @override
  String get debtProduct => 'Produto';

  @override
  String get debtCreditCard => 'Cartão de crédito';

  @override
  String get debtBankLoan => 'Crédito bancário';

  @override
  String get debtPersonalLoan => 'Empréstimo pessoal recebido';

  @override
  String get debtRegistered => 'Dívida registrada';

  @override
  String get debtCreditBalance => 'Saldo credor em cartões';

  @override
  String get debtPosition => 'Posição líquida registrada';

  @override
  String get debtPositionNote =>
      'Somente registros selecionados; não representa todo o seu patrimônio.';

  @override
  String get debtOpeningMode => 'Origem do saldo';

  @override
  String get debtExisting => 'Dívida existente (não movimenta dinheiro)';

  @override
  String get debtReceived => 'Empréstimo recebido agora';

  @override
  String get debtReferenceDate => 'Data do saldo inicial';

  @override
  String get debtPrincipal => 'Capital pendente';

  @override
  String get debtCharges => 'Encargos acumulados pendentes';

  @override
  String get debtLimit => 'Limite (opcional)';

  @override
  String get debtCreditor => 'Credor (opcional)';

  @override
  String get debtLastFour => 'Últimos 4 dígitos (opcional)';

  @override
  String get debtPay => 'Registrar pagamento';

  @override
  String get debtPayCard => 'Pagar cartão';

  @override
  String get debtDisburse => 'Registrar desembolso';

  @override
  String get debtCharge => 'Registrar encargo';

  @override
  String get debtRefund => 'Estorno de despesa';

  @override
  String get debtAdjust => 'Ajustar dívida';

  @override
  String get debtPurchase => 'Compra com cartão';

  @override
  String get debtPreviousCharges => 'Encargos já registrados pagos';

  @override
  String get debtNewCharges => 'Novos encargos pagos agora';

  @override
  String get debtOriginalPurchase => 'Compra original';

  @override
  String get debtBank => 'Conta de dinheiro';

  @override
  String get debtReview => 'Revisar antes de confirmar';

  @override
  String get debtOnline => 'Requer conexão. Seu rascunho é mantido se o salvamento falhar.';

  @override
  String get debtDisabled => 'A função de dívidas ainda não está ativada no servidor.';

  @override
  String get debtErrorSplit =>
      'Complete a divisão: capital, encargos registrados e novos devem somar o pagamento.';

  @override
  String get debtErrorComponents =>
      'A alteração deixaria capital ou encargos negativos. Revise a divisão e os movimentos posteriores.';

  @override
  String get debtErrorRefund => 'Confira a compra original e o valor ainda não estornado.';

  @override
  String get debtErrorDate => 'A data não pode ser anterior ao saldo inicial.';

  @override
  String get debtErrorArchive => 'Só é possível arquivar uma obrigação com saldo zero.';

  @override
  String get debtErrorReference => 'Revise a conta, moeda, categoria e orçamento selecionados.';

  @override
  String get debtOverLimit => 'A dívida supera o limite registrado. O movimento foi salvo.';

  @override
  String get debtReverse => 'Anular com reversão';

  @override
  String get debtComponents => 'Componentes vinculados';

  @override
  String get debtCommand => 'Comando';

  @override
  String get debtReversal => 'Reversão';

  @override
  String get budgetConnectionRequired =>
      'É necessário ter conexão para salvar este orçamento. Suas alterações continuam aqui; tente novamente.';

  @override
  String get budgetCommandArchived => 'Este orçamento ou item foi arquivado. Atualize a lista.';

  @override
  String get budgetCommandNotFound =>
      'Este orçamento ou item não está mais disponível. Atualize a lista.';

  @override
  String get budgetCommandConflict =>
      'A solicitação entra em conflito com uma alteração anterior. Atualize o orçamento antes de tentar novamente.';

  @override
  String get appTitle => 'LumioMoney';

  @override
  String get sessionCheckFailed =>
      'Não foi possível verificar seu perfil. Confira a conexão e tente novamente, ou entre na conta outra vez.';

  @override
  String get sessionSignOut => 'Sair da conta e voltar ao login';

  @override
  String get loginTitle => 'Entrar';

  @override
  String get createAccount => 'Criar conta';

  @override
  String get continueAsGuest => 'Continuar como convidado';

  @override
  String get authLoginTab => 'Entrar';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authEmailHint => 'voce@exemplo.com';

  @override
  String get authPasswordLabel => 'Senha';

  @override
  String get authEmailInvalid => 'Digite um e-mail válido.';

  @override
  String get authPasswordTooShort => 'Use pelo menos 8 caracteres.';

  @override
  String get authForgotPassword => 'Esqueceu a senha?';

  @override
  String get authResetEmailInvalid => 'Digite um e-mail válido para recuperar sua senha.';

  @override
  String get authPasswordResetSent =>
      'Se existir uma conta com este e-mail, enviamos um link para redefinir a senha.';

  @override
  String get authShowPassword => 'Mostrar senha';

  @override
  String get authHidePassword => 'Ocultar senha';

  @override
  String get authContinueWithGoogle => 'Continuar com Google';

  @override
  String get authOrContinueWith => 'ou continue com';

  @override
  String get authPrivacyNote => 'Seus dados são privados e criptografados.';

  @override
  String get authActionFailed => 'Não foi possível concluir. Confira seus dados e tente novamente.';

  @override
  String get authNetworkError => 'Sem conexão. Verifique sua internet e tente novamente.';

  @override
  String get authTagline => 'Clareza para cada real.';

  @override
  String get hideBalances => 'Ocultar valores';

  @override
  String get showBalances => 'Mostrar valores';

  @override
  String get hiddenAmount => 'Valor oculto';

  @override
  String get moreOptions => 'Mais opções';

  @override
  String get dashboardTitle => 'Seu dinheiro, com clareza.';

  @override
  String get homeMenu => 'Mais opções';

  @override
  String get homeTotalBalance => 'Saldo total';

  @override
  String get homeBudgetTitle => 'Orçamento do mês';

  @override
  String get homeExpenseVsBudget => 'Despesa vs. orçamento';

  @override
  String get homeIncomeVsBudget => 'Receita vs. orçamento';

  @override
  String homeBudgetComparisonDetails(Object actual, Object planned) {
    return 'Realizado · $actual / Planejado · $planned';
  }

  @override
  String get homeNoBudgetForFlow => 'Sem orçamento neste mês';

  @override
  String homeMonthlySummary(Object month, Object currency) {
    return 'Resumo de $month · $currency';
  }

  @override
  String get seeAll => 'Ver tudo';

  @override
  String get setupTitle => 'Configure o LumioMoney';

  @override
  String get personalizeExperience => 'Prepare seu espaço';

  @override
  String get onboardingSubtitle => 'Escolha suas preferências. Você pode alterá-las depois.';

  @override
  String get language => 'Idioma';

  @override
  String get country => 'País';

  @override
  String get baseCurrency => 'Moeda principal';

  @override
  String get firstAccountName => 'Nome da sua primeira conta';

  @override
  String get continueAction => 'Continuar';

  @override
  String get home => 'Início';

  @override
  String get activity => 'Atividade';

  @override
  String get activitySubtitle => 'Encontre e revise suas movimentações';

  @override
  String get activityFilterAll => 'Todas';

  @override
  String get activityFilterTransfers => 'Transferências';

  @override
  String get activityBalanceAdjustmentsFilter => 'Ajustes';

  @override
  String get activityBalanceAdjustmentType => 'Ajuste de saldo';

  @override
  String activityBalanceAdjustmentEntry(Object previous, Object target, Object difference) {
    return 'Saldo $previous → objetivo $target · diferença $difference';
  }

  @override
  String get activityBalanceAdjustmentsHeader => 'Ajustes de saldo';

  @override
  String get activityBalanceAdjustmentsEmpty => 'Não há ajustes para estes filtros.';

  @override
  String activityFilterAction(Object account, Object period) {
    return 'Filtros · $account · $period';
  }

  @override
  String get activityFilterTitle => 'Filtrar atividade';

  @override
  String get activityFilterAccount => 'CONTA';

  @override
  String get activityFilterAllAccounts => 'Todas as contas';

  @override
  String get activityFilterPeriod => 'PERÍODO';

  @override
  String get activityFilterMonth => 'Mês';

  @override
  String get activityFilterDateRange => 'Intervalo de datas';

  @override
  String get activityFilterSelectAccount => 'Escolha as contas';

  @override
  String get activityFilterMultiSelectHint =>
      'Escolha até 10 contas. Uma transferência aparece se qualquer uma das contas for selecionada.';

  @override
  String get activityFilterDone => 'Concluído';

  @override
  String activityFilterSelectedAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contas',
      one: '$count conta',
    );
    return '$_temp0';
  }

  @override
  String get activityFilterSelectMonth => 'Escolher mês';

  @override
  String get activityFilterStartDate => 'DE';

  @override
  String get activityFilterEndDate => 'ATÉ';

  @override
  String get activityFilterTimezoneHint => 'O mês segue o seu fuso horário.';

  @override
  String activityFilterRangeHint(Object month) {
    return 'Escolha datas dentro de $month.';
  }

  @override
  String get activityFilterApply => 'Aplicar filtros';

  @override
  String get activityFilterReset => 'Redefinir';

  @override
  String activityFilterUseMonth(Object month) {
    return 'Usar $month';
  }

  @override
  String get activityFilterUseDate => 'Usar data';

  @override
  String get activityFilterAllDates => 'Todas as datas';

  @override
  String activityFilterSelectedDetails(Object account, Object range) {
    return '$account · $range';
  }

  @override
  String get activityShare => 'Compartilhar';

  @override
  String get activityShareSubject => 'Atividade do LumioMoney';

  @override
  String get activityShareFailed =>
      'Não foi possível preparar ou compartilhar o arquivo. Tente novamente.';

  @override
  String get activityShareEmpty => 'Não há movimentações para compartilhar.';

  @override
  String get activityMovements => 'Movimentações';

  @override
  String activityMovementCount(int count) {
    return 'Movimentações · $count';
  }

  @override
  String get activityExportAction => 'Exportar';

  @override
  String get activityExportTitle => 'Exportar CSV';

  @override
  String get activityExportSubtitle => 'Revise a seleção antes de continuar.';

  @override
  String get activityExportAccount => 'Conta';

  @override
  String get activityExportPeriod => 'Período';

  @override
  String get activityExportType => 'Tipo';

  @override
  String get activityExportCurrencyFormat => 'Moeda · Formato';

  @override
  String activityExportConfirmedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimentações confirmadas',
      one: '1 movimentação confirmada',
      zero: '0 movimentações confirmadas',
    );
    return '$_temp0';
  }

  @override
  String activityExportIncludedCount(int count) {
    return '$count movimentações incluídas';
  }

  @override
  String activityExportMoreCount(int count) {
    return 'e mais $count';
  }

  @override
  String get activityExportIncludePending => 'Incluir pendentes';

  @override
  String activityExportPendingExcluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimentações pendentes excluídas. Ative para incluí-las.',
      one: '1 movimentação pendente excluída. Ative para incluí-la.',
    );
    return '$_temp0';
  }

  @override
  String activityExportPendingIncluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimentações pendentes serão incluídas e identificadas como pendentes.',
      one: '1 movimentação pendente será incluída e identificada como pendente.',
    );
    return '$_temp0';
  }

  @override
  String get activityExportAllResults =>
      'Todas as movimentações filtradas serão exportadas, não apenas as carregadas. Ordem, datas e fuso horário serão preservados.';

  @override
  String get activityExportNoNotes =>
      'As notas não são incluídas. Salvar e compartilhar usam o mesmo CSV.';

  @override
  String get activityExportSave => 'Salvar arquivo';

  @override
  String get activityExportShare => 'Compartilhar arquivo';

  @override
  String activityExportPreparing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimentações',
      one: '1 movimentação',
    );
    return 'Preparando $_temp0…';
  }

  @override
  String get activityExportErrorTitle => 'Não foi possível gerar o arquivo';

  @override
  String get activityExportErrorMessage =>
      'Ocorreu um problema temporário. Sua seleção continua aqui; tente novamente.';

  @override
  String get activityExportCloseHint => 'Ao fechar, seus filtros e seleção serão mantidos.';

  @override
  String get activityTotalsTitle => 'Resumo';

  @override
  String get activityTotalsIncome => 'Receitas';

  @override
  String get activityTotalsExpenses => 'Despesas';

  @override
  String get activityTotalsNet => 'Resultado';

  @override
  String get activityTotalsMethodNote => 'Receitas − despesas · Transferências excluídas';

  @override
  String get activityTransfersTotalsNote =>
      'Transferências não entram em receitas, despesas nem no resultado.';

  @override
  String get activityTotalsEmpty =>
      'Não há receitas ou despesas confirmadas para calcular os totais.';

  @override
  String get activityCsvDate => 'Data e hora';

  @override
  String get activityCsvType => 'Tipo';

  @override
  String get activityCsvDescription => 'Descrição';

  @override
  String get activityCsvAccount => 'Conta(s)';

  @override
  String get activityCsvCategory => 'Categoria';

  @override
  String get activityCsvAmount => 'Valor';

  @override
  String get activityCsvCurrency => 'Moeda';

  @override
  String get activityCsvStatus => 'Status';

  @override
  String get activityCsvPending => 'Pendente';

  @override
  String get activityCsvConfirmed => 'Confirmada';

  @override
  String get activityCsvRejected => 'Rejeitada';

  @override
  String get activityCsvUnknownAccount => 'Conta desconhecida';

  @override
  String get activityCsvUnknownCategory => 'Categoria desconhecida';

  @override
  String get transferOperationLabel => 'Transferência';

  @override
  String get budget => 'Orçamento';

  @override
  String get accounts => 'Contas';

  @override
  String get accountsTitle => 'Contas e dívidas';

  @override
  String get accountsSubtitle => 'Dinheiro, cartões e empréstimos em um só lugar';

  @override
  String get addAccount => 'Adicionar conta';

  @override
  String get cashAccountType => 'Dinheiro';

  @override
  String get checkingAccountType => 'Conta corrente';

  @override
  String get savingsAccountType => 'Conta poupança';

  @override
  String get addMovement => 'Adicionar movimentação';

  @override
  String get addMovementChoiceTitle => 'O que você quer adicionar?';

  @override
  String get addMovementChoiceSubtitle => 'Escolha uma opção para continuar';

  @override
  String get moveMoney => 'Mover dinheiro';

  @override
  String get close => 'Fechar';

  @override
  String get transferExplanation =>
      'Transfira dinheiro entre suas próprias contas. Isso não aumenta nem reduz o saldo total.';

  @override
  String incomeRegistered(Object amount) {
    return 'Receita registrada · $amount';
  }

  @override
  String expenseRegistered(Object amount) {
    return 'Despesa registrada · $amount';
  }

  @override
  String get transferRegistered => 'Transferência registrada';

  @override
  String get viewMovement => 'Ver lançamento';

  @override
  String get viewDetails => 'Ver detalhes';

  @override
  String get viewPendingOperations => 'Ver pendentes';

  @override
  String get pendingBalanceNote =>
      'Há lançamentos salvos neste dispositivo. O saldo confirmado pode ainda não incluí-los.';

  @override
  String get notVisibleWithCurrentFilters => 'Este lançamento não aparece com os filtros atuais';

  @override
  String get genericError => 'Algo deu errado. Tente novamente.';

  @override
  String get createFirstAccount => 'Crie sua primeira conta para começar.';

  @override
  String get plannedAmountLabel => 'Total planejado';

  @override
  String get timeZone => 'Fuso horário';

  @override
  String get timeZoneBogota => 'Bogotá (UTC−5)';

  @override
  String get timeZoneMexicoCity => 'Cidade do México (UTC−6)';

  @override
  String get timeZoneSaoPaulo => 'São Paulo (UTC−3)';

  @override
  String get createCategory => 'Criar categoria';

  @override
  String get manageCategories => 'Gerenciar categorias';

  @override
  String get editCategory => 'Editar categoria';

  @override
  String get edit => 'Editar';

  @override
  String get categoriesSubtitle => 'Organize seus lançamentos com nomes conhecidos.';

  @override
  String get categorySavedDescription => 'O nome aparecerá nos seus lançamentos e orçamentos.';

  @override
  String get confirmArchiveCategoryTitle => 'Arquivar esta categoria?';

  @override
  String get categoryName => 'Nome';

  @override
  String get categoryTypeReadOnly => 'Tipo · não pode ser alterado';

  @override
  String get saveCategoryChanges => 'Salvar alterações';

  @override
  String get archiveCategoryDetails =>
      'Ela não aparecerá em novos lançamentos. Os registros existentes continuarão com esta categoria.';

  @override
  String get categoryNameRequired => 'Digite um nome para esta categoria.';

  @override
  String get categorySaved => 'Categoria atualizada';

  @override
  String get newCategory => 'Nova categoria';

  @override
  String get archive => 'Arquivar';

  @override
  String get adjustAccountBalance => 'Ajustar saldo';

  @override
  String get balanceAdjustmentTitle => 'Ajustar saldos';

  @override
  String get balanceAdjustmentSubtitle => 'O saldo inicial e as movimentações não serão alterados.';

  @override
  String get balanceAdjustmentTarget => 'Saldo real';

  @override
  String balanceAdjustmentCurrent(Object balance) {
    return 'Saldo atual: $balance';
  }

  @override
  String get balanceAdjustmentPrevious => 'Saldo anterior';

  @override
  String get balanceAdjustmentDifferenceLabel => 'Diferença';

  @override
  String balanceAdjustmentDifference(Object amount) {
    return 'Diferença: $amount';
  }

  @override
  String get balanceAdjustmentReason => 'Motivo (opcional)';

  @override
  String get balanceAdjustmentOtherDevicesHint =>
      'Sincronize primeiro as movimentações pendentes nos outros dispositivos; elas podem alterar estes saldos depois.';

  @override
  String get balanceAdjustmentPendingHint =>
      'Resolva as movimentações pendentes, em sincronização ou rejeitadas das contas selecionadas antes de ajustar.';

  @override
  String get balanceAdjustmentSave => 'Salvar ajustes';

  @override
  String get balanceAdjustmentNoop => 'O saldo desejado já corresponde ao saldo atual.';

  @override
  String get balanceAdjustmentInvalidAmount =>
      'Informe um saldo válido dentro do limite permitido.';

  @override
  String get balanceAdjustmentSuccess => 'Saldos atualizados.';

  @override
  String get confirmArchiveCategory =>
      'A categoria será arquivada e mantida nos seus lançamentos anteriores.';

  @override
  String get expenseCategories => 'Despesas';

  @override
  String get incomeCategories => 'Receitas';

  @override
  String get systemCategory => 'Padrão';

  @override
  String get customCategory => 'Personalizada';

  @override
  String get noCategories => 'Ainda não há categorias para este tipo.';

  @override
  String get categoryType => 'Tipo de categoria';

  @override
  String get newAccount => 'Nova conta';

  @override
  String get accountName => 'Nome da conta';

  @override
  String get initialBalance => 'Saldo inicial';

  @override
  String get editAccount => 'Editar conta';

  @override
  String get confirmArchiveAccount =>
      'A conta será arquivada. Seu histórico e saldo serão mantidos.';

  @override
  String get deleteOperation => 'Excluir movimentação';

  @override
  String get confirmDeleteOperation =>
      'Esta movimentação será removida da atividade e o saldo será recalculado.';

  @override
  String get editOperation => 'Editar movimentação';

  @override
  String get savedPending => 'Salvo neste dispositivo. Será sincronizado quando a conexão voltar.';

  @override
  String get categories => 'Categorias';

  @override
  String get income => 'Receita';

  @override
  String get expense => 'Despesa';

  @override
  String get transfer => 'Transferir';

  @override
  String get addIncome => 'Adicionar receita';

  @override
  String get addExpense => 'Adicionar despesa';

  @override
  String get transferMoney => 'Transferir dinheiro';

  @override
  String get currentBalance => 'Saldo atual';

  @override
  String get recentActivity => 'Atividade recente';

  @override
  String get noTransactions => 'Você ainda não tem movimentações.';

  @override
  String get amount => 'Valor';

  @override
  String get amountInvalid => 'Informe um valor válido maior que zero.';

  @override
  String get amountTooLarge => 'O valor não pode exceder 1.000.000.000 nesta moeda.';

  @override
  String get operationAccountRequired => 'Escolha uma conta.';

  @override
  String get operationCategoryRequired => 'Escolha uma categoria.';

  @override
  String get transferSourceRequired => 'Escolha a conta de origem.';

  @override
  String get transferDestinationRequired => 'Escolha a conta de destino.';

  @override
  String get transferAccountsDifferent => 'Escolha duas contas diferentes com a mesma moeda.';

  @override
  String get budgetDayInvalidForMonth => 'Escolha um dia existente no mês selecionado.';

  @override
  String get onboardingAccountRequired => 'Informe o nome da sua primeira conta.';

  @override
  String get type => 'Tipo';

  @override
  String get date => 'Data';

  @override
  String get time => 'Horário';

  @override
  String get account => 'Conta';

  @override
  String get category => 'Categoria';

  @override
  String get descriptionOptional => 'Descrição (opcional)';

  @override
  String get save => 'Salvar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get sourceAccount => 'Conta de origem';

  @override
  String get destinationAccount => 'Conta de destino';

  @override
  String get optionalNote => 'Observação opcional';

  @override
  String get confirmTransfer => 'Confirmar transferência';

  @override
  String get reviewTransfer => 'Revisar transferência';

  @override
  String get invalidTransfer => 'Escolha contas diferentes, com a mesma moeda, e um valor válido.';

  @override
  String get completeRequiredFields => 'Preencha valor, conta e categoria.';

  @override
  String budgetTracking(Object month) {
    return 'Acompanhamento · $month';
  }

  @override
  String get noBudgetsThisMonth => 'Não há orçamentos para este mês.';

  @override
  String planned(Object amount) {
    return 'Planejado $amount';
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
  String get createBudget => 'Criar orçamento';

  @override
  String get newBudget => 'Novo orçamento';

  @override
  String get budgetItem => 'Item';

  @override
  String get budgetCategory => 'Categoria';

  @override
  String get budgetSaved => 'Orçamento salvo';

  @override
  String get signOut => 'Sair';

  @override
  String get sessionExpired => 'Sessão expirada';

  @override
  String loadError(Object message) {
    return 'Não foi possível carregar: $message';
  }

  @override
  String get retry => 'Tentar novamente';

  @override
  String get offlinePending => 'Sincronização pendente';

  @override
  String get offlineRejected => 'Não foi possível sincronizar. Você pode tentar novamente.';

  @override
  String get syncIssueNetwork =>
      'Não foi possível conectar ao servidor. Este movimento continua salvo no dispositivo; tente novamente quando a conexão voltar.';

  @override
  String get syncIssuePermissionDenied =>
      'O Firebase rejeitou este movimento. Verifique sua sessão; se continuar, compartilhe o código de diagnóstico com o suporte.';

  @override
  String get syncIssueInvalidOperation =>
      'Este movimento não corresponde mais aos dados atuais. Verifique a conta, categoria ou orçamento antes de tentar novamente.';

  @override
  String get syncIssueUnexpected =>
      'Não foi possível identificar a causa. Compartilhe o código de diagnóstico com o suporte.';

  @override
  String syncDiagnosticCode(Object code) {
    return 'Código de diagnóstico: $code';
  }

  @override
  String get syncing => 'Sincronizando...';

  @override
  String get synced => 'Sincronizado';

  @override
  String get changeMonth => 'Mudar mês';

  @override
  String get byCategory => 'Por categoria';

  @override
  String get plannedSummary => 'Planejado · real · restante';

  @override
  String plannedTotal(Object amount) {
    return '$amount planejado';
  }

  @override
  String usedSummary(Object currency, Object percent, Object remaining) {
    return '$currency · $percent% usado · $remaining restante';
  }

  @override
  String get unbudgetedMovements => 'Movimentações sem orçamento';

  @override
  String get reviewCategories => 'Revisar categorias';

  @override
  String get viewBudgetDetails => 'Ver detalhes do orçamento';

  @override
  String get accountFormCreateSubtitle => 'Escolha como deseja organizar este dinheiro.';

  @override
  String get accountFormEditSubtitle =>
      'Você pode alterar o nome; o saldo e o tipo ficam vinculados ao seu histórico.';

  @override
  String get accountNameHint => 'Por exemplo, Gastos do dia a dia';

  @override
  String get accountType => 'Tipo de conta';

  @override
  String get accountCurrency => 'Moeda';

  @override
  String get openingBalanceHelper =>
      'Informe 0 ou mais. Você pode atualizar o saldo com suas movimentações.';

  @override
  String profileCurrencyHint(Object currency) {
    return 'A moeda do seu perfil é $currency.';
  }

  @override
  String get accountBalanceReadOnlyHelper =>
      'O saldo muda quando você adiciona receitas, despesas ou transferências.';

  @override
  String get accountNameRequired => 'Informe o nome da conta.';

  @override
  String get invalidInitialBalance => 'Informe um saldo válido igual ou maior que 0.';

  @override
  String get accountSaveFailed =>
      'Não foi possível salvar a conta. Seus dados continuam aqui; tente novamente.';

  @override
  String get budgetCreateTitle => 'Planeje por categoria';

  @override
  String get budgetCreateSubtitle => 'Defina cada item para o seu mês.';

  @override
  String get budgetTrackingTitle => 'Acompanhamento';

  @override
  String get viewBudgetTracking => 'Ver acompanhamento';

  @override
  String get budgetTrackingEmptyTitle => 'Ainda não há orçamentos';

  @override
  String get budgetTrackingEmptyMessage =>
      'Crie um orçamento para comparar seu planejamento com as movimentações do mês.';

  @override
  String budgetUsedPercent(Object percent) {
    return '$percent% utilizado';
  }

  @override
  String budgetReceivedPercent(Object percent) {
    return '$percent% recebido';
  }

  @override
  String unbudgetedCategoryCount(Object count) {
    return '$count categorias têm movimentações sem orçamento';
  }

  @override
  String unbudgetedActualAmount(Object amount) {
    return 'Total sem orçamento · $amount';
  }

  @override
  String get budgetMonth => 'Mês';

  @override
  String get budgetSelectMonth => 'Escolha um mês';

  @override
  String get budgetPlannedItems => 'Itens planejados';

  @override
  String get budgetAddItem => 'Adicionar item';

  @override
  String get budgetRemoveItem => 'Remover';

  @override
  String get budgetItemDescription => 'Descrição do item';

  @override
  String get budgetDescriptionRequired => 'Informe uma descrição.';

  @override
  String get budgetAmountPositive => 'Informe um valor maior que zero.';

  @override
  String get budgetSelectCategory => 'Escolha uma categoria.';

  @override
  String get budgetNoCategories =>
      'Não há categorias para este tipo. Crie uma categoria para continuar.';

  @override
  String get budgetValidateItems => 'Confira a descrição, o valor e o dia de cada item.';

  @override
  String get budgetAlreadyExists => 'Já existe um orçamento para esta categoria e este mês.';

  @override
  String get budgetSaveFailed =>
      'Não foi possível salvar o orçamento. Seus dados continuam aqui; tente novamente.';

  @override
  String get budgetSave => 'Salvar orçamento';

  @override
  String get budgetsTitle => 'Seus orçamentos';

  @override
  String get budgetsSubtitle => 'Planeje e acompanhe o seu mês';

  @override
  String get budgetsForMonth => 'Orçamentos do mês';

  @override
  String get budgetFilterAll => 'Todos';

  @override
  String get budgetFilterExpenses => 'Despesas';

  @override
  String get budgetFilterIncome => 'Receitas';

  @override
  String get budgetEmptyTitle => 'Você ainda não tem orçamentos';

  @override
  String get budgetEmptyMessage =>
      'Crie um orçamento por categoria para saber quanto planeja gastar e quanto resta durante o mês.';

  @override
  String get budgetFilteredEmptyTitle => 'Nenhum orçamento corresponde a este filtro';

  @override
  String get budgetFilteredEmptyMessage => 'Escolha outro filtro para ver seus orçamentos.';

  @override
  String get budgetFilterReset => 'Ver todos';

  @override
  String get budgetSpent => 'Gasto';

  @override
  String get budgetReceived => 'Recebido';

  @override
  String get day => 'Dia';

  @override
  String get budgetDetailTitle => 'Detalhes do orçamento';

  @override
  String get budgetBackToBudgets => 'Orçamentos';

  @override
  String budgetItemsHeading(Object count) {
    return 'Itens planejados · $count';
  }

  @override
  String get budgetEditItemTitle => 'Editar item';

  @override
  String get budgetAddItemSubtitle => 'Adicione outro item a este orçamento.';

  @override
  String get budgetEditItemSubtitle => 'Ajuste a descrição, o valor ou o dia esperado.';

  @override
  String get budgetDescription => 'Descrição';

  @override
  String budgetPlannedAmount(Object currency) {
    return 'Valor planejado · $currency';
  }

  @override
  String get budgetExpectedDay => 'Dia esperado';

  @override
  String get budgetDayRange => 'Escolha um dia entre 1 e 31.';

  @override
  String get budgetTotalUpdatesHint =>
      'O total planejado será atualizado automaticamente ao salvar.';

  @override
  String get budgetSaveChanges => 'Salvar alterações';

  @override
  String get budgetEditFailed =>
      'Não foi possível salvar as alterações. Seus dados continuam aqui; tente novamente.';

  @override
  String get budgetAddItemFailed =>
      'Não foi possível adicionar o item. Seus dados continuam aqui; tente novamente.';

  @override
  String get budgetDeleteItemTitle => 'Remover este item?';

  @override
  String budgetDeleteItemMessage(Object amount) {
    return 'O total planejado diminuirá em $amount. As movimentações registradas não mudarão.';
  }

  @override
  String get budgetLastItemTitle => 'Mantenha pelo menos um item';

  @override
  String get budgetLastItemMessage =>
      'Um orçamento precisa ter pelo menos um item. Para removê-lo, exclua o orçamento completo.';

  @override
  String get budgetDeleteBudgetAction => 'Excluir orçamento';

  @override
  String get budgetDeleteBudgetTitle => 'Excluir este orçamento?';

  @override
  String get budgetDeleteBudgetMessage =>
      'Ele será removido dos seus orçamentos ativos. Suas movimentações e saldos serão mantidos.';

  @override
  String get budgetArchiveSuccess => 'Orçamento removido da lista ativa.';

  @override
  String get budgetDeleteFailed => 'Não foi possível excluir o orçamento. Tente novamente.';

  @override
  String get budgetItemDeleteFailed => 'Não foi possível remover o item. Tente novamente.';

  @override
  String get budgetItemSaved => 'Alterações salvas.';

  @override
  String get budgetItemAdded => 'Item adicionado.';

  @override
  String get budgetEditAction => 'Editar';

  @override
  String get categoryIcon => 'Ícone da categoria';

  @override
  String get categoryColor => 'Cor da categoria';

  @override
  String get categoryColorDefault => 'Padrão';

  @override
  String get categoryColorBlue => 'Azul';

  @override
  String get categoryColorGreen => 'Verde';

  @override
  String get categoryColorOrange => 'Laranja';

  @override
  String get categoryColorPurple => 'Roxo';

  @override
  String get categoryColorRed => 'Vermelho';

  @override
  String get categoryColorTeal => 'Verde-azulado';

  @override
  String categoryColorOption(Object color, Object hex) {
    return '$color · $hex';
  }

  @override
  String get changeColor => 'Alterar';

  @override
  String get useColor => 'Usar cor';

  @override
  String get categoryIconLabel => 'Ícone';

  @override
  String get categoryIconUtensils => 'Talheres';

  @override
  String get categoryIconHouse => 'Casa';

  @override
  String get categoryIconCar => 'Carro';

  @override
  String get categoryIconHeart => 'Coração';

  @override
  String get categoryIconBook => 'Livro';

  @override
  String get categoryIconBriefcase => 'Maleta';

  @override
  String get categoryIconTag => 'Etiqueta';

  @override
  String get changeIcon => 'Alterar';

  @override
  String get useIcon => 'Usar ícone';

  @override
  String get budgetConfirmMonth => 'Confirmar mês';

  @override
  String get categoryIconFood => 'Alimentação';

  @override
  String get categoryIconHousing => 'Moradia';

  @override
  String get categoryIconTransport => 'Transporte';

  @override
  String get categoryIconHealth => 'Saúde';

  @override
  String get categoryIconEducation => 'Educação';

  @override
  String get categoryIconSalary => 'Salário';

  @override
  String get categoryIconOther => 'Outros';

  @override
  String budgetItemActual(Object amount) {
    return 'Registrado: $amount';
  }

  @override
  String get budgetRecordExpense => 'Registrar despesa';

  @override
  String get budgetRecordIncome => 'Registrar receita';

  @override
  String budgetItemNoCompatibleAccount(Object currency) {
    return 'Você precisa de uma conta ativa em $currency para registrar este movimento.';
  }

  @override
  String budgetItemMovementContext(Object description) {
    return 'Movimento para o item: $description';
  }

  @override
  String get budgetArchivedItems => 'Itens arquivados';

  @override
  String get budgetItemArchived => 'Arquivado · movimentos preservados';

  @override
  String get budgetItemLinkedMovements => 'Movimentos vinculados';

  @override
  String get budgetItemNoLinkedMovements => 'Ainda não há movimentos vinculados.';

  @override
  String get budgetLinkedMovementConfirmed => 'Confirmado';

  @override
  String get budgetLinkedMovementPending => 'Pendente de sincronização';

  @override
  String get budgetLinkedMovementRejected => 'Rejeitado · não afeta o total';

  @override
  String budgetArchiveNetworkFailure(Object code) {
    return 'Não foi possível conectar. O orçamento continua ativo; verifique sua conexão e tente novamente. Código: $code';
  }

  @override
  String budgetArchivePermissionFailure(Object code) {
    return 'O Firebase não autorizou esta alteração. O orçamento continua ativo; verifique sua sessão e compartilhe este código com o suporte: $code';
  }

  @override
  String budgetArchiveConflictFailure(Object code) {
    return 'Não foi possível validar o orçamento. Ele continua ativo; compartilhe este código com o suporte: $code';
  }

  @override
  String budgetArchiveUnexpectedFailure(Object code) {
    return 'Não foi possível excluir o orçamento. Ele continua ativo; tente novamente. Código: $code';
  }

  @override
  String get more => 'Mais';

  @override
  String get back => 'Voltar';

  @override
  String get moreSubtitle => 'Personalize o LumioMoney e gerencie suas preferências.';

  @override
  String get moreManagement => 'Gestão';

  @override
  String get moreSession => 'Sessão';

  @override
  String get signOutConfirmTitle => 'Sair da conta?';

  @override
  String get signOutConfirmMessage => 'Você precisará entrar novamente para acessar seus dados.';

  @override
  String signOutPendingWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# movimentações aguardando sincronização',
      one: '# movimentação aguardando sincronização',
    );
    return 'Você tem $_temp0. Sair não as exclui, mas talvez seja necessário entrar novamente para sincronizar.';
  }

  @override
  String get discardChangesTitle => 'Descartar as alterações?';

  @override
  String get discardChangesMessage => 'As alterações ainda não foram salvas.';

  @override
  String get keepEditing => 'Continuar editando';

  @override
  String get discardChanges => 'Descartar';

  @override
  String get accountIncludeInHomeBalance => 'Incluir no saldo do Início';

  @override
  String get accountIncludeInHomeBalanceHint =>
      'Esta conta será incluída no saldo total do Início.';

  @override
  String get homeNoAccountsIncluded => 'Não há contas ativas incluídas no saldo do Início.';

  @override
  String get homeCustomizeTitle => 'Personalizar Início';

  @override
  String get homeCustomizeSubtitle =>
      'Escolha o que deseja ver no Início. Os avisos de sincronização permanecerão visíveis.';

  @override
  String get homeWidgetsSection => 'Cartões do Início';

  @override
  String get homeBudgetCardsSection => 'Orçamentos por categoria';

  @override
  String get homeWidgetTotalBalance => 'Saldo total';

  @override
  String get homeWidgetIncome => 'Resumo de receitas';

  @override
  String get homeWidgetExpense => 'Resumo de despesas';

  @override
  String get homeWidgetExpenseBudget => 'Despesa vs. orçamento';

  @override
  String get homeWidgetIncomeBudget => 'Receita vs. orçamento';

  @override
  String get homeWidgetRecentActivity => 'Atividade recente';

  @override
  String get homeNoBudgetCards => 'Não há orçamentos ativos para personalizar.';

  @override
  String get homePreferencesSaving => 'Salvando preferência…';

  @override
  String get homePreferencesSaveFailed =>
      'Não foi possível salvar. Sua seleção foi mantida; tente novamente.';

  @override
  String get coachTitle => 'Coach e lembretes';

  @override
  String get coachSettingsIntro => 'Organize sua rotina e escolha quando revisar suas finanças.';

  @override
  String get coachDailyTitle => 'Revisão diária';

  @override
  String get coachWeeklyTitle => 'Revisão semanal';

  @override
  String get coachNextStepTitle => 'Seu próximo passo';

  @override
  String get coachDailyReminder => 'Lembrete de revisão diária';

  @override
  String get coachWeeklyReminder => 'Lembrete de revisão semanal';

  @override
  String get coachReminderTime => 'Horário do lembrete';

  @override
  String get coachReminderDays => 'Dias da semana';

  @override
  String get coachDevice => 'Neste dispositivo';

  @override
  String get coachEnableDevice => 'Receber lembretes neste dispositivo';

  @override
  String get coachDevicePrivacy => 'Os avisos não mostram valores nem dados das suas contas.';

  @override
  String get coachWindowNotice =>
      'Abra o app ao menos uma vez a cada 28 dias para renovar os avisos. Alterações de outros dispositivos são aplicadas ao sincronizar.';

  @override
  String get coachPause => 'Pausar por sete dias';

  @override
  String get coachResume => 'Reativar lembretes';

  @override
  String get coachPaused => 'Lembretes pausados';

  @override
  String get coachPermissionGranted => 'Notificações permitidas';

  @override
  String get coachPermissionDenied =>
      'As notificações estão bloqueadas nos ajustes do dispositivo.';

  @override
  String get coachPermissionUnknown => 'Ative os avisos para solicitar permissão.';

  @override
  String get coachUnsupported =>
      'Na web você pode revisar sua rotina. Os lembretes estão disponíveis no Android e iOS.';

  @override
  String get coachOpenSettings => 'Abrir ajustes do dispositivo';

  @override
  String get coachReviewed => 'Revisado';

  @override
  String get coachFinishDaily => 'Já revisei minhas movimentações';

  @override
  String get coachNoMovements => 'Hoje não tive movimentações';

  @override
  String get coachFinishWeekly => 'Marcar semana como revisada';

  @override
  String get coachNoRecords => 'Não há movimentações registradas neste período.';

  @override
  String get coachAllCurrent => 'Sua rotina está em dia.';

  @override
  String get coachDailyAction => 'Revisar minhas movimentações';

  @override
  String get coachWeeklyAction => 'Revisar minha semana';

  @override
  String get coachReviewIntro =>
      'Confira os registros antes de concluir. Registrar uma movimentação não conclui a revisão.';

  @override
  String get coachWeeklyIntro =>
      'Receitas, despesas e Resultado das movimentações confirmadas. Transferências e ajustes não entram nesses totais.';

  @override
  String get coachConfirmedCount => 'Movimentações confirmadas';

  @override
  String get coachPendingCount => 'Sincronização pendente';

  @override
  String get coachRejectedCount => 'Movimentações rejeitadas';

  @override
  String get coachCached =>
      'Dados salvos neste dispositivo; o período pode estar incompleto. Conecte-se e atualize para verificar.';

  @override
  String get coachSavePending => 'Revisão salva neste dispositivo; aguardando sincronização.';

  @override
  String get coachSaveFailed =>
      'Não foi possível salvar. Sua seleção foi mantida; tente novamente.';

  @override
  String get coachSaveConfirmed => 'Revisão salva';

  @override
  String get coachTopCategories => 'Categorias com maiores despesas';

  @override
  String get coachConfigure => 'Configurar minha rotina';

  @override
  String get coachReadFailure => 'Não foi possível carregar sua revisão. Tente novamente.';

  @override
  String get coachNotificationTitle => 'Um momento para suas finanças';

  @override
  String get coachNotificationBody => 'Sua revisão está pronta. Abra o LumioMoney para continuar.';

  @override
  String get coachHomeWidget => 'Próximo passo do coach';

  @override
  String get coachReminderTiming =>
      'Os avisos podem atrasar conforme os ajustes e a economia de bateria do dispositivo.';

  @override
  String get coachPreferencesPending =>
      'Alterações salvas neste dispositivo; aguardando sincronização.';

  @override
  String get coachScheduleFailed => 'Não foi possível programar os avisos. Tente novamente.';

  @override
  String get coachViewMovements => 'Ver movimentações do período';

  @override
  String get coachNoMovementsUnavailable =>
      'Agora há movimentações registradas ou faltam dados atualizados. Revise o dia antes de confirmar.';

  @override
  String get plan => 'Plano';

  @override
  String get coachTab => 'Coach';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get accountsSectionOverview => 'Resumo';

  @override
  String get accountsSectionMoney => 'Dinheiro';

  @override
  String get accountsSectionCards => 'Cartões';

  @override
  String get accountsSectionLoans => 'Empréstimos';

  @override
  String get accountsSectionEmpty => 'Ainda não há contas nesta seção.';

  @override
  String get coachHubTitle => 'Seu coach financeiro';

  @override
  String get coachHubSubtitle =>
      'Revise suas movimentações e construa uma rotina financeira clara.';

  @override
  String get coachHistoryTitle => 'Revisões recentes';

  @override
  String get coachHistoryEmpty => 'Você ainda não concluiu nenhuma revisão.';

  @override
  String get coachSettingsShortcut => 'Configurar lembretes';

  @override
  String get debtSelectForPayment =>
      'Escolha o cartão ou empréstimo que você já pagou. Registrar o pagamento não movimenta dinheiro por você.';

  @override
  String get accountDetailTitle => 'Detalhes da conta';

  @override
  String get operationEditTitle => 'Editar movimentação';

  @override
  String get appearanceTitle => 'Aparência';

  @override
  String get appearanceSubtitle => 'Personalize as cores do LumioMoney nos seus dispositivos.';

  @override
  String get appearanceMode => 'Tema';

  @override
  String get appearanceSystem => 'Sistema';

  @override
  String get appearanceLight => 'Claro';

  @override
  String get appearanceDark => 'Escuro';

  @override
  String get appearancePalette => 'Paleta de cores';

  @override
  String get paletteLumio => 'Lumio';

  @override
  String get paletteClassicBlue => 'Azul clássico';

  @override
  String get paletteOcean => 'Oceano';

  @override
  String get palettePlum => 'Ameixa';

  @override
  String get appearanceSaving => 'Salvando preferência…';

  @override
  String get appearanceSaved => 'Aparência sincronizada';

  @override
  String get appearanceSaveFailed => 'Não foi possível sincronizar. Sua seleção continua aplicada.';

  @override
  String get appearanceRetry => 'Tentar novamente';

  @override
  String get accountKindMoney => 'Conta de dinheiro';

  @override
  String get accountKindCreditCard => 'Cartão de crédito';

  @override
  String get accountKindBankLoan => 'Crédito bancário';

  @override
  String get accountKindPersonalLoan => 'Empréstimo pessoal recebido';

  @override
  String get selectionChoosePrompt => 'Selecionar';

  @override
  String get selectionSearchHint => 'Buscar por nome ou tipo';

  @override
  String get selectionClearSearch => 'Limpar busca';

  @override
  String get selectionNoResults => 'Nenhum resultado';

  @override
  String get accountOptionBalance => 'Saldo';

  @override
  String get accountOptionDebt => 'Dívida';

  @override
  String get accountOptionCreditBalance => 'Saldo credor';

  @override
  String get selectionFrequent => 'Frequentes';

  @override
  String get selectionAll => 'Todas as opções';
}
