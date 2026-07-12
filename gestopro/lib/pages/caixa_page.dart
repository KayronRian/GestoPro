import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/db_service.dart';
import '../utils/theme.dart';
import 'scanner_page.dart';

class CaixaPage extends StatefulWidget {
  const CaixaPage({super.key});

  @override
  State<CaixaPage> createState() => _CaixaPageState();
}

class _CaixaPageState extends State<CaixaPage> {
  List<Produto> _produtos = [];
  List<ItemCarrinho> _carrinho = [];
  List<Produto> _sugestoes = [];
  final _buscaCtrl = TextEditingController();
  bool _loading = true;
  int _view = 0; // 0=caixa, 1=carrinho, 2=pagamento

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prods = await DbService().getProdutos(AppState().empresaId);
    if (mounted) {
      setState(() {
        _produtos = prods.where((p) => !p.esgotado).toList();
        _loading = false;
      });
    }
  }

  void _buscar(String q) {
    if (q.isEmpty) {
      setState(() => _sugestoes = []);
      return;
    }
    setState(() {
      _sugestoes = _produtos
          .where(
            (p) =>
                p.nome.toLowerCase().contains(q.toLowerCase()) ||
                p.codigoBarras.contains(q),
          )
          .take(8)
          .toList();
    });
  }

  void _addProduto(Produto p) {
    setState(() {
      final idx = _carrinho.indexWhere((c) => c.produto.id == p.id);
      if (idx >= 0) {
        _carrinho[idx].quantidade++;
      } else {
        _carrinho.add(ItemCarrinho(produto: p));
      }
      _buscaCtrl.clear();
      _sugestoes = [];
    });
  }

  Future<void> _scanCodigo() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (codigo != null && mounted) {
      final p = await DbService().findProdutoPorCodigo(
        AppState().empresaId,
        codigo,
      );
      if (p != null) {
        _addProduto(p);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Produto com código "$codigo" não encontrado'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    }
  }

  double get _subtotal => _carrinho.fold(0.0, (s, c) => s + c.subtotal);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return IndexedStack(
      index: _view,
      children: [
        _CaixaView(
          produtos: _produtos,
          carrinho: _carrinho,
          buscaCtrl: _buscaCtrl,
          sugestoes: _sugestoes,
          onBusca: _buscar,
          onScan: _scanCodigo,
          onAdd: _addProduto,
          onCarrinho: () => setState(() => _view = 1),
          subtotal: _subtotal,
        ),
        _CarrinhoView(
          carrinho: _carrinho,
          onBack: () => setState(() => _view = 0),
          onPagar: () => setState(() => _view = 2),
          onUpdate: () => setState(() {}),
        ),
        _PagamentoView(
          carrinho: _carrinho,
          subtotal: _subtotal,
          onBack: () => setState(() => _view = 1),
          onFinalizar: (venda) {
            setState(() {
              _carrinho = [];
              _view = 0;
            });
            _load();
            _showSucesso(context, venda);
          },
        ),
      ],
    );
  }

  void _showSucesso(BuildContext context, Venda venda) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Venda Concluída!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ${formatBRL(venda.total)}'),
            Text('Pagamento: ${_formaPagLabel(venda.formaPagamento)}'),
            if (venda.formaPagamento == FormaPagamento.dinheiro)
              Text('Troco: ${formatBRL(venda.valorRecebido - venda.total)}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nova venda'),
          ),
        ],
      ),
    );
  }

  String _formaPagLabel(FormaPagamento f) {
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

// ─── Tela principal do caixa ─────────────────────────────────────────────────

class _CaixaView extends StatelessWidget {
  final List<Produto> produtos;
  final List<ItemCarrinho> carrinho;
  final TextEditingController buscaCtrl;
  final List<Produto> sugestoes;
  final ValueChanged<String> onBusca;
  final VoidCallback onScan;
  final ValueChanged<Produto> onAdd;
  final VoidCallback onCarrinho;
  final double subtotal;

  const _CaixaView({
    required this.produtos,
    required this.carrinho,
    required this.buscaCtrl,
    required this.sugestoes,
    required this.onBusca,
    required this.onScan,
    required this.onAdd,
    required this.onCarrinho,
    required this.subtotal,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.primaryDark,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Caixa / PDV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: onScan,
                      icon: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        onPressed: onCarrinho,
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                        ),
                      ),
                      if (carrinho.isNotEmpty)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: AppColors.accentGreen,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${carrinho.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: buscaCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Buscar produto ou código de barras...',
                    hintStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.search, color: Colors.white54),
                    border: InputBorder.none,
                  ),
                  onChanged: onBusca,
                ),
              ),
            ],
          ),
        ),
        if (sugestoes.isNotEmpty)
          Container(
            color: Colors.white,
            child: Column(
              children: sugestoes
                  .map(
                    (p) => ListTile(
                      title: Text(p.nome),
                      subtitle: Text(formatBRL(p.precoVenda)),
                      onTap: () => onAdd(p),
                    ),
                  )
                  .toList(),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                InkWell(
                  onTap: onScan,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 100,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'ESCANEAR PRODUTO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: carrinho.isEmpty
                      ? const Center(child: Text('Nenhum item adicionado'))
                      : ListView.builder(
                          itemCount: carrinho.length,
                          itemBuilder: (context, index) {
                            final item = carrinho[index];
                            return Card(
                              child: ListTile(
                                title: Text(item.produto.nome),
                                subtitle: Text(
                                  '${item.quantidade}x ${formatBRL(item.produto.precoVenda)}',
                                ),
                                trailing: Text(formatBRL(item.subtotal)),
                              ),
                            );
                          },
                        ),
                ),
                // Espaçamento para a barra inferior
                const SizedBox(height: 110),
              ],
            ),
          ),
        ),
        if (carrinho.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatBRL(subtotal),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onCarrinho,
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('Ver carrinho'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Tela do carrinho ─────────────────────────────────────────────────────────
class _CarrinhoView extends StatelessWidget {
  final List<ItemCarrinho> carrinho;
  final VoidCallback onBack;
  final VoidCallback onPagar;
  final VoidCallback onUpdate;

  const _CarrinhoView({
    required this.carrinho,
    required this.onBack,
    required this.onPagar,
    required this.onUpdate,
  });

  double get _subtotal => carrinho.fold(0.0, (s, c) => s + c.subtotal);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cabeçalho customizado (substituindo AppBar do Scaffold)
        Container(
          color: AppColors.primaryDark,
          padding: const EdgeInsets.fromLTRB(8, 24, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Text(
                'Carrinho',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: carrinho.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: AppColors.muted.withOpacity(0.4),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Carrinho vazio',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: onBack,
                        child: const Text('Adicionar produtos'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: carrinho.length,
                  itemBuilder: (ctx, i) {
                    final item = carrinho[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.inventory_2_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.produto.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    formatBRL(item.produto.precoVenda),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Controle de quantidade
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (item.quantidade > 1) {
                                      item.quantidade--;
                                    } else {
                                      carrinho.removeAt(i);
                                    }
                                    onUpdate();
                                  },
                                  icon: Icon(
                                    item.quantidade > 1
                                        ? Icons.remove_circle_outline
                                        : Icons.delete_outline,
                                    color: AppColors.danger,
                                  ),
                                  iconSize: 22,
                                ),
                                Text(
                                  '${item.quantidade}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    if (item.quantidade <
                                        item.produto.qtdEstoque) {
                                      item.quantidade++;
                                      onUpdate();
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: AppColors.success,
                                  ),
                                  iconSize: 22,
                                ),
                              ],
                            ),
                            Text(
                              formatBRL(item.subtotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // Resumo e botão pagar
        if (carrinho.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    Text(
                      formatBRL(_subtotal),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: onPagar,
                    icon: const Icon(Icons.payment_outlined),
                    label: Text(
                      'Ir para pagamento · ${formatBRL(_subtotal)}',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Tela de pagamento ────────────────────────────────────────────────────────
class _PagamentoView extends StatefulWidget {
  final List<ItemCarrinho> carrinho;
  final double subtotal;
  final VoidCallback onBack;
  final ValueChanged<Venda> onFinalizar;

  const _PagamentoView({
    required this.carrinho,
    required this.subtotal,
    required this.onBack,
    required this.onFinalizar,
  });

  @override
  State<_PagamentoView> createState() => _PagamentoViewState();
}

class _PagamentoViewState extends State<_PagamentoView> {
  FormaPagamento _forma = FormaPagamento.dinheiro;
  final _descontoCtrl = TextEditingController(text: '0');
  final _recebidoCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _descontoCtrl.dispose();
    _recebidoCtrl.dispose();
    super.dispose();
  }

  double get _desconto =>
      double.tryParse(_descontoCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _total => widget.subtotal * (1 - _desconto / 100);
  double get _troco {
    final rec = double.tryParse(_recebidoCtrl.text.replaceAll(',', '.')) ?? 0;
    return rec - _total;
  }

  Future<void> _finalizar() async {
    if (_total <= 0) return;
    if (_forma == FormaPagamento.dinheiro) {
      final rec = double.tryParse(_recebidoCtrl.text.replaceAll(',', '.')) ?? 0;
      if (rec < _total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Valor recebido é menor que o total'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      final state = AppState();
      final venda = await DbService().finalizarVenda(
        empresaId: state.empresaId,
        carrinho: widget.carrinho,
        desconto: _desconto,
        formaPagamento: _forma,
        valorRecebido:
            double.tryParse(_recebidoCtrl.text.replaceAll(',', '.')) ?? _total,
        usuarioNome: state.usuarioNome,
      );
      await DbService().addLog(
        empresaId: state.empresaId,
        usuarioNome: state.usuarioNome,
        acao: 'Venda realizada',
        descricao:
            'Venda de ${formatBRL(venda.total)} — ${widget.carrinho.length} itens',
      );
      if (mounted) widget.onFinalizar(venda);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cabeçalho customizado
        Container(
          color: AppColors.primaryDark,
          padding: const EdgeInsets.fromLTRB(8, 24, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Text(
                'Finalizar Venda',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Resumo
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        title: 'Resumo',
                        icon: Icons.receipt_long_outlined,
                      ),
                      const SizedBox(height: 12),
                      ...widget.carrinho.map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${c.quantidade}x ${c.produto.nome}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                formatBRL(c.subtotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          Text(
                            formatBRL(widget.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Desconto
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        title: 'Desconto',
                        icon: Icons.discount_outlined,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _descontoCtrl,
                        label: 'Desconto (%)',
                        hint: '0',
                        icon: Icons.percent,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        suffix: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            '%',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder(
                        valueListenable: _descontoCtrl,
                        builder: (_, __, ___) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total com desconto:',
                              style: TextStyle(color: AppColors.muted),
                            ),
                            Text(
                              formatBRL(_total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Forma de pagamento
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        title: 'Forma de Pagamento',
                        icon: Icons.payment_outlined,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: FormaPagamento.values.map((f) {
                          final selected = _forma == f;
                          return ChoiceChip(
                            label: Text(_formaNome(f)),
                            selected: selected,
                            onSelected: (_) => setState(() => _forma = f),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: selected ? Colors.white : AppColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                            avatar: Icon(
                              _formaIcon(f),
                              color: selected ? Colors.white : AppColors.muted,
                              size: 18,
                            ),
                          );
                        }).toList(),
                      ),
                      if (_forma == FormaPagamento.dinheiro) ...[
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _recebidoCtrl,
                          label: 'Valor recebido',
                          hint: '0,00',
                          icon: Icons.attach_money,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder(
                          valueListenable: _recebidoCtrl,
                          builder: (_, __, ___) {
                            final troco = _troco;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Troco:',
                                  style: TextStyle(color: AppColors.muted),
                                ),
                                Text(
                                  formatBRL(troco > 0 ? troco : 0),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: troco >= 0
                                        ? AppColors.success
                                        : AppColors.danger,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _finalizar,
                    icon: const Icon(Icons.check_circle_outline),
                    label: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'Confirmar venda · ${formatBRL(_total)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentGreen,
                    ),
                  ),
                ),
                // Espaçamento para a barra inferior
                const SizedBox(height: 110),
              ],
            ),
          ),
        ),
      ],
    );
  }

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

  IconData _formaIcon(FormaPagamento f) {
    switch (f) {
      case FormaPagamento.dinheiro:
        return Icons.attach_money;
      case FormaPagamento.pix:
        return Icons.qr_code_2;
      case FormaPagamento.debito:
        return Icons.credit_card;
      case FormaPagamento.credito:
        return Icons.credit_card_outlined;
      case FormaPagamento.misto:
        return Icons.compare_arrows;
    }
  }
}
