import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../utils/theme.dart';
import 'login_page.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool _loading = false;

  // Empresa
  final _nomeEmpresaCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _emailEmpresaCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _cidadeCtrl = TextEditingController();
  final _estadoCtrl = TextEditingController();

  // Admin
  final _nomeAdminCtrl = TextEditingController();
  final _emailAdminCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmarSenhaCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Dados de demonstração pré-preenchidos para facilitar o primeiro acesso
    _nomeEmpresaCtrl.text = 'Empresa Demo Ltda';
    _cnpjCtrl.text = '12.345.678/0001-99';
    _telefoneCtrl.text = '(11) 98765-4321';
    _emailEmpresaCtrl.text = 'contato@empresademo.com.br';
    _enderecoCtrl.text = 'Rua das Flores, 123';
    _cidadeCtrl.text = 'São Paulo';
    _estadoCtrl.text = 'SP';
    _nomeAdminCtrl.text = 'Administrador';
    _emailAdminCtrl.text = 'admin@empresademo.com.br';
    _senhaCtrl.text = 'admin123';
    _confirmarSenhaCtrl.text = 'admin123';
  }

  @override
  void dispose() {
    for (final c in [
      _nomeEmpresaCtrl, _cnpjCtrl, _telefoneCtrl, _emailEmpresaCtrl,
      _enderecoCtrl, _cidadeCtrl, _estadoCtrl,
      _nomeAdminCtrl, _emailAdminCtrl, _senhaCtrl, _confirmarSenhaCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleNextStep() {
    FocusScope.of(context).unfocus();
    Future.microtask(() {
      if (!mounted) return;
      if (_nomeEmpresaCtrl.text.trim().isNotEmpty) {
        setState(() => _step = 1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informe o nome da empresa'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  Future<void> _finalizar() async {
    // Validação manual dos campos obrigatórios do admin
    if (_nomeAdminCtrl.text.trim().isEmpty ||
        _emailAdminCtrl.text.trim().isEmpty ||
        _senhaCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha nome, email e senha do administrador'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_senhaCtrl.text != _confirmarSenhaCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('As senhas não coincidem'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await DbService().setupAdmin(
        nomeEmpresa: _nomeEmpresaCtrl.text.trim(),
        cnpj: _cnpjCtrl.text.trim(),
        telefone: _telefoneCtrl.text.trim(),
        emailEmpresa: _emailEmpresaCtrl.text.trim(),
        endereco: _enderecoCtrl.text.trim(),
        cidade: _cidadeCtrl.text.trim(),
        estado: _estadoCtrl.text.trim(),
        nomeAdmin: _nomeAdminCtrl.text.trim(),
        emailAdmin: _emailAdminCtrl.text.trim(),
        senha: _senhaCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Empresa cadastrada! Faça login para continuar.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9FBFF), Color(0xFFEAF1FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const LogoMark(size: 72),
                    const SizedBox(height: 16),
                    const Text(
                      'Cadastrar Empresa',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _step == 0
                          ? 'Dados da empresa'
                          : 'Dados do administrador',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    // Indicador de progresso
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StepDot(active: _step >= 0, label: '1'),
                        Container(
                          width: 40,
                          height: 2,
                          color: _step >= 1
                              ? AppColors.primary
                              : AppColors.cardBorder,
                        ),
                        _StepDot(active: _step >= 1, label: '2'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      onChanged: () {
                        // Permitir Enter para submeter
                      },
                      child: AppCard(
                        child: _step == 0
                            ? _StepEmpresa(
                                nomeCtrl: _nomeEmpresaCtrl,
                                cnpjCtrl: _cnpjCtrl,
                                telefoneCtrl: _telefoneCtrl,
                                emailCtrl: _emailEmpresaCtrl,
                                enderecoCtrl: _enderecoCtrl,
                                cidadeCtrl: _cidadeCtrl,
                                estadoCtrl: _estadoCtrl,
                                onSubmit: () => _handleNextStep(),
                              )
                            : _StepAdmin(
                                nomeCtrl: _nomeAdminCtrl,
                                emailCtrl: _emailAdminCtrl,
                                senhaCtrl: _senhaCtrl,
                                confirmarCtrl: _confirmarSenhaCtrl,
                                obscure: _obscure,
                                onToggleObscure: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        if (_step > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _step--),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Voltar'),
                            ),
                          ),
                        if (_step > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      FocusScope.of(context).unfocus();
                                      Future.microtask(() {
                                        if (!mounted) return;
                                        if (_step == 0) {
                                          if (_nomeEmpresaCtrl.text.trim().isNotEmpty) {
                                            setState(() => _step = 1);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Informe o nome da empresa'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        } else {
                                          _finalizar();
                                        }
                                      });
                                    },
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      _step == 0 ? 'Próximo' : 'Cadastrar',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Já tenho cadastro — Fazer login',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool active;
  final String label;
  const _StepDot({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.cardBorder,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : AppColors.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StepEmpresa extends StatelessWidget {
  final TextEditingController nomeCtrl, cnpjCtrl, telefoneCtrl, emailCtrl,
      enderecoCtrl, cidadeCtrl, estadoCtrl;
  final VoidCallback? onSubmit;

  const _StepEmpresa({
    required this.nomeCtrl,
    required this.cnpjCtrl,
    required this.telefoneCtrl,
    required this.emailCtrl,
    required this.enderecoCtrl,
    required this.cidadeCtrl,
    required this.estadoCtrl,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppTextField(
          controller: nomeCtrl,
          label: 'Nome da empresa *',
          icon: Icons.business_outlined,
          validator: (v) => (v ?? '').trim().isEmpty ? 'Obrigatório' : null,
          onFieldSubmitted: (_) => onSubmit?.call(),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: cnpjCtrl,
          label: 'CNPJ',
          hint: '00.000.000/0001-00',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: telefoneCtrl,
                label: 'Telefone',
                icon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: emailCtrl,
                label: 'E-mail da empresa',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: enderecoCtrl,
          label: 'Endereço',
          icon: Icons.location_on_outlined,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: AppTextField(
                controller: cidadeCtrl,
                label: 'Cidade',
                icon: Icons.location_city_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: estadoCtrl,
                label: 'Estado',
                hint: 'SP',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepAdmin extends StatelessWidget {
  final TextEditingController nomeCtrl, emailCtrl, senhaCtrl, confirmarCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;

  const _StepAdmin({
    required this.nomeCtrl,
    required this.emailCtrl,
    required this.senhaCtrl,
    required this.confirmarCtrl,
    required this.obscure,
    required this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Conta do administrador',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Este será o acesso principal do sistema.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: nomeCtrl,
          label: 'Nome completo *',
          icon: Icons.person_outline,
          validator: (v) => (v ?? '').trim().isEmpty ? 'Obrigatório' : null,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: emailCtrl,
          label: 'E-mail do administrador *',
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
          controller: senhaCtrl,
          label: 'Senha *',
          icon: Icons.lock_outline,
          obscureText: obscure,
          suffix: IconButton(
            onPressed: onToggleObscure,
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          validator: (v) {
            if ((v ?? '').isEmpty) return 'Obrigatório';
            if (v!.length < 6) return 'Mínimo 6 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: confirmarCtrl,
          label: 'Confirmar senha *',
          icon: Icons.lock_outline,
          obscureText: obscure,
          validator: (v) {
            if ((v ?? '').isEmpty) return 'Obrigatório';
            if (v != senhaCtrl.text) return 'Senhas não coincidem';
            return null;
          },
        ),
      ],
    );
  }
}
