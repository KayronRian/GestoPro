import 'package:flutter/material.dart';
import '../models/models.dart';
import 'db_service.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._();
  factory AppState() => _instance;
  AppState._();

  final _db = DbService();

  Usuario? _usuario;
  Empresa? _empresa;
  bool _loading = false;

  Usuario? get usuario => _usuario;
  Empresa? get empresa => _empresa;
  bool get loading => _loading;
  bool get logado => _usuario != null;
  bool get isAdmin => _usuario?.role == UserRole.admin;
  String get empresaId => _usuario?.empresaId ?? '';
  String get usuarioNome => _usuario?.nome ?? '';

  Future<void> init() async {
    await _db.init();
    final u = await _db.getSessionUser();
    if (u != null) {
      _usuario = u;
      _empresa = await _db.getEmpresa(u.empresaId);
      notifyListeners();
    }
  }

  Future<String?> login(String email, String senha) async {
    _loading = true;
    notifyListeners();
    try {
      final u = await _db.login(email, senha);
      if (u == null) return 'E-mail ou senha incorretos';
      _usuario = u;
      _empresa = await _db.getEmpresa(u.empresaId);
      await _db.saveSession(u);
      await _db.addLog(
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

  Future<void> logout() async {
    await _db.clearSession();
    _usuario = null;
    _empresa = null;
    notifyListeners();
  }

  Future<bool> hasSetup() => _db.hasAdminSetup();

  Future<void> reloadEmpresa() async {
    if (_usuario != null) {
      _empresa = await _db.getEmpresa(_usuario!.empresaId);
      notifyListeners();
    }
  }
}
