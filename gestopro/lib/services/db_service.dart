// Lógica de serviço
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

// Gerador de IDs únicos (UUID v4) para novos registros.
const _uuid = Uuid();

/// Função utilitária para transformar uma senha em texto puro em um hash SHA-256.
String hashSenha(String senha) =>
    sha256.convert(utf8.encode(senha)).toString();

/// [DbService] gerencia toda a persistência de dados do aplicativo.
/// Como este é um app focado em simplicidade e funcionamento offline/local,
/// ele utiliza o [SharedPreferences] para simular um banco de dados NoSQL.
class DbService {
  // Padrão Singleton para garantir que todas as telas usem a mesma conexão com os dados.
  static final DbService _instance = DbService._();
  factory DbService() => _instance;
  DbService._();

  late SharedPreferences _prefs;
  bool _initialized = false;

  /// Inicializa a biblioteca de armazenamento local.
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // ─── Empresa ────────────────────────────────────────────────────────────────
  // Métodos para buscar e salvar os dados cadastrais da empresa.

  Future<Empresa?> getEmpresa(String id) async {
    final s = _prefs.getString('empresa_$id');
    if (s == null) return null;
    return Empresa.fromJson(s);
  }

  Future<void> saveEmpresa(Empresa e) async {
    await _prefs.setString('empresa_${e.id}', e.toJson());
  }

  // ─── Usuários ────────────────────────────────────────────────────────────────
  // Gerenciamento de login, cadastro e permissões de usuários.

  /// Retorna todos os usuários vinculados a uma empresa específica.
  Future<List<Usuario>> getUsuarios(String empresaId) async {
    final ids = _prefs.getStringList('usuarios_$empresaId') ?? [];
    final result = <Usuario>[];
    for (final id in ids) {
      final s = _prefs.getString('usuario_$id');
      if (s != null) result.add(Usuario.fromJson(s));
    }
    return result;
  }

  /// Salva ou atualiza um usuário e garante que seu ID esteja na lista da empresa.
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

  /// Busca um usuário pelo e-mail (usado no processo de login).
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

  /// Verifica as credenciais e realiza o login se o hash da senha bater.
  Future<Usuario?> login(String email, String senha) async {
    final u = await findUsuarioByEmail(email);
    if (u == null || !u.ativo) return null;
    if (u.senhaHash != hashSenha(senha)) return null;
    u.ultimoAcesso = DateTime.now();
    await saveUsuario(u);
    return u;
  }

  // ─── Produtos ────────────────────────────────────────────────────────────────
  // Controle do catálogo de produtos e estoque.

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

  /// Busca um produto pelo código de barras (usado no Scanner e no PDV).
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
  // Registro histórico de todas as entradas e saídas de mercadorias.

  Future<List<Movimentacao>> getMovimentacoes(String empresaId) async {
    final ids = _prefs.getStringList('movs_$empresaId') ?? [];
    final result = <Movimentacao>[];
    for (final id in ids) {
      final s = _prefs.getString('mov_$id');
      if (s != null) result.add(Movimentacao.fromJson(s));
    }
    // Ordena as movimentações da mais recente para a mais antiga.
    result.sort((a, b) => b.data.compareTo(a.data));
    return result;
  }

  /// Adiciona itens ao estoque e gera um registro de movimentação do tipo 'entrada'.
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

  /// Remove itens do estoque (ajuste manual ou perda) e gera registro de 'saída'.
  Future<bool> registrarSaida({
    required String empresaId,
    required Produto produto,
    required int quantidade,
    String? motivo,
    String? observacoes,
    required String usuarioNome,
  }) async {
    if (produto.qtdEstoque < quantidade) return false; // Impede estoque negativo.
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
  // Processamento de vendas realizadas no PDV (Ponto de Venda).

  /// Finaliza uma venda, calcula totais, gera o registro de venda e baixa o estoque.
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

    // Baixa automática do estoque para cada item vendido.
    for (final item in carrinho) {
      item.produto.qtdEstoque -= item.quantidade;
      if (item.produto.qtdEstoque < 0) item.produto.qtdEstoque = 0;
      await saveProduto(item.produto);
      
      // Registra a saída no histórico de movimentações.
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
  // Registro de ações importantes realizadas no sistema para segurança.

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
  // Configurações realizadas na primeira vez que o app é aberto.

  /// Cria a estrutura inicial da empresa e do primeiro administrador.
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

    await _prefs.setString('admin_email', emailAdmin);
    await _prefs.setString('admin_empresa_id', empresaId);
  }

  // ─── Sessão ──────────────────────────────────────────────────────────────────
  // Controle de persistência de login (Manter conectado).

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
}
