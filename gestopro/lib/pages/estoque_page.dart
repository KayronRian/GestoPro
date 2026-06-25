import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/db_service.dart';
import '../utils/theme.dart';
import 'produto_detalhe_page.dart';
import 'produto_form_page.dart';
import 'movimentacao_page.dart';

class EstoquePage extends StatefulWidget {
  const EstoquePage({super.key});

  @override
  State<EstoquePage> createState() => _EstoquePageState();
}

class _EstoquePageState extends State<EstoquePage>
    with SingleTickerProviderStateMixin {
  List<Produto> _todos = [];
  List<Produto> _filtrados = [];
  bool _loading = true;
  final _buscaCtrl = TextEditingController();
  late TabController _tabCtrl;
  int _tab = 0; // 0=todos, 1=alertas, 2=esgotados

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {
          _tab = _tabCtrl.index;
          _filtrar();
        });
      }
    });
    _load();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = DbService();
    final produtos = await db.getProdutos(AppState().empresaId);
    if (mounted) {
      setState(() {
        _todos = produtos;
        _filtrar();
        _loading = false;
      });
    }
  }

  void _filtrar() {
    final busca = _buscaCtrl.text.toLowerCase();
    List<Produto> base;
    switch (_tab) {
      case 1:
        base = _todos.where((p) => p.estoqueAbaixoMinimo).toList();
        break;
      case 2:
        base = _todos.where((p) => p.esgotado).toList();
        break;
      default:
        base = _todos;
    }
    if (busca.isEmpty) {
      _filtrados = base;
    } else {
      _filtrados = base
          .where((p) =>
              p.nome.toLowerCase().contains(busca) ||
              p.codigoBarras.contains(busca) ||
              p.categoria.toLowerCase().contains(busca))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AppState().isAdmin;

    return Column(
      children: [
        // Header
        Container(
          color: AppColors.primaryDark,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'Estoque',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (isAdmin) ...[
                    IconButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProdutoFormPage()),
                        );
                        _load();
                      },
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.white),
                      tooltip: 'Novo produto',
                    ),
                  ],
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const MovimentacaoPage(tipo: TipoMovimentacao.entrada)),
                      );
                      _load();
                    },
                    icon: const Icon(Icons.add_box_outlined,
                        color: Colors.white),
                    tooltip: 'Entrada de mercadoria',
                  ),
                  IconButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const MovimentacaoPage(tipo: TipoMovimentacao.saida)),
                      );
                      _load();
                    },
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.white),
                    tooltip: 'Saída de mercadoria',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Busca
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _buscaCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Buscar produto, código...',
                    hintStyle: TextStyle(color: Colors.white54),
                    prefixIcon:
                        Icon(Icons.search, color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _filtrar()),
                ),
              ),
              const SizedBox(height: 12),
              // Tabs
              TabBar(
                controller: _tabCtrl,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: AppColors.accentGreen,
                tabs: [
                  Tab(text: 'Todos (${_todos.length})'),
                  Tab(
                      text:
                          'Baixo (${_todos.where((p) => p.estoqueAbaixoMinimo).length})'),
                  Tab(
                      text:
                          'Esgotado (${_todos.where((p) => p.esgotado).length})'),
                ],
              ),
            ],
          ),
        ),

        // Lista
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              size: 64, color: AppColors.muted.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          const Text(
                            'Nenhum produto encontrado',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const ProdutoFormPage()),
                                );
                                _load();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Adicionar produto'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                        itemCount: _filtrados.length,
                        itemBuilder: (ctx, i) {
                          final p = _filtrados[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ProdutoCard(
                              produto: p,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ProdutoDetalhePage(produto: p)),
                                );
                                _load();
                              },
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _ProdutoCard extends StatelessWidget {
  final Produto produto;
  final VoidCallback onTap;

  const _ProdutoCard({required this.produto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;

    if (produto.esgotado) {
      statusColor = AppColors.danger;
      statusLabel = 'ESGOTADO';
    } else if (produto.estoqueAbaixoMinimo) {
      statusColor = AppColors.warning;
      statusLabel = 'BAIXO';
    } else {
      statusColor = AppColors.success;
      statusLabel = 'OK';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 3),
              color: Color(0x0A000000),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ícone categoria
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produto.nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (produto.categoria.isNotEmpty)
                        Text(
                          produto.categoria,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12),
                        ),
                      if (produto.codigoBarras.isNotEmpty) ...[
                        const Text(' · ',
                            style: TextStyle(color: AppColors.muted)),
                        Text(
                          produto.codigoBarras,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatBRL(produto.precoVenda),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(label: statusLabel, color: statusColor),
                const SizedBox(height: 6),
                Text(
                  '${produto.qtdEstoque} ${produto.unidade}',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
