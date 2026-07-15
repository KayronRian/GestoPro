import 'dart:convert';

// ─── Empresa ────────────────────────────────────────────────────────────────
// Modelo de domínio para dados cadastrais da empresa.
class Empresa {
  final String id;
  String nome;
  String cnpj;
  String telefone;
  String email;
  String endereco;
  String cidade;
  String estado;

  Empresa({
    required this.id,
    required this.nome,
    this.cnpj = '',
    this.telefone = '',
    this.email = '',
    this.endereco = '',
    this.cidade = '',
    this.estado = '',
  });

  // toMap serializa o objeto para persistência/transferência (chaves estáveis).
  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'cnpj': cnpj,
        'telefone': telefone,
        'email': email,
        'endereco': endereco,
        'cidade': cidade,
        'estado': estado,
      };

  // fromMap reconstrói a Empresa; usa valores padrão para campos ausentes.
  factory Empresa.fromMap(Map<String, dynamic> m) => Empresa(
        id: m['id'],
        nome: m['nome'],
        cnpj: m['cnpj'] ?? '',
        telefone: m['telefone'] ?? '',
        email: m['email'] ?? '',
        endereco: m['endereco'] ?? '',
        cidade: m['cidade'] ?? '',
        estado: m['estado'] ?? '',
      );

  String toJson() => jsonEncode(toMap());
  factory Empresa.fromJson(String s) => Empresa.fromMap(jsonDecode(s));
}

// ─── Usuário ─────────────────────────────────────────────────────────────────
// Enum de perfis para controle de permissões e visibilidade no sistema.
enum UserRole { admin, funcionario }

// Entidade de usuário com identidade, credenciais e status de acesso.
class Usuario {
  final String id;
  String empresaId;
  String nome;
  String email;
  String senhaHash;
  UserRole role;
  bool ativo;
  DateTime? ultimoAcesso;

  Usuario({
    required this.id,
    required this.empresaId,
    required this.nome,
    required this.email,
    required this.senhaHash,
    this.role = UserRole.funcionario,
    this.ativo = true,
    this.ultimoAcesso,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'empresaId': empresaId,
        'nome': nome,
        'email': email,
        'senhaHash': senhaHash,
        'role': role.name,
        'ativo': ativo,
        'ultimoAcesso': ultimoAcesso?.toIso8601String(),
      };

  // fromMap recria o usuário e garante role válido e data parseada com segurança.
  factory Usuario.fromMap(Map<String, dynamic> m) => Usuario(
        id: m['id'],
        empresaId: m['empresaId'],
        nome: m['nome'],
        email: m['email'],
        senhaHash: m['senhaHash'],
        role: UserRole.values.firstWhere((e) => e.name == m['role'],
            orElse: () => UserRole.funcionario),
        ativo: m['ativo'] ?? true,
        ultimoAcesso: m['ultimoAcesso'] != null
            ? DateTime.tryParse(m['ultimoAcesso'])
            : null,
      );

  String toJson() => jsonEncode(toMap());
  factory Usuario.fromJson(String s) => Usuario.fromMap(jsonDecode(s));
}

// ─── Produto ─────────────────────────────────────────────────────────────────
// Entidade principal de estoque: atributos comerciais e de inventário.
class Produto {
  final String id;
  String empresaId;
  String nome;
  String codigoBarras;
  String categoria;
  String marca;
  String fornecedor;
  String unidade;
  double precoCusto;
  double precoVenda;
  int qtdEstoque;
  int estoqueMinimo;
  DateTime? dataValidade;
  bool ativo;

  Produto({
    required this.id,
    required this.empresaId,
    required this.nome,
    this.codigoBarras = '',
    this.categoria = '',
    this.marca = '',
    this.fornecedor = '',
    this.unidade = 'UN',
    this.precoCusto = 0,
    this.precoVenda = 0,
    this.qtdEstoque = 0,
    this.estoqueMinimo = 5,
    this.dataValidade,
    this.ativo = true,
  });

  // Calcula margem percentual considerando custo e preço de venda.
  double get margem =>
      precoVenda > 0 ? ((precoVenda - precoCusto) / precoVenda * 100) : 0;

  // Sinaliza baixo estoque: <= mínimo, mas ainda disponível.
  bool get estoqueAbaixoMinimo => qtdEstoque <= estoqueMinimo && qtdEstoque > 0;
  bool get esgotado => qtdEstoque == 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'empresaId': empresaId,
        'nome': nome,
        'codigoBarras': codigoBarras,
        'categoria': categoria,
        'marca': marca,
        'fornecedor': fornecedor,
        'unidade': unidade,
        'precoCusto': precoCusto,
        'precoVenda': precoVenda,
        'qtdEstoque': qtdEstoque,
        'estoqueMinimo': estoqueMinimo,
        'dataValidade': dataValidade?.toIso8601String(),
        'ativo': ativo,
      };

  // fromMap normaliza tipos numéricos/datas e aplica defaults de campos.
  factory Produto.fromMap(Map<String, dynamic> m) => Produto(
        id: m['id'],
        empresaId: m['empresaId'],
        nome: m['nome'],
        codigoBarras: m['codigoBarras'] ?? '',
        categoria: m['categoria'] ?? '',
        marca: m['marca'] ?? '',
        fornecedor: m['fornecedor'] ?? '',
        unidade: m['unidade'] ?? 'UN',
        precoCusto: (m['precoCusto'] as num?)?.toDouble() ?? 0,
        precoVenda: (m['precoVenda'] as num?)?.toDouble() ?? 0,
        qtdEstoque: m['qtdEstoque'] ?? 0,
        estoqueMinimo: m['estoqueMinimo'] ?? 5,
        dataValidade: m['dataValidade'] != null
            ? DateTime.tryParse(m['dataValidade'])
            : null,
        ativo: m['ativo'] ?? true,
      );

  String toJson() => jsonEncode(toMap());
  factory Produto.fromJson(String s) => Produto.fromMap(jsonDecode(s));
}

// ─── Movimentação de Estoque ──────────────────────────────────────────────────
// Tipos de movimentação que impactam o saldo do estoque.
enum TipoMovimentacao { entrada, saida, ajuste }

// Registro de movimentação com contexto (origem, usuário, data).
class Movimentacao {
  final String id;
  String empresaId;
  String produtoId;
  String produtoNome;
  TipoMovimentacao tipo;
  int quantidade;
  String? notaFiscal;
  String? fornecedor;
  double? precoCusto;
  String? motivo;
  String? observacoes;
  String usuarioNome;
  DateTime data;

  Movimentacao({
    required this.id,
    required this.empresaId,
    required this.produtoId,
    required this.produtoNome,
    required this.tipo,
    required this.quantidade,
    this.notaFiscal,
    this.fornecedor,
    this.precoCusto,
    this.motivo,
    this.observacoes,
    required this.usuarioNome,
    required this.data,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'empresaId': empresaId,
        'produtoId': produtoId,
        'produtoNome': produtoNome,
        'tipo': tipo.name,
        'quantidade': quantidade,
        'notaFiscal': notaFiscal,
        'fornecedor': fornecedor,
        'precoCusto': precoCusto,
        'motivo': motivo,
        'observacoes': observacoes,
        'usuarioNome': usuarioNome,
        'data': data.toIso8601String(),
      };

  // fromMap traduz strings para enum e reconstrói metadados da movimentação.
  factory Movimentacao.fromMap(Map<String, dynamic> m) => Movimentacao(
        id: m['id'],
        empresaId: m['empresaId'],
        produtoId: m['produtoId'],
        produtoNome: m['produtoNome'],
        tipo: TipoMovimentacao.values.firstWhere((e) => e.name == m['tipo'],
            orElse: () => TipoMovimentacao.entrada),
        quantidade: m['quantidade'],
        notaFiscal: m['notaFiscal'],
        fornecedor: m['fornecedor'],
        precoCusto: (m['precoCusto'] as num?)?.toDouble(),
        motivo: m['motivo'],
        observacoes: m['observacoes'],
        usuarioNome: m['usuarioNome'],
        data: DateTime.parse(m['data']),
      );

  String toJson() => jsonEncode(toMap());
  factory Movimentacao.fromJson(String s) => Movimentacao.fromMap(jsonDecode(s));
}

// ─── Item do Carrinho ─────────────────────────────────────────────────────────
class ItemCarrinho {
  final Produto produto;
  int quantidade;

  ItemCarrinho({required this.produto, this.quantidade = 1});

  // Regra de negócio do carrinho: subtotal do item = preço x quantidade.
  double get subtotal => produto.precoVenda * quantidade;
}

// ─── Venda ────────────────────────────────────────────────────────────────────
// Enum das formas de pagamento aceitas no PDV.
enum FormaPagamento { dinheiro, pix, debito, credito, misto }

// Agregado Venda: itens vendidos, totais, pagamento e autor da operação.
class Venda {
  final String id;
  String empresaId;
  List<ItemVenda> itens;
  double subtotal;
  double desconto;
  double total;
  FormaPagamento formaPagamento;
  double valorRecebido;
  String usuarioNome;
  DateTime data;

  Venda({
    required this.id,
    required this.empresaId,
    required this.itens,
    required this.subtotal,
    required this.desconto,
    required this.total,
    required this.formaPagamento,
    required this.valorRecebido,
    required this.usuarioNome,
    required this.data,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'empresaId': empresaId,
        'itens': itens.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'desconto': desconto,
        'total': total,
        'formaPagamento': formaPagamento.name,
        'valorRecebido': valorRecebido,
        'usuarioNome': usuarioNome,
        'data': data.toIso8601String(),
      };

  // fromMap reidrata a venda, convertendo lista de itens e enum de pagamento.
  factory Venda.fromMap(Map<String, dynamic> m) => Venda(
        id: m['id'],
        empresaId: m['empresaId'],
        itens: (m['itens'] as List).map((i) => ItemVenda.fromMap(i)).toList(),
        subtotal: (m['subtotal'] as num).toDouble(),
        desconto: (m['desconto'] as num).toDouble(),
        total: (m['total'] as num).toDouble(),
        formaPagamento: FormaPagamento.values.firstWhere(
            (e) => e.name == m['formaPagamento'],
            orElse: () => FormaPagamento.dinheiro),
        valorRecebido: (m['valorRecebido'] as num).toDouble(),
        usuarioNome: m['usuarioNome'],
        data: DateTime.parse(m['data']),
      );

  String toJson() => jsonEncode(toMap());
  factory Venda.fromJson(String s) => Venda.fromMap(jsonDecode(s));
}

// Item desnormalizado da venda, persistido junto ao cabeçalho.
class ItemVenda {
  String produtoId;
  String produtoNome;
  int quantidade;
  double precoUnitario;

  ItemVenda({
    required this.produtoId,
    required this.produtoNome,
    required this.quantidade,
    required this.precoUnitario,
  });

  double get subtotal => precoUnitario * quantidade;

  Map<String, dynamic> toMap() => {
        'produtoId': produtoId,
        'produtoNome': produtoNome,
        'quantidade': quantidade,
        'precoUnitario': precoUnitario,
      };

  factory ItemVenda.fromMap(Map<String, dynamic> m) => ItemVenda(
        produtoId: m['produtoId'],
        produtoNome: m['produtoNome'],
        quantidade: m['quantidade'],
        precoUnitario: (m['precoUnitario'] as num).toDouble(),
      );
}

// ─── Log de Auditoria ─────────────────────────────────────────────────────────
// Entidade de auditoria para rastrear ações e cumprir conformidade.
class LogAuditoria {
  final String id;
  String empresaId;
  String usuarioNome;
  String acao;
  String descricao;
  DateTime data;

  LogAuditoria({
    required this.id,
    required this.empresaId,
    required this.usuarioNome,
    required this.acao,
    required this.descricao,
    required this.data,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'empresaId': empresaId,
        'usuarioNome': usuarioNome,
        'acao': acao,
        'descricao': descricao,
        'data': data.toIso8601String(),
      };

  factory LogAuditoria.fromMap(Map<String, dynamic> m) => LogAuditoria(
        id: m['id'],
        empresaId: m['empresaId'],
        usuarioNome: m['usuarioNome'],
        acao: m['acao'],
        descricao: m['descricao'],
        data: DateTime.parse(m['data']),
      );

  String toJson() => jsonEncode(toMap());
  factory LogAuditoria.fromJson(String s) => LogAuditoria.fromMap(jsonDecode(s));
}
