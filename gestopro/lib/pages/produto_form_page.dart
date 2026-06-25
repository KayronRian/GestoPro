import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/db_service.dart';
import '../utils/theme.dart';
import 'scanner_page.dart';

const _uuid = Uuid();

class ProdutoFormPage extends StatefulWidget {
  final Produto? produto;
  const ProdutoFormPage({super.key, this.produto});

  @override
  State<ProdutoFormPage> createState() => _ProdutoFormPageState();
}

class _ProdutoFormPageState extends State<ProdutoFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _codigoCtrl;
  late final TextEditingController _categoriaCtrl;
  late final TextEditingController _marcaCtrl;
  late final TextEditingController _fornecedorCtrl;
  late final TextEditingController _unidadeCtrl;
  late final TextEditingController _custoCtrl;
  late final TextEditingController _vendaCtrl;
  late final TextEditingController _estoqueCtrl;
  late final TextEditingController _minCtrl;
  DateTime? _validade;

  @override
  void initState() {
    super.initState();
    final p = widget.produto;
    _nomeCtrl = TextEditingController(text: p?.nome ?? '');
    _codigoCtrl = TextEditingController(text: p?.codigoBarras ?? '');
    _categoriaCtrl = TextEditingController(text: p?.categoria ?? '');
    _marcaCtrl = TextEditingController(text: p?.marca ?? '');
    _fornecedorCtrl = TextEditingController(text: p?.fornecedor ?? '');
    _unidadeCtrl = TextEditingController(text: p?.unidade ?? 'UN');
    _custoCtrl = TextEditingController(
        text: p != null ? p.precoCusto.toStringAsFixed(2) : '');
    _vendaCtrl = TextEditingController(
        text: p != null ? p.precoVenda.toStringAsFixed(2) : '');
    _estoqueCtrl = TextEditingController(
        text: p != null ? p.qtdEstoque.toString() : '0');
    _minCtrl = TextEditingController(
        text: p != null ? p.estoqueMinimo.toString() : '5');
    _validade = p?.dataValidade;
  }

  @override
  void dispose() {
    for (final c in [
      _nomeCtrl, _codigoCtrl, _categoriaCtrl, _marcaCtrl, _fornecedorCtrl,
      _unidadeCtrl, _custoCtrl, _vendaCtrl, _estoqueCtrl, _minCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final db = DbService();
      final state = AppState();
      final isEdit = widget.produto != null;

      final produto = Produto(
        id: widget.produto?.id ?? _uuid.v4(),
        empresaId: state.empresaId,
        nome: _nomeCtrl.text.trim(),
        codigoBarras: _codigoCtrl.text.trim(),
        categoria: _categoriaCtrl.text.trim(),
        marca: _marcaCtrl.text.trim(),
        fornecedor: _fornecedorCtrl.text.trim(),
        unidade: _unidadeCtrl.text.trim().isEmpty ? 'UN' : _unidadeCtrl.text.trim(),
        precoCusto: double.tryParse(_custoCtrl.text.replaceAll(',', '.')) ?? 0,
        precoVenda: double.tryParse(_vendaCtrl.text.replaceAll(',', '.')) ?? 0,
        qtdEstoque: int.tryParse(_estoqueCtrl.text) ?? 0,
        estoqueMinimo: int.tryParse(_minCtrl.text) ?? 5,
        dataValidade: _validade,
      );

      await db.saveProduto(produto);
      await db.addLog(
        empresaId: state.empresaId,
        usuarioNome: state.usuarioNome,
        acao: isEdit ? 'Produto editado' : 'Produto cadastrado',
        descricao:
            '${isEdit ? 'Produto editado' : 'Produto cadastrado'}: ${produto.nome}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? 'Produto atualizado com sucesso!'
                : 'Produto cadastrado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanCodigo() async {
    final codigo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (codigo != null && mounted) {
      setState(() => _codigoCtrl.text = codigo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.produto != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Produto' : 'Novo Produto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      title: 'Informações Básicas',
                      icon: Icons.info_outline,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _nomeCtrl,
                      label: 'Nome do produto *',
                      icon: Icons.inventory_2_outlined,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Obrigatório' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _codigoCtrl,
                            label: 'Código de barras',
                            icon: Icons.qr_code,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _scanCodigo,
                          icon: const Icon(Icons.camera_alt_outlined),
                          tooltip: 'Escanear código',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _categoriaCtrl,
                            label: 'Categoria',
                            icon: Icons.category_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _marcaCtrl,
                            label: 'Marca',
                            icon: Icons.label_outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller: _fornecedorCtrl,
                            label: 'Fornecedor',
                            icon: Icons.local_shipping_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _unidadeCtrl,
                            label: 'Unidade',
                            hint: 'UN, KG, L...',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      title: 'Preços',
                      icon: Icons.attach_money,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _custoCtrl,
                            label: 'Preço de custo',
                            hint: '0,00',
                            icon: Icons.money_off,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _vendaCtrl,
                            label: 'Preço de venda *',
                            hint: '0,00',
                            icon: Icons.sell_outlined,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (v) {
                              final val = double.tryParse(
                                  (v ?? '').replaceAll(',', '.'));
                              if (val == null || val <= 0) {
                                return 'Informe um preço válido';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      title: 'Estoque',
                      icon: Icons.inventory_2_outlined,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _estoqueCtrl,
                            label: 'Quantidade inicial',
                            icon: Icons.numbers,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _minCtrl,
                            label: 'Estoque mínimo',
                            icon: Icons.warning_amber_outlined,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _validade ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 3650)),
                        );
                        if (d != null) setState(() => _validade = d);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_outlined,
                                color: AppColors.muted),
                            const SizedBox(width: 12),
                            Text(
                              _validade != null
                                  ? 'Validade: ${formatDate(_validade!)}'
                                  : 'Data de validade (opcional)',
                              style: TextStyle(
                                color: _validade != null
                                    ? AppColors.text
                                    : AppColors.muted,
                              ),
                            ),
                            const Spacer(),
                            if (_validade != null)
                              GestureDetector(
                                onTap: () => setState(() => _validade = null),
                                child: const Icon(Icons.close,
                                    color: AppColors.muted, size: 18),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _salvar,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          isEdit ? 'Salvar alterações' : 'Cadastrar produto',
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
