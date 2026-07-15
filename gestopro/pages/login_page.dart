import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../utils/theme.dart';
import 'setup_page.dart';
import 'home_page.dart';

// Página de login como StatefulWidget para manter estado de inputs e UI.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  // Cria o objeto de estado que controlará a tela e suas interações.
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Chave do Form para validar todos os campos de forma coordenada.
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // O app apenas carrega e aguarda você digitar email e senha
  }
  
  @override
  void dispose() {
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  // Método de envio: valida, chama login e atualiza estado conforme retorno.
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _erro = null;
    });
    // Chamada ao serviço AppState.login; devolve String de erro ou null.
    final erro = await AppState().login(_emailCtrl.text.trim(), _senhaCtrl.text);
    // Proteção: só continua se o widget ainda está montado na árvore.
    if (!mounted) return;
    setState(() => _loading = false);
    if (erro != null) {
      setState(() => _erro = erro);
    } else {
      // Login OK: substitui a rota atual e navega para a HomePage.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  // Monta o layout geral com gradiente, logo e área do formulário.
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
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LogoMark(size: 92),
                    const SizedBox(height: 20),
                    const Text(
                      'Gesto Pro',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Entre para acessar estoque, caixa e relatórios.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Card que abriga o Form; inicia a seção validável do login.
                    AppCard(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Campo de e-mail com teclado adequado e regra: não pode ficar vazio.
                            AppTextField(
                              controller: _emailCtrl,
                              label: 'E-mail',
                              hint: 'admin@empresa.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) =>
                                  (v ?? '').trim().isEmpty ? 'Informe o e-mail' : null,
                            ),
                            const SizedBox(height: 14),
                            // Campo de senha; obscurece texto e permite alternar via ícone.
                            AppTextField(
                              controller: _senhaCtrl,
                              label: 'Senha',
                              hint: '••••••••',
                              icon: Icons.lock_outline,
                              obscureText: _obscure,
                              suffix: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                              validator: (v) =>
                                  (v ?? '').trim().isEmpty ? 'Informe a senha' : null,
                            ),
                            // Bloco condicional: mostra aviso quando _erro possui mensagem.
                            if (_erro != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDEEEE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: AppColors.danger, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _erro!,
                                        style: const TextStyle(
                                          color: AppColors.danger,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            // Área do botão principal: largura total e altura fixa.
                            // O FilledButton alterna entre spinner e texto conforme _loading.
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Entrar',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Ação "Primeira vez?": abre SetupPage para cadastro inicial.
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SetupPage()),
                        );
                      },
                      child: const Text(
                        'Primeira vez? Cadastrar empresa',
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
