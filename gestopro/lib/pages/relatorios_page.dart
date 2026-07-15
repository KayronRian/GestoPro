import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/db_service.dart';
import '../utils/theme.dart';

// StatefulWidget da tela de relatórios com três abas principais.
// Orquestra filtros de período e a alimentação dos widgets de cada aba.
class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

// State usa SingleTickerProvider para animar o TabController.
// Centraliza dados carregados, filtros e agregações (KPIs).
class _RelatoriosPageState extends State<RelatoriosPage>
    with SingleTickerProviderStateMixin {
  List<Venda> _vendas = [];
  List<Produto> _produtos = [];
  List<Movimentacao> _movs = [];
  bool _loading = true;

  int _tab = 0;
  late TabController _tabCtrl;

  // Filtro de período
  DateTime _inicio = DateTime.now().subtract(const Duration(days: 29));
  DateTime _fim = DateTime.now();

  // initState configura o TabController e observa mudança de aba.
  // Também inicia o carregamento assíncrono dos dados.
  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() => _tab = _tabCtrl.index);
    });
    // Dispara a rotina que busca dados no banco e popula o estado.
    _load();
  }

  // Libera o TabController no ciclo de vida para evitar leaks.
  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // Função assíncrona que consulta DbService e AppState.
  // Ao finalizar, atualiza listas locais e remove o loading.
  Future<void> _load() async {
    final db = DbService();
    final state = AppState();
    final vendas = await db.getVendas(state.empresaId);
    final produtos = await db.getProdutos(state.empresaId);
    final movs = await db.getMovimentacoes(state.empresaId);
    // Verificação de segurança: só atualiza o estado se o widget existir.
    // Evita exceção de setState após dispose.
    if (mounted) {
      setState(() {
        _vendas = vendas;
        _produtos = produtos;
        _movs = movs;
        _loading = false;
      });
    }
  }

  // Filtra vendas pelo intervalo selecionado (fim inclusivo via +1 dia).
  // Base para todos os cálculos e gráficos desta tela.
  List<Venda> get _vendasFiltradas => _vendas.where((v) {
        final d = v.data;
        return !d.isBefore(_inicio) &&
            !d.isAfter(_fim.add(const Duration(days: 1)));
      }).toList();

  double get _totalVendas =>
      _vendasFiltradas.fold(0.0, (s, v) => s + v.total);

  // Estima o custo somando (preço de custo x quantidade) de cada item.
  // Percorre vendas filtradas e resolve produto por produtoId.
  double get _totalCusto {
    double custo = 0;
    for (final v in _vendasFiltradas) {
      for (final item in v.itens) {
        final p = _produtos.where((x) => x.id == item.produtoId).firstOrNull;
        if (p != null) custo += p.precoCusto * item.quantidade;
      }
    }
    return custo;
  }

  double get _lucroEstimado => _totalVendas - _totalCusto;

  // Agrega o total dos últimos 7 dias, formatando chave como dd/MM.
  // Alimenta diretamente o gráfico de barras diário.
  Map<String, double> get _vendasPorDia {
    final map = <String, double>{};
    for (var i = 0; i < 7; i++) {
      final day = _fim.subtract(Duration(days: 6 - i));
      final key =
          '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}';
      map[key] = _vendasFiltradas
          .where((v) =>
              v.data.year == day.year &&
              v.data.month == day.month &&
              v.data.day == day.day)
          .fold(0.0, (s, v) => s + v.total);
    }
    return map;
  }

  // Totaliza vendas por categoria do produto; fallback para 'Outros'.
  // Acumula subtotais dos itens nas respectivas categorias.
  Map<String, double> get _vendasPorCategoria {
    final map = <String, double>{};
    for (final v in _vendasFiltradas) {
      for (final item in v.itens) {
        final p = _produtos.where((x) => x.id == item.produtoId).firstOrNull;
        final cat = (p?.categoria.isNotEmpty == true) ? p!.categoria : 'Outros';
        map[cat] = (map[cat] ?? 0) + item.subtotal;
      }
    }
    return map;
  }

  // Agrupa o valor total por forma de pagamento usando rótulos legíveis.
  Map<String, double> get _vendasPorForma {
    final map = <String, double>{};
    for (final v in _vendasFiltradas) {
      final nome = _formaNome(v.formaPagamento);
      map[nome] = (map[nome] ?? 0) + v.total;
    }
    return map;
  }

  // Constrói cabeçalho (título, seletor de período, TabBar) e conteúdo.
  // O TabBarView alterna as seções conforme o TabController.
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          color: AppColors.primaryDark,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Relatórios',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _selecionarPeriodo,
                    icon: const Icon(Icons.date_range, color: Colors.white70),
                    label: Text(
                      '${formatDate(_inicio)} – ${formatDate(_fim)}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabCtrl,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: AppColors.accentGreen,
                tabs: const [
                  Tab(text: 'Vendas'),
                  Tab(text: 'Estoque'),
                  Tab(text: 'Financeiro'),
                ],
              ),
            ],
          ),
        ),

        // Área de conteúdo: exibe loader durante _loading ou as três abas.
        // Mantém o estado de cada aba via o mesmo TabController.
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _TabVendas(
                      vendas: _vendasFiltradas,
                      vendasPorDia: _vendasPorDia,
                      vendasPorCategoria: _vendasPorCategoria,
                      vendasPorForma: _vendasPorForma,
                      totalVendas: _totalVendas,
                    ),
                    _TabEstoque(produtos: _produtos, movs: _movs),
                    _TabFinanceiro(
                      totalVendas: _totalVendas,
                      totalCusto: _totalCusto,
                      lucro: _lucroEstimado,
                      vendas: _vendasFiltradas,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  // Abre o seletor de intervalo de datas e atualiza o filtro escolhido.
  Future<void> _selecionarPeriodo() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _inicio, end: _fim),
    );
    if (range != null) {
      setState(() {
        _inicio = range.start;
        _fim = range.end;
      });
    }
  }

  // Converte o enum FormaPagamento em texto exibível na interface.
  String _formaNome(FormaPagamento f) {
    switch (f) {
      case FormaPagamento.dinheiro:
        return 'Dinheiro';
      case FormaPagamento.pix:
        return 'PIX';
      case FormaPagamento.debito:
        return 'Débito';
      case FormaPagamento.credito:
        return 'Crédito';
      case FormaPagamento.misto:
        return 'Misto';
    }
  }
}

// ─── Aba de Vendas ────────────────────────────────────────────────────────────
// Widget da aba Vendas: mostra KPIs, gráfico diário, pizza por categoria
// e distribuição por forma de pagamento.
class _TabVendas extends StatelessWidget {
  final List<Venda> vendas;
  final Map<String, double> vendasPorDia;
  final Map<String, double> vendasPorCategoria;
  final Map<String, double> vendasPorForma;
  final double totalVendas;

  const _TabVendas({
    required this.vendas,
    required this.vendasPorDia,
    required this.vendasPorCategoria,
    required this.vendasPorForma,
    required this.totalVendas,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(
        children: [
          // Indicadores
          Row(
            children: [
              Expanded(
                child: _IndicatorCard(
                  label: 'Total de Vendas',
                  value: formatBRL(totalVendas),
                  icon: Icons.attach_money,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IndicatorCard(
                  label: 'Transações',
                  value: '${vendas.length}',
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Gráfico de barras por dia
          // Card com gráfico de barras: define maxY pelo pico e tooltip em BRL.
          // Cada grupo representa um dia dentro dos últimos 7.
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'Vendas por Dia (últimos 7 dias)'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: vendasPorDia.values.every((v) => v == 0)
                      ? const Center(
                          child: Text(
                            'Sem vendas neste período',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : BarChart(
                          BarChartData(
                            maxY: vendasPorDia.values
                                    .reduce((a, b) => a > b ? a : b) *
                                1.3,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (g, gi, rod, ri) =>
                                    BarTooltipItem(
                                  formatBRL(rod.toY),
                                  const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (v, m) {
                                    final keys =
                                        vendasPorDia.keys.toList();
                                    final i = v.toInt();
                                    if (i < 0 || i >= keys.length) {
                                      return const SizedBox();
                                    }
                                    return Text(
                                      keys[i],
                                      style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: vendasPorDia.values
                                .toList()
                                .asMap()
                                .entries
                                .map((e) => BarChartGroupData(
                                      x: e.key,
                                      barRods: [
                                        BarChartRodData(
                                          toY: e.value,
                                          color: AppColors.primary,
                                          width: 18,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                      ],
                                    ))
                                .toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Gráfico por categoria
          // Exibe o gráfico de pizza e a legenda apenas se houver categorias.
          if (vendasPorCategoria.isNotEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(title: 'Vendas por Categoria'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieSections(vendasPorCategoria),
                        centerSpaceRadius: 50,
                        sectionsSpace: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: vendasPorCategoria.keys
                        .toList()
                        .asMap()
                        .entries
                        .map((e) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _pieColor(e.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  e.value,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.text),
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // Forma de pagamento
          if (vendasPorForma.isNotEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(title: 'Por Forma de Pagamento'),
                  const SizedBox(height: 12),
                  ...vendasPorForma.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: totalVendas > 0
                                          ? e.value / totalVendas
                                          : 0,
                                      minHeight: 6,
                                      backgroundColor:
                                          const Color(0xFFE9EEF6),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              formatBRL(e.value),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Transforma o mapa em seções do PieChart e calcula o percentual.
  // O título de cada fatia mostra a participação no total.
  List<PieChartSectionData> _buildPieSections(Map<String, double> data) {
    final total = data.values.fold(0.0, (s, v) => s + v);
    return data.values.toList().asMap().entries.map((e) {
      final pct = total > 0 ? e.value / total * 100 : 0;
      return PieChartSectionData(
        color: _pieColor(e.key),
        value: e.value,
        title: '${pct.toStringAsFixed(0)}%',
        radius: 60,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      );
    }).toList();
  }

  // Paleta cíclica para cores das fatias; evita repetir padrão visual.
  Color _pieColor(int i) {
    const colors = [
      AppColors.primary,
      AppColors.accentGreen,
      Color(0xFF8C5DE8),
      Color(0xFFF39B26),
      AppColors.danger,
      Color(0xFF00BCD4),
    ];
    return colors[i % colors.length];
  }
}

// ─── Aba de Estoque ───────────────────────────────────────────────────────────
class _TabEstoque extends StatelessWidget {
  final List<Produto> produtos;
  final List<Movimentacao> movs;

  const _TabEstoque({required this.produtos, required this.movs});

  @override
  Widget build(BuildContext context) {
    // KPIs de estoque derivados da lista de produtos (quantidade e valor).
    // Abastecem os cartões de indicador no topo da aba.
    final esgotados = produtos.where((p) => p.esgotado).length;
    final baixo = produtos.where((p) => p.estoqueAbaixoMinimo).length;
    final totalItens = produtos.fold(0, (s, p) => s + p.qtdEstoque);
    final valorEstoque = produtos.fold(
        0.0, (s, p) => s + p.precoCusto * p.qtdEstoque);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _IndicatorCard(
                  label: 'Total de Itens',
                  value: '$totalItens',
                  icon: Icons.inventory_2_rounded,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IndicatorCard(
                  label: 'Valor em Estoque',
                  value: formatBRL(valorEstoque),
                  icon: Icons.attach_money,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _IndicatorCard(
                  label: 'Esgotados',
                  value: '$esgotados',
                  icon: Icons.warning_rounded,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IndicatorCard(
                  label: 'Estoque Baixo',
                  value: '$baixo',
                  icon: Icons.trending_down,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Produtos com menor estoque
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'Produtos com Menor Estoque',
                  icon: Icons.trending_down,
                  iconColor: AppColors.warning,
                ),
                const SizedBox(height: 12),
                ...(() {
                  // Copia e ordena produtos por menor estoque para destacar críticos.
                  // Seleciona os 10 com menor quantidade disponível.
                  final sorted = [...produtos]
                    ..sort((a, b) => a.qtdEstoque.compareTo(b.qtdEstoque));
                  return sorted.take(10).map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    p.categoria.isEmpty ? 'Sem categoria' : p.categoria,
                                    style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${p.qtdEstoque} ${p.unidade}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: p.esgotado
                                    ? AppColors.danger
                                    : p.estoqueAbaixoMinimo
                                        ? AppColors.warning
                                        : AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ));
                })(),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Últimas movimentações
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'Últimas Movimentações',
                  icon: Icons.history,
                ),
                const SizedBox(height: 12),
                // Condicional: placeholder se não houver movimentações ou lista as 15 últimas.
                // Diferencia entrada/saída com cor e ícone.
                if (movs.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Nenhuma movimentação registrada',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  )
                else
                  ...movs.take(15).map((m) {
                    final isEntrada = m.tipo == TipoMovimentacao.entrada;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isEntrada
                                  ? AppColors.success.withOpacity(0.12)
                                  : AppColors.danger.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isEntrada ? Icons.add : Icons.remove,
                              color: isEntrada
                                  ? AppColors.success
                                  : AppColors.danger,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.produtoNome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  formatDateTime(m.data),
                                  style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isEntrada ? '+' : '-'}${m.quantidade}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: isEntrada
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aba Financeiro ───────────────────────────────────────────────────────────
// Aba Financeiro: consolida receita, custo e lucro bruto estimado.
// Também lista últimas vendas do período filtrado.
class _TabFinanceiro extends StatelessWidget {
  final double totalVendas;
  final double totalCusto;
  final double lucro;
  final List<Venda> vendas;

  const _TabFinanceiro({
    required this.totalVendas,
    required this.totalCusto,
    required this.lucro,
    required this.vendas,
  });

  @override
  Widget build(BuildContext context) {
    // Calcula a margem bruta (%) usada no texto e na barra de progresso.
    final margem = totalVendas > 0 ? lucro / totalVendas * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      child: Column(
        children: [
          // Card de lucro
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lucro Bruto Estimado',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  formatBRL(lucro),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Margem média: ${margem.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: totalVendas > 0 ? (lucro / totalVendas).clamp(0, 1) : 0,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accentGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _IndicatorCard(
                  label: 'Receita Total',
                  value: formatBRL(totalVendas),
                  icon: Icons.trending_up,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _IndicatorCard(
                  label: 'Custo Total',
                  value: formatBRL(totalCusto),
                  icon: Icons.trending_down,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Últimas vendas
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(
                  title: 'Últimas Vendas',
                  icon: Icons.receipt_long_outlined,
                ),
                const SizedBox(height: 12),
                // Mostra aviso quando não há vendas; caso contrário, lista as 20 mais recentes.
                if (vendas.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Nenhuma venda neste período',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  )
                else
                  ...vendas.take(20).map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.shopping_cart_outlined,
                                  color: AppColors.success, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${v.itens.length} item(ns) · ${v.usuarioNome}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    formatDateTime(v.data),
                                    style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatBRL(v.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.success,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Componente reutilizável para KPIs rápidos (rótulo, valor e ícone).
// Recebe uma cor temática para estilo e ênfase visual.
class _IndicatorCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _IndicatorCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
