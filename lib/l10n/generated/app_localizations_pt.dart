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
  String get personalizeExperience => 'Personalize sua experiência';

  @override
  String get language => 'Idioma';

  @override
  String get country => 'País';

  @override
  String get baseCurrency => 'Moeda principal';

  @override
  String get firstAccountName => 'Nome da sua primeira conta';

  @override
  String get getStarted => 'Começar';

  @override
  String get home => 'Início';

  @override
  String get activity => 'Atividade';

  @override
  String get budget => 'Orçamento';

  @override
  String get accounts => 'Contas';

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
}
