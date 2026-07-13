// Arquivo Principal
import 'package:flutter/material.dart';
import 'services/app_state.dart';
import 'services/db_service.dart';
import 'utils/theme.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

/// Função principal que inicia a execução do programa.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService().init();   // Inicializa o serviço de banco de dados
  runApp(const GestoProApp());  // Inicia o aplicativo chamando o widget raiz.
}


class GestoProApp extends StatelessWidget {
  const GestoProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GestoPro',
      theme: buildTheme(),       // Aplica o tema visual personalizado definido no arquivo utils/theme.dart.
      home: const _AppBootstrap(),
    );
  }
}

/// [_AppBootstrap] é um widget intermediário que decide qual tela o usuário deve ver primeiro.
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();
  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}
class _AppBootstrapState extends State<_AppBootstrap> {
  bool _loading = true;
  Widget? _destination;
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Processo de verificação de sessão e dados iniciais.
  Future<void> _bootstrap() async {
    final state = AppState();
    // Inicializa o estado global (verifica se há usuário logado na memória).
    await state.init();
    
    final db = DbService();

    // o sistema cria um usuário "Admin Demo" automaticamente para permitir o primeiro acesso.
    final hasAdmin = await db.hasAdminSetup();
    if (!hasAdmin) {
      await db.setupAdmin(
        nomeEmpresa: 'Empresa Demo',
        cnpj: '12.345.678/0001-99',
        telefone: '(11) 98765-4321',
        emailEmpresa: 'contato@demo.com.br',
        endereco: 'Rua Demo, 123',
        cidade: 'São Paulo',
        estado: 'SP',
        nomeAdmin: 'Admin Demo',
        emailAdmin: 'admin@demo.com.br',
        senha: 'demo123',
      );
    }

        // Define o destino com base no estado de login do usuário.
    Widget dest;
    if (state.logado) {
      dest = const HomePage();
    } else {
      dest = const LoginPage();
    }

        // Atualiza a interface: remove o carregamento e define a tela de destino.
    if (mounted) {
      setState(() {
        _destination = dest;
        _loading = false;
      });
    }
  }

  //carregamento do app
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoMark(size: 80),
              SizedBox(height: 24),
              Text(
                'GestoPro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Gestão inteligente de estoque',
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ],
          ),
        ),
      );
    }

    // Após o carregamento, retorna a tela de destino definida (Home ou Login).
    return _destination!;
  }
}
