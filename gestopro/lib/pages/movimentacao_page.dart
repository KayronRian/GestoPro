import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/db_service.dart';
import '../utils/theme.dart';
import 'scanner_page.dart';

class MovimentacaoPage extends StatefulWidget {
  final TipoMovimentacao tipo;
  final Produto? produtoInicial;

  const MovimentacaoPage({
    super.key,
    required this.tipo,
    this.produtoInicial,
  });

  @override
  State<MovimentacaoPage> createState() => _MovimentacaoPageState();
}

class _MovimentacaoPageState extends State<MovimentacaoPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  Produto? _produto;
  List<Produto> _produtos = [];

  final _qtdCtrl = TextEditingController(text: '1');
  final _nfCtrl = TextEditingController();
  final _fornecedorCtrl = TextEditingController();
  final _custoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  final _buscaCtrl = TextEditingController();

  List<Produto> _sugestoes = [];

  @override
  void initState() {
    super.initState();
    _produto = widget.produtoInicial;
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _qtdCtrl, _nfCtrl, _fornecedorCtrl, _custoCtrl,
      _motivoCtrl, _obsCtrl, _buscaCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final prods = await DbService().getProdutos(AppState().empresaId);
    if (mounted) setState(() => _produtos = prods);
  }

  void _buscar(String q) {
    if (q.isEmpty) {
      setState(() => _sugestoes = []);
      return;
    }
    setState(() {
      _sugestoes = _produtos
          .where((p) =>
              p.nome.toLowerCase().contains(q.toLowerCase()) ||
              p.codigoBarras.contains(q))
          .take(6)
          .toList();
    });
  }

  Future<void> _scanCodigo() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (codigo != null && mounted) {
      final p = await DbService()
          .findProdutoPorCodigo(AppState().empresaId, codigo);
      if (p != null) {
        setState(() {
          _produto = p;
          _showBusca = false;
        });
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

  Future<void> _salvar() async {
    if (_produto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um produto'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final db = DbService();
      final state = AppState();
      final qtd = int.tryParse(_qtdCtrl.text) ?? 0;

      if (qtd <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quantidade deve ser maior que zero'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      bool ok = true;
      if (widget.tipo == TipoMovimentacao.entrada) {
        await db.registrarEntrada(
          empresaId: state.empresaId,
          produto: _produto!,
          quantidade: qtd,
          notaFiscal: _nfCtrl.text.trim().isEmpty ? null : _nfCtrl.text.trim(),
          fornecedor: _fornecedorCtrl.text.trim().isEmpty
              ? null
              : _fornecedorCtrl.text.trim(),
          precoCusto: double.tryParse(
              _custoCtrl.text.replaceAll(',', '.')),
          observacoes:
              _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
          usuarioNome: state.usuarioNome,
        );
      } else {
        ok = await db.registrarSaida(
          empresaId: state.empresaId,
          produto: _produto!,
          quantidade: qtd,
          motivo: _motivoCtrl.text.trim().isEmpty
              ? null
              : _motivoCtrl.text.trim(),
          observacoes:
              _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
          usuarioNome: state.usuarioNome,
        );
      }

      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Estoque insuficiente para esta saída'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      await db.addLog(
        empresaId: state.empresaId,
        usuarioNome: state.usuarioNome,
        acao: widget.tipo == TipoMovimentacao.entrada
            ? 'Entrada de estoque'
            : 'Saída de estoque',
        descricao:
            '${widget.tipo == TipoMovimentacao.entrada ? 'Entrada' : 'Saída'} de $qtd ${_produto!.unidade} de "${_produto!.nome}"',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.tipo == TipoMovimentacao.entrada
                  ? 'Entrada registrada com sucesso!'
                  : 'Saída registrada com sucesso!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEntrada = widget.tipo == TipoMovimentacao.entrada;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEntrada ? 'Entrada de Mercadoria' : 'Saída de Mercadoria'),
        backgroundColor:
            isEntrada ? AppColors.primaryDark : const Color(0xFFB03030),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Seleção de produto
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      title: 'Produto',
                      icon: Icons.inventory_2_outlined,
                      trailing: IconButton(
                        onPressed: _scanCodigo,
                        icon: const Icon(Icons.camera_alt_outlined,
                            color: AppColors.primary),
                        tooltip: 'Escanear código de barras',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_produto != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isEntrada
                              ? const Color(0xFFE7FAF3)
                              : const Color(0xFFFDEEEE),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _produto!.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  Text(
                                    'Estoque atual: ${_produto!.qtdEstoque} ${_produto!.unidade}',
                                    style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _produto = null;
                                _showBusca = true;
                              }),
                              child: const Text('Trocar'),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      TextField(
                        controller: _buscaCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Buscar produto por nome ou código...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: _buscar,
                      ),
                      if (_sugestoes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.cardBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: _sugestoes
                                .map((p) => ListTile(
                                      title: Text(p.nome),
                                      subtitle: Text(
                                          '${p.qtdEstoque} ${p.unidade} · ${formatBRL(p.precoVenda)}'),
                                      onTap: () {
                                        setState(() {
                                          _produto = p;
                                          _buscaCtrl.clear();
                                          _sugestoes = [];
                                          _showBusca = false;
                                        });
                                      },
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Quantidade
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                        title: 'Quantidade', icon: Icons.numbers),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _qtdCtrl,
                      label: 'Quantidade *',
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Informe uma quantidade válida';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Campos específicos por tipo
              if (isEntrada) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                          title: 'Dados da Entrada',
                          icon: Icons.receipt_long_outlined),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _nfCtrl,
                        label: 'Nota Fiscal (opcional)',
                        icon: Icons.receipt_outlined,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _fornecedorCtrl,
                        label: 'Fornecedor (opcional)',
                        icon: Icons.local_shipping_outlined,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _custoCtrl,
                        label: 'Preço de custo (opcional)',
                        hint: '0,00',
                        icon: Icons.attach_money,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                          title: 'Dados da Saída',
                          icon: Icons.info_outline),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _motivoCtrl,
                        label: 'Motivo (opcional)',
                        icon: Icons.edit_note_outlined,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              AppCard(
                child: AppTextField(
                  controller: _obsCtrl,
                  label: 'Observações (opcional)',
                  icon: Icons.notes_outlined,
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _salvar,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isEntrada ? AppColors.success : AppColors.danger,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          isEntrada
                              ? 'Registrar Entrada'
                              : 'Registrar Saída',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
