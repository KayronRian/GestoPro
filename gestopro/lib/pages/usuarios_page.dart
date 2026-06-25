import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/app_state.dart';
import '../services/db_service.dart';
import '../utils/theme.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage>
    with SingleTickerProviderStateMixin {
  List<Usuario> _usuarios = [];
  List<LogAuditoria> _logs = [];
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = DbService();
    final state = AppState();
    final usuarios = await db.getUsuarios(state.empresaId);
    final logs = await db.getLogs(state.empresaId);
    if (mounted) {
      setState(() {
        _usuarios = usuarios;
        _logs = logs;
        _loading = false;
      });
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Usuários',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (isAdmin)
                    IconButton(
                      onPressed: () => _showFormUsuario(context),
                      icon: const Icon(Icons.person_add_outlined,
                          color: Colors.white),
                      tooltip: 'Novo usuário',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabCtrl,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorColor: AppColors.accentGreen,
                tabs: const [
                  Tab(text: 'Usuários'),
                  Tab(text: 'Auditoria'),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _TabUsuarios(
                      usuarios: _usuarios,
                      isAdmin: isAdmin,
                      onEdit: (u) => _showFormUsuario(context, usuario: u),
                      onToggle: (u) => _toggleAtivo(u),
                      onDelete: (u) => _deletar(u),
                      onRefresh: _load,
                    ),
                    _TabAuditoria(logs: _logs),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _toggleAtivo(Usuario u) async {
    u.ativo = !u.ativo;
    await DbService().saveUsuario(u);
    await DbService().addLog(
      empresaId: AppState().empresaId,
      usuarioNome: AppState().usuarioNome,
      acao: u.ativo ? 'Usuário ativado' : 'Usuário desativado',
      descricao: '${u.nome} foi ${u.ativo ? 'ativado' : 'desativado'}',
    );
    _load();
  }

  Future<void> _deletar(Usuario u) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Text('Deseja excluir "${u.nome}"?'),
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
    if (confirm == true) {
      await DbService().deleteUsuario(AppState().empresaId, u.id);
      await DbService().addLog(
        empresaId: AppState().empresaId,
        usuarioNome: AppState().usuarioNome,
        acao: 'Usuário excluído',
        descricao: 'Usuário "${u.nome}" excluído',
      );
      _load();
    }
  }

  void _showFormUsuario(BuildContext context, {Usuario? usuario}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _FormUsuario(
        usuario: usuario,
        onSalvo: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }
}

class _TabUsuarios extends StatelessWidget {
  final List<Usuario> usuarios;
  final bool isAdmin;
  final ValueChanged<Usuario> onEdit;
  final ValueChanged<Usuario> onToggle;
  final ValueChanged<Usuario> onDelete;
  final VoidCallback onRefresh;

  const _TabUsuarios({
    required this.usuarios,
    required this.isAdmin,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (usuarios.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined,
                size: 64, color: AppColors.muted.withOpacity(0.4)),
            const SizedBox(height: 12),
            const Text(
              'Nenhum usuário cadastrado',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        itemCount: usuarios.length,
        itemBuilder: (ctx, i) {
          final u = usuarios[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: u.role == UserRole.admin
                          ? AppColors.primaryDark.withOpacity(0.12)
                          : AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      u.role == UserRole.admin
                          ? Icons.admin_panel_settings_outlined
                          : Icons.person_outline,
                      color: u.role == UserRole.admin
                          ? AppColors.primaryDark
                          : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              u.nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: u.role == UserRole.admin
                                    ? AppColors.primaryDark.withOpacity(0.1)
                                    : AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                u.role == UserRole.admin
                                    ? 'Admin'
                                    : 'Funcionário',
                                style: TextStyle(
                                  color: u.role == UserRole.admin
                                      ? AppColors.primaryDark
                                      : AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          u.email,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12),
                        ),
                        if (u.ultimoAcesso != null)
                          Text(
                            'Último acesso: ${formatDateTime(u.ultimoAcesso!)}',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  if (isAdmin) ...[
                    Column(
                      children: [
                        Switch(
                          value: u.ativo,
                          onChanged: (_) => onToggle(u),
                          activeColor: AppColors.success,
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => onEdit(u),
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: AppColors.primary),
                              tooltip: 'Editar',
                            ),
                            IconButton(
                              onPressed: () => onDelete(u),
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.danger),
                              tooltip: 'Excluir',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else
                    StatusBadge(
                      label: u.ativo ? 'Ativo' : 'Inativo',
                      color: u.ativo ? AppColors.success : AppColors.muted,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TabAuditoria extends StatelessWidget {
  final List<LogAuditoria> logs;

  const _TabAuditoria({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum registro de auditoria',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: logs.length,
      itemBuilder: (ctx, i) {
        final log = logs[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.acao,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        log.descricao,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                      Text(
                        '${log.usuarioNome} · ${formatDateTime(log.data)}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Formulário de usuário ────────────────────────────────────────────────────
class _FormUsuario extends StatefulWidget {
  final Usuario? usuario;
  final VoidCallback onSalvo;

  const _FormUsuario({this.usuario, required this.onSalvo});

  @override
  State<_FormUsuario> createState() => _FormUsuarioState();
}

class _FormUsuarioState extends State<_FormUsuario> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  late final TextEditingController _nomeCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _senhaCtrl;
  UserRole _role = UserRole.funcionario;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nomeCtrl = TextEditingController(text: u?.nome ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _senhaCtrl = TextEditingController();
    _role = u?.role ?? UserRole.funcionario;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final db = DbService();
      final state = AppState();
      final isEdit = widget.usuario != null;

      if (isEdit) {
        final u = widget.usuario!;
        u.nome = _nomeCtrl.text.trim();
        u.email = _emailCtrl.text.trim();
        u.role = _role;
        if (_senhaCtrl.text.isNotEmpty) {
          u.senhaHash = hashSenha(_senhaCtrl.text);
        }
        await db.saveUsuario(u);
        await db.addLog(
          empresaId: state.empresaId,
          usuarioNome: state.usuarioNome,
          acao: 'Usuário editado',
          descricao: 'Usuário "${u.nome}" editado',
        );
      } else {
        final u = await db.criarUsuario(
          empresaId: state.empresaId,
          nome: _nomeCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          senha: _senhaCtrl.text,
          role: _role,
        );
        await db.addLog(
          empresaId: state.empresaId,
          usuarioNome: state.usuarioNome,
          acao: 'Usuário criado',
          descricao: 'Usuário "${u.nome}" criado com perfil ${_role.name}',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? 'Usuário atualizado!'
                : 'Usuário criado com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onSalvo();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.usuario != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isEdit ? 'Editar Usuário' : 'Novo Usuário',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _nomeCtrl,
                label: 'Nome completo *',
                icon: Icons.person_outline,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _emailCtrl,
                label: 'E-mail *',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return 'Obrigatório';
                  if (!v!.contains('@')) return 'E-mail inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _senhaCtrl,
                label: isEdit ? 'Nova senha (deixe em branco para manter)' : 'Senha *',
                icon: Icons.lock_outline,
                obscureText: _obscure,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                validator: (v) {
                  if (!isEdit && (v ?? '').isEmpty) return 'Obrigatório';
                  if ((v ?? '').isNotEmpty && v!.length < 6) {
                    return 'Mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Perfil de acesso',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _RoleCard(
                      role: UserRole.funcionario,
                      selected: _role == UserRole.funcionario,
                      onTap: () => setState(() => _role = UserRole.funcionario),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RoleCard(
                      role: UserRole.admin,
                      selected: _role == UserRole.admin,
                      onTap: () => setState(() => _role = UserRole.admin),
                    ),
                  ),
                ],
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
                          isEdit ? 'Salvar alterações' : 'Criar usuário',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? (isAdmin
                  ? AppColors.primaryDark.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1))
              : const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? (isAdmin ? AppColors.primaryDark : AppColors.primary)
                : AppColors.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isAdmin
                  ? Icons.admin_panel_settings_outlined
                  : Icons.person_outline,
              color: selected
                  ? (isAdmin ? AppColors.primaryDark : AppColors.primary)
                  : AppColors.muted,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              isAdmin ? 'Admin' : 'Funcionário',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected
                    ? (isAdmin ? AppColors.primaryDark : AppColors.primary)
                    : AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isAdmin
                  ? 'Acesso total'
                  : 'Estoque e caixa',
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
