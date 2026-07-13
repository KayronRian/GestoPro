// Lógica de serviço (Banco de Dados ou Estado)

import 'package:flutter/material.dart';
import '../models/models.dart';
import 'db_service.dart';

// classe central que gerencia o estado global do aplicativo.
class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._();   // Garante que o AppState seja acessado de qualquer lugar com a mesma instância.
  factory AppState() => _instance;
  AppState._();

    // Instância do serviço de banco de dados para operações internas.
  final _db = DbService();

    // --- Variáveis de Estado Privadas ---
  Usuario? _usuario;
  Empresa? _empresa;
  bool _loading = false;

  // --- Getters Públicos ---
  Usuario? get usuario => _usuario;
  Empresa? get empresa => _empresa;
  bool get loading => _loading;
  bool get logado => _usuario != null;
  bool get isAdmin => _usuario?.role == UserRole.admin;
  String get empresaId => _usuario?.empresaId ?? '';
  String get usuarioNome => _usuario?.nome ?? '';

    /// Inicializa o estado do app.
  /// Verifica se já existe uma sessão salva localmente para logar automaticamente.
  Future<void> init() async {
    await _db.init();
    final u = await _db.getSessionUser();
    if (u != null) {
      _usuario = u;
      _empresa = await _db.getEmpresa(u.empresaId);
      notifyListeners();
    }
  }

    /// Realiza a tentativa de login do usuário.
  Future<String?> login(String email, String senha) async {
    _loading = true;
    notifyListeners();
    try {
      final u = await _db.login(email, senha);
      if (u == null) return 'E-mail ou senha incorretos';
      _usuario = u;
      _empresa = await _db.getEmpresa(u.empresaId);
      await _db.saveSession(u); // Salva a sessão para que o usuário não precise logar de novo ao abrir o app.
      await _db.addLog(       // Registra o login no histórico do sistema.
        empresaId: u.empresaId,
        usuarioNome: u.nome,
        acao: 'Login',
        descricao: 'Login realizado por ${u.nome}',
      );
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

   /// Finaliza a sessão do usuário e limpa os dados da memória e do armazenamento local.
  Future<void> logout() async {
    await _db.clearSession();
    _usuario = null;
    _empresa = null;
    notifyListeners();
  }
  /// Verifica se o sistema já passou pela configuração inicial
  Future<bool> hasSetup() => _db.hasAdminSetup();

    /// Recarrega as informações da empresa.
  Future<void> reloadEmpresa() async {
    if (_usuario != null) {
      _empresa = await _db.getEmpresa(_usuario!.empresaId);
      notifyListeners();
    }
  }
}
