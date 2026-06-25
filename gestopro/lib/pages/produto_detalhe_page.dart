import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/db_service.dart';
import '../utils/theme.dart';
import 'produto_form_page.dart';
import 'movimentacao_page.dart';

class ProdutoDetalhePage extends StatefulWidget {
  final Produto produto;
  const ProdutoDetalhePage({super.key, required this.produto});

  @override
  State<ProdutoDetalhePage> createState() => _ProdutoDetalhePageState();
}

class _ProdutoDetalhePageState extends State<ProdutoDetalhePage> {
  late Produto _produto;
  List<Movimentacao> _movs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _produto = widget.produto;
    _load();
  }

  Future<void> _load() async {
    final db = DbService();
    final movs = await db.getMovimentacoesPorProduto(
        AppState().empresaId, _produto.id);
    final prodAtual = await db.getProdutos(AppState().empresaId);
    final p = prodAtual.where((x) => x.id == _produto.id).firstOrNull;
    if (mounted) {
      setState(() {
        if (p != null) _produto = p;
        _movs = movs;
        _loading = false;
      });
    }
  }

  Future<void> _deletar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir produto'),
        content: Text('Deseja excluir "${_produto.nome}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await DbService().deleteProduto(AppState().empresaId, _produto.id);
      await DbService().addLog(
        empresaId: AppState().empresaId,
        usuarioNome: AppState().usuarioNome,
        acao: 'Produto excluído',
        descricao: 'Produto "${_produto.nome}" excluído',
      );
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = AppState().isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: Text(_produto.nome),
        actions: [
          if (isAdmin) ...[
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProdutoFormPage(produto: _produto)),
                );
                _load();
              },
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
            ),
            IconButton(
              onPressed: _deletar,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Excluir',
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              child: Column(
                children: [
                  // Card principal
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.inventory_2_rounded,
                                  color: AppColors.primary, size: 30),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _produto.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  if (_produto.marca.isNotEmpty)
                                    Text(
                                      _produto.marca,
                                      style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 13),
                                    ),
                                ],
                              ),
                            ),
                            _StatusChip(produto: _produto),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        _InfoRow(
                            label: 'Código de barras',
                            value: _produto.codigoBarras.isEmpty
                                ? '—'
                                : _produto.codigoBarras,
                            icon: Icons.qr_code),
                        _InfoRow(
                            label: 'Categoria',
                            value: _produto.categoria.isEmpty
                                ? '—'
                                : _produto.categoria,
                            icon: Icons.category_outlined),
                        _InfoRow(
                            label: 'Fornecedor',
                            value: _produto.fornecedor.isEmpty
                                ? '—'
                                : _produto.fornecedor,
                            icon: Icons.local_shipping_outlined),
                        _InfoRow(
                            label: 'Unidade',
                            value: _produto.unidade,
                            icon: Icons.straighten),
                        if (_produto.dataValidade != null)
                          _InfoRow(
                              label: 'Validade',
                              value: formatDate(_produto.dataValidade!),
                              icon: Icons.event_outlined),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Preços e estoque
                  Row(
                    children: [
                      Expanded(
                        child: _PriceCard(
                          label: 'Preço de Custo',
                          value: formatBRL(_produto.precoCusto),
                          color: const Color(0xFFF0E8FF),
                          iconColor: const Color(0xFF8C5DE8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PriceCard(
                          label: 'Preço de Venda',
                          value: formatBRL(_produto.precoVenda),
                          color: const Color(0xFFE7FAF3),
                          iconColor: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PriceCard(
                          label: 'Margem',
                          value: '${_produto.margem.toStringAsFixed(1)}%',
                          color: const Color(0xFFF2F5FB),
                          iconColor: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PriceCard(
                          label: 'Estoque Atual',
                          value: '${_produto.qtdEstoque} ${_produto.unidade}',
                          color: _produto.esgotado
                              ? const Color(0xFFFDEEEE)
                              : _produto.estoqueAbaixoMinimo
                                  ? const Color(0xFFFFF5E8)
                                  : const Color(0xFFE7FAF3),
                          iconColor: _produto.esgotado
                              ? AppColors.danger
                              : _produto.estoqueAbaixoMinimo
                                  ? AppColors.warning
                                  : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Botões de ação
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MovimentacaoPage(
                                        tipo: TipoMovimentacao.entrada,
                                        produtoInicial: _produto,
                                      )),
                            );
                            _load();
                          },
                          icon: const Icon(Icons.add_box_outlined,
                              color: AppColors.success),
                          label: const Text('Entrada',
                              style: TextStyle(color: AppColors.success)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.success),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MovimentacaoPage(
                                        tipo: TipoMovimentacao.saida,
                                        produtoInicial: _produto,
                                      )),
                            );
                            _load();
                          },
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppColors.danger),
                          label: const Text('Saída',
                              style: TextStyle(color: AppColors.danger)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.danger),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Histórico
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionTitle(
                          title: 'Histórico de Movimentações',
                          icon: Icons.history,
                        ),
                        const SizedBox(height: 12),
                        if (_movs.isEmpty)
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
                          ..._movs.take(20).map((m) => _MovRow(mov: m)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Produto produto;
  const _StatusChip({required this.produto});

  @override
  Widget build(BuildContext context) {
    if (produto.esgotado) {
      return const StatusBadge(label: 'ESGOTADO', color: AppColors.danger);
    } else if (produto.estoqueAbaixoMinimo) {
      return const StatusBadge(label: 'BAIXO', color: AppColors.warning);
    }
    return const StatusBadge(label: 'OK', color: AppColors.success);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color iconColor;

  const _PriceCard({
    required this.label,
    required this.value,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: iconColor.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: iconColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovRow extends StatelessWidget {
  final Movimentacao mov;
  const _MovRow({required this.mov});

  @override
  Widget build(BuildContext context) {
    final isEntrada = mov.tipo == TipoMovimentacao.entrada;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isEntrada
                  ? AppColors.success.withOpacity(0.12)
                  : AppColors.danger.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEntrada ? Icons.add : Icons.remove,
              color: isEntrada ? AppColors.success : AppColors.danger,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEntrada ? 'Entrada' : 'Saída',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  mov.motivo ?? mov.fornecedor ?? mov.usuarioNome,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isEntrada ? '+' : '-'}${mov.quantidade}',
                style: TextStyle(
                  color: isEntrada ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                formatDate(mov.data),
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
