import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/db_service.dart';
import '../utils/theme.dart';
import 'login_page.dart';

// Página do painel principal; Stateful para reagir a mudanças nos dados.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

// State da Dashboard: mantém dados e calcula métricas exibidas na UI.
class _DashboardPageState extends State<DashboardPage> {
  // Estados locais com produtos, vendas e flag de carregamento para controlar a tela.
  List<Produto> _produtos = [];
  List<Venda> _vendas = [];
  bool _loading = true;

  // Ciclo de vida: ao iniciar, dispara o carregamento inicial de dados.
  @override
  void initState() {
    super.initState();
    _load();
  }

  // Busca produtos e vendas via serviços (AppState/DbService) de forma assíncrona.
  Future<void> _load() async {
    final state = AppState();
    final db = DbService();
    final produtos = await db.getProdutos(state.empresaId);
    final vendas = await db.getVendas(state.empresaId);
    // Garante que o widget ainda está montado antes de chamar setState.
    if (mounted) {
      setState(() {
        _produtos = produtos;
        _vendas = vendas;
        _loading = false;
      });
    }
  }

  // Soma o total das vendas de hoje filtrando por ano/mês/dia atuais.
  double get _vendasHoje {
    final hoje = DateTime.now();
    return _vendas
        .where((v) =>
            v.data.year == hoje.year &&
            v.data.month == hoje.month &&
            v.data.day == hoje.day)
        .fold(0.0, (s, v) => s + v.total);
  }

  // Acumula o total de vendas do mês corrente.
  double get _vendasMes {
    final hoje = DateTime.now();
    return _vendas
        .where((v) => v.data.year == hoje.year && v.data.month == hoje.month)
        .fold(0.0, (s, v) => s + v.total);
  }

  // Quantidade de vendas realizadas (tamanho da lista).
  int get _vendasRealizadas => _vendas.length;
  int get _totalEstoque => _produtos.fold(0, (s, p) => s + p.qtdEstoque);

  // Compila produtos em alerta: esgotado, baixo estoque ou vencimento próximo.
  List<Produto> get _alertas {
    final result = <Produto>[];
    for (final p in _produtos) {
      if (p.esgotado || p.estoqueAbaixoMinimo) result.add(p);
      // Trata validade: inclui itens com data até 7 dias a partir de hoje.
      if (p.dataValidade != null) {
        final diff = p.dataValidade!.difference(DateTime.now()).inDays;
        if (diff <= 7 && !result.contains(p)) result.add(p);
      }
    }
    return result.take(6).toList();
  }

  // Calcula top 5 mais vendidos: agrega por nome e ordena por quantidade.
  List<MapEntry<String, double>> get _maisVendidos {
    final map = <String, double>{};
    for (final v in _vendas) {
      for (final i in v.itens) {
        map[i.produtoNome] = (map[i.produtoNome] ?? 0) + i.quantidade;
      }
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  // Gera série de 7 dias (D-6 a Hoje) somando o total de vendas por dia.
  List<double> get _vendasSemana {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return _vendas
          .where((v) =>
              v.data.year == day.year &&
              v.data.month == day.month &&
              v.data.day == day.day)
          .fold(0.0, (s, v) => s + v.total);
    });
  }

  // Monta o layout do dashboard com refresh, header e seções.
  @override
  Widget build(BuildContext context) {
    final state = AppState();
    final empresa = state.empresa;

    // Placeholder de carregamento enquanto os dados são obtidos.
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bem-vindo de volta,',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.usuarioNome,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (empresa != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            empresa.nome,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(DateTime.now()),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await AppState().logout();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (_) => const LoginPage()),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.white70),
                    tooltip: 'Sair',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Métricas
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _MetricCard(
                  icon: Icons.attach_money_rounded,
                  bg: const Color(0xFFE7FAF3),
                  iconColor: AppColors.success,
                  label: 'Vendas Hoje',
                  value: formatBRL(_vendasHoje),
                ),
                _MetricCard(
                  icon: Icons.trending_up_rounded,
                  bg: const Color(0xFFF2F5FB),
                  iconColor: AppColors.primaryDark,
                  label: 'Vendas do Mês',
                  value: formatBRL(_vendasMes),
                ),
                _MetricCard(
                  icon: Icons.inventory_2_rounded,
                  bg: const Color(0xFFF0E8FF),
                  iconColor: const Color(0xFF8C5DE8),
                  label: 'Itens em Estoque',
                  value: _totalEstoque.toString(),
                ),
                _MetricCard(
                  icon: Icons.shopping_cart_outlined,
                  bg: const Color(0xFFFFF2E1),
                  iconColor: const Color(0xFFF39B26),
                  label: 'Vendas Realizadas',
                  value: _vendasRealizadas.toString(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Alertas
            if (_alertas.isNotEmpty) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      title: 'Alertas (${_alertas.length})',
                      icon: Icons.warning_amber_rounded,
                      iconColor: AppColors.warning,
                    ),
                    const SizedBox(height: 14),
                    ..._alertas.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AlertRow(produto: p),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Gráfico de vendas da semana
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(title: 'Vendas da Semana'),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: _VendasChart(dados: _vendasSemana),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mais vendidos
            if (_maisVendidos.isNotEmpty) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(title: 'Mais Vendidos'),
                    const SizedBox(height: 14),
                    ..._maisVendidos.asMap().entries.map((e) {
                      final max = _maisVendidos.first.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BestSellerRow(
                          rank: '${e.key + 1}',
                          name: e.value.key,
                          units: '${e.value.value.toInt()} un',
                          progress: max > 0 ? e.value.value / max : 0,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Lucro estimado
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Receita Total — ${_mesNome(DateTime.now().month)}',
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    formatBRL(_vendasMes),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_vendasRealizadas} vendas realizadas no mês',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Formata data longa em pt-BR para exibir no cabeçalho.
  String _formatDate(DateTime d) {
    const dias = [
      'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'
    ];
    const meses = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
    ];
    return '${dias[d.weekday - 1]}, ${d.day} de ${meses[d.month - 1]} de ${d.year}';
  }

  // Retorna o nome do mês usado no resumo de receita.
  String _mesNome(int m) {
    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return meses[m - 1];
  }
}

// Cartão de métrica reutilizável com ícone, rótulo e valor destacado.
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color iconColor;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.bg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 4),
            color: Color(0x0E000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Linha de alerta: mostra status do produto e detalhe contextual.
class _AlertRow extends StatelessWidget {
  final Produto produto;
  const _AlertRow({required this.produto});

  @override
  Widget build(BuildContext context) {
    String status;
    Color statusColor;
    String subtitle;
    Color bgColor;

    // Regras para definir status, cor e mensagem do alerta conforme a situação.
    if (produto.esgotado) {
      status = 'ESGOTADO';
      statusColor = AppColors.danger;
      subtitle = 'Produto esgotado';
      bgColor = const Color(0xFFFDEEEE);
    } else if (produto.estoqueAbaixoMinimo) {
      status = 'BAIXO';
      statusColor = AppColors.warning;
      subtitle = 'Estoque: ${produto.qtdEstoque} (mín: ${produto.estoqueMinimo})';
      bgColor = const Color(0xFFFFF5E8);
    } else if (produto.dataValidade != null) {
      final diff = produto.dataValidade!.difference(DateTime.now()).inDays;
      status = 'VENCE';
      statusColor = AppColors.warning;
      subtitle = diff <= 0 ? 'Vencido!' : 'Vence em $diff dias';
      bgColor = const Color(0xFFFFF5E8);
    } else {
      status = 'ALERTA';
      statusColor = AppColors.muted;
      subtitle = '';
      bgColor = const Color(0xFFF5F7FB);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produto.nome,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          StatusBadge(label: status, color: statusColor),
        ],
      ),
    );
  }
}

// Item do ranking de mais vendidos com posição e barra de progresso.
class _BestSellerRow extends StatelessWidget {
  final String rank;
  final String name;
  final String units;
  final double progress;

  const _BestSellerRow({
    required this.rank,
    required this.name,
    required this.units,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(
            rank,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE9EEF6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.accentGreen),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          units,
          style: const TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// Gráfico de barras das vendas semanais utilizando fl_chart.
class _VendasChart extends StatelessWidget {
  final List<double> dados;
  const _VendasChart({required this.dados});

  @override
  Widget build(BuildContext context) {
    // Calcula o valor máximo para normalizar a escala do eixo Y.
    final max = dados.isEmpty
        ? 1.0
        : dados.reduce((a, b) => a > b ? a : b);
    final labels = ['D-6', 'D-5', 'D-4', 'D-3', 'D-2', 'Ont.', 'Hoje'];

// Define rótulos para os últimos 7 dias (do mais antigo ao atual).

    // Cria e configura o BarChart: escala, toques, títulos e grupos de barras.
    return BarChart(
      BarChartData(
        maxY: max > 0 ? max * 1.3 : 100,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                formatBRL(rod.toY),
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              );
            },
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
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox();
                return Text(
                  labels[i],
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 11),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: dados.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: e.key == dados.length - 1
                    ? AppColors.primary
                    : AppColors.primaryDark.withOpacity(0.5),
                width: 18,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
