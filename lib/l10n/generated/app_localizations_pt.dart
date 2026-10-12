// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'ClearBudget';

  @override
  String get loginTitle => 'Entrar';

  @override
  String get createAccount => 'Criar conta';

  @override
  String get continueAsGuest => 'Continuar como convidado';

  @override
  String get dashboardTitle => 'Seu dinheiro, com clareza.';

  @override
  String get setupTitle => 'Configure o ClearBudget';

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
  String get transferOperationLabel => 'Transferência';

  @override
  String get budget => 'Orçamento';

  @override
  String get accounts => 'Contas';

  @override
  String get accountsTitle => 'Suas contas';

  @override
  String get accountsSubtitle => 'Saldos organizados por moeda';

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
  String get type => 'Tipo';

  @override
  String get date => 'Data';

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
}
