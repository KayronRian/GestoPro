import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

const _uuid = Uuid();

String hashSenha(String senha) =>
    sha256.convert(utf8.encode(senha)).toString();

class DbService {
  static final DbService _instance = DbService._();
  factory DbService() => _instance;
  DbService._();

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // ─── Empresa ────────────────────────────────────────────────────────────────
  Future<Empresa?> getEmpresa(String id) async {
    final s = _prefs.getString('empresa_$id');
    if (s == null) return null;
    return Empresa.fromJson(s);
  }

  Future<void> saveEmpresa(Empresa e) async {
    await _prefs.setString('empresa_${e.id}', e.toJson());
  }

  // ─── Usuários ────────────────────────────────────────────────────────────────
  Future<List<Usuario>> getUsuarios(String empresaId) async {
    final ids = _prefs.getStringList('usuarios_$empresaId') ?? [];
    final result = <Usuario>[];
    for (final id in ids) {
      final s = _prefs.getString('usuario_$id');
      if (s != null) result.add(Usuario.fromJson(s));
    }
    return result;
  }

  Future<void> saveUsuario(Usuario u) async {
    await _prefs.setString('usuario_${u.id}', u.toJson());
    final ids = _prefs.getStringList('usuarios_${u.empresaId}') ?? [];
    if (!ids.contains(u.id)) {
      ids.add(u.id);
      await _prefs.setStringList('usuarios_${u.empresaId}', ids);
    }
  }

  Future<void> deleteUsuario(String empresaId, String userId) async {
    await _prefs.remove('usuario_$userId');
    final ids = _prefs.getStringList('usuarios_$empresaId') ?? [];
    ids.remove(userId);
    await _prefs.setStringList('usuarios_$empresaId', ids);
  }

  Future<Usuario?> findUsuarioByEmail(String email) async {
    final allKeys = _prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('usuario_')) {
        final s = _prefs.getString(key);
        if (s != null) {
          final u = Usuario.fromJson(s);
          if (u.email.toLowerCase() == email.toLowerCase()) return u;
        }
      }
    }
    return null;
  }

  Future<Usuario?> login(String email, String senha) async {
    final u = await findUsuarioByEmail(email);
    if (u == null || !u.ativo) return null;
    if (u.senhaHash != hashSenha(senha)) return null;
    u.ultimoAcesso = DateTime.now();
    await saveUsuario(u);
    return u;
  }

  // ─── Produtos ────────────────────────────────────────────────────────────────
  Future<List<Produto>> getProdutos(String empresaId) async {
    final ids = _prefs.getStringList('produtos_$empresaId') ?? [];
    final result = <Produto>[];
    for (final id in ids) {
      final s = _prefs.getString('produto_$id');
      if (s != null) result.add(Produto.fromJson(s));
    }
    return result;
  }

  Future<void> saveProduto(Produto p) async {
    await _prefs.setString('produto_${p.id}', p.toJson());
    final ids = _prefs.getStringList('produtos_${p.empresaId}') ?? [];
    if (!ids.contains(p.id)) {
      ids.add(p.id);
      await _prefs.setStringList('produtos_${p.empresaId}', ids);
    }
  }

  Future<void> deleteProduto(String empresaId, String produtoId) async {
    await _prefs.remove('produto_$produtoId');
    final ids = _prefs.getStringList('produtos_$empresaId') ?? [];
    ids.remove(produtoId);
    await _prefs.setStringList('produtos_$empresaId', ids);
  }

  Future<Produto?> findProdutoPorCodigo(
      String empresaId, String codigo) async {
    final produtos = await getProdutos(empresaId);
    try {
      return produtos.firstWhere((p) => p.codigoBarras == codigo);
    } catch (_) {
      return null;
    }
  }

  // ─── Movimentações ───────────────────────────────────────────────────────────
  Future<List<Movimentacao>> getMovimentacoes(String empresaId) async {
    final ids = _prefs.getStringList('movs_$empresaId') ?? [];
    final result = <Movimentacao>[];
    for (final id in ids) {
      final s = _prefs.getString('mov_$id');
      if (s != null) result.add(Movimentacao.fromJson(s));
    }
    result.sort((a, b) => b.data.compareTo(a.data));
    return result;
  }

  Future<List<Movimentacao>> getMovimentacoesPorProduto(
      String empresaId, String produtoId) async {
    final all = await getMovimentacoes(empresaId);
    return all.where((m) => m.produtoId == produtoId).toList();
  }

  Future<void> saveMovimentacao(Movimentacao m) async {
    await _prefs.setString('mov_${m.id}', m.toJson());
    final ids = _prefs.getStringList('movs_${m.empresaId}') ?? [];
    if (!ids.contains(m.id)) {
      ids.add(m.id);
      await _prefs.setStringList('movs_${m.empresaId}', ids);
    }
  }

  Future<void> registrarEntrada({
    required String empresaId,
    required Produto produto,
    required int quantidade,
    String? notaFiscal,
    String? fornecedor,
    double? precoCusto,
    String? observacoes,
    required String usuarioNome,
  }) async {
    produto.qtdEstoque += quantidade;
    if (precoCusto != null && precoCusto > 0) {
      produto.precoCusto = precoCusto;
    }
    await saveProduto(produto);
    final mov = Movimentacao(
      id: _uuid.v4(),
      empresaId: empresaId,
      produtoId: produto.id,
      produtoNome: produto.nome,
      tipo: TipoMovimentacao.entrada,
      quantidade: quantidade,
      notaFiscal: notaFiscal,
      fornecedor: fornecedor,
      precoCusto: precoCusto,
      observacoes: observacoes,
      usuarioNome: usuarioNome,
      data: DateTime.now(),
    );
    await saveMovimentacao(mov);
  }

  Future<bool> registrarSaida({
    required String empresaId,
    required Produto produto,
    required int quantidade,
    String? motivo,
    String? observacoes,
    required String usuarioNome,
  }) async {
    if (produto.qtdEstoque < quantidade) return false;
    produto.qtdEstoque -= quantidade;
    await saveProduto(produto);
    final mov = Movimentacao(
      id: _uuid.v4(),
      empresaId: empresaId,
      produtoId: produto.id,
      produtoNome: produto.nome,
      tipo: TipoMovimentacao.saida,
      quantidade: quantidade,
      motivo: motivo,
      observacoes: observacoes,
      usuarioNome: usuarioNome,
      data: DateTime.now(),
    );
    await saveMovimentacao(mov);
    return true;
  }

  // ─── Vendas ──────────────────────────────────────────────────────────────────
  Future<List<Venda>> getVendas(String empresaId) async {
    final ids = _prefs.getStringList('vendas_$empresaId') ?? [];
    final result = <Venda>[];
    for (final id in ids) {
      final s = _prefs.getString('venda_$id');
      if (s != null) result.add(Venda.fromJson(s));
    }
    result.sort((a, b) => b.data.compareTo(a.data));
    return result;
  }

  Future<void> saveVenda(Venda v) async {
    await _prefs.setString('venda_${v.id}', v.toJson());
    final ids = _prefs.getStringList('vendas_${v.empresaId}') ?? [];
    if (!ids.contains(v.id)) {
      ids.add(v.id);
      await _prefs.setStringList('vendas_${v.empresaId}', ids);
    }
  }

  Future<Venda> finalizarVenda({
    required String empresaId,
    required List<ItemCarrinho> carrinho,
    required double desconto,
    required FormaPagamento formaPagamento,
    required double valorRecebido,
    required String usuarioNome,
  }) async {
    final subtotal = carrinho.fold(0.0, (s, i) => s + i.subtotal);
    final total = subtotal * (1 - desconto / 100);
    final itens = carrinho
        .map((c) => ItemVenda(
              produtoId: c.produto.id,
              produtoNome: c.produto.nome,
              quantidade: c.quantidade,
              precoUnitario: c.produto.precoVenda,
            ))
        .toList();

    final venda = Venda(
      id: _uuid.v4(),
      empresaId: empresaId,
      itens: itens,
      subtotal: subtotal,
      desconto: desconto,
      total: total,
      formaPagamento: formaPagamento,
      valorRecebido: valorRecebido,
      usuarioNome: usuarioNome,
      data: DateTime.now(),
    );

    await saveVenda(venda);

    // Baixar estoque
    for (final item in carrinho) {
      item.produto.qtdEstoque -= item.quantidade;
      if (item.produto.qtdEstoque < 0) item.produto.qtdEstoque = 0;
      await saveProduto(item.produto);
      final mov = Movimentacao(
        id: _uuid.v4(),
        empresaId: empresaId,
        produtoId: item.produto.id,
        produtoNome: item.produto.nome,
        tipo: TipoMovimentacao.saida,
        quantidade: item.quantidade,
        motivo: 'Venda PDV',
        usuarioNome: usuarioNome,
        data: DateTime.now(),
      );
      await saveMovimentacao(mov);
    }

    return venda;
  }

  // ─── Auditoria ───────────────────────────────────────────────────────────────
  Future<List<LogAuditoria>> getLogs(String empresaId) async {
    final ids = _prefs.getStringList('logs_$empresaId') ?? [];
    final result = <LogAuditoria>[];
    for (final id in ids) {
      final s = _prefs.getString('log_$id');
      if (s != null) result.add(LogAuditoria.fromJson(s));
    }
    result.sort((a, b) => b.data.compareTo(a.data));
    return result;
  }

  Future<void> addLog({
    required String empresaId,
    required String usuarioNome,
    required String acao,
    required String descricao,
  }) async {
    final log = LogAuditoria(
      id: _uuid.v4(),
      empresaId: empresaId,
      usuarioNome: usuarioNome,
      acao: acao,
      descricao: descricao,
      data: DateTime.now(),
    );
    await _prefs.setString('log_${log.id}', log.toJson());
    final ids = _prefs.getStringList('logs_$empresaId') ?? [];
    ids.add(log.id);
    await _prefs.setStringList('logs_$empresaId', ids);
  }

  // ─── Setup inicial ───────────────────────────────────────────────────────────
  Future<bool> hasAdminSetup() async {
    final keys = _prefs.getKeys();
    return keys.any((k) => k.startsWith('usuario_'));
  }

  Future<void> setupAdmin({
    required String nomeEmpresa,
    required String cnpj,
    required String telefone,
    required String emailEmpresa,
    required String endereco,
    required String cidade,
    required String estado,
    required String nomeAdmin,
    required String emailAdmin,
    required String senha,
  }) async {
    final empresaId = _uuid.v4();
    final empresa = Empresa(
      id: empresaId,
      nome: nomeEmpresa,
      cnpj: cnpj,
      telefone: telefone,
      email: emailEmpresa,
      endereco: endereco,
      cidade: cidade,
      estado: estado,
    );
    await saveEmpresa(empresa);

    final admin = Usuario(
      id: _uuid.v4(),
      empresaId: empresaId,
      nome: nomeAdmin,
      email: emailAdmin,
      senhaHash: hashSenha(senha),
      role: UserRole.admin,
    );
    await saveUsuario(admin);

    // Salvar referência do admin principal
    await _prefs.setString('admin_email', emailAdmin);
    await _prefs.setString('admin_empresa_id', empresaId);
  }

  Future<String?> getAdminEmpresaId() async {
    return _prefs.getString('admin_empresa_id');
  }

  // ─── Sessão ──────────────────────────────────────────────────────────────────
  Future<void> saveSession(Usuario u) async {
    await _prefs.setString('session_user_id', u.id);
    await _prefs.setString('session_empresa_id', u.empresaId);
  }

  Future<void> clearSession() async {
    await _prefs.remove('session_user_id');
    await _prefs.remove('session_empresa_id');
  }

  Future<Usuario?> getSessionUser() async {
    final userId = _prefs.getString('session_user_id');
    if (userId == null) return null;
    final s = _prefs.getString('usuario_$userId');
    if (s == null) return null;
    return Usuario.fromJson(s);
  }

  // ─── Novo usuário ────────────────────────────────────────────────────────────
  Future<Usuario> criarUsuario({
    required String empresaId,
    required String nome,
    required String email,
    required String senha,
    required UserRole role,
  }) async {
    final u = Usuario(
      id: _uuid.v4(),
      empresaId: empresaId,
      nome: nome,
      email: email,
      senhaHash: hashSenha(senha),
      role: role,
    );
    await saveUsuario(u);
    return u;
  }
}
