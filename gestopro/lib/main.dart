import 'package:flutter/material.dart';
import 'services/app_state.dart';
import 'services/db_service.dart';
import 'utils/theme.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar SharedPreferences antes de qualquer coisa
  await DbService().init();
  runApp(const GestoProApp());
}

class GestoProApp extends StatelessWidget {
  const GestoProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GestoPro',
      theme: buildTheme(),
      home: const _AppBootstrap(),
    );
  }
}

/// Decide qual tela mostrar ao iniciar o app:
/// 1. Se há sessão ativa → HomePage
/// 2. Se não há admin cadastrado → SetupPage
/// 3. Caso contrário → LoginPage
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

  Future<void> _bootstrap() async {
    final state = AppState();
    await state.init();
    final db = DbService();

    // Criar admin de demo automaticamente se não existir
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

    Widget dest;
    if (state.logado) {
      dest = const HomePage();
    } else {
      dest = const LoginPage();
    }

    if (mounted) {
      setState(() {
        _destination = dest;
        _loading = false;
      });
    }
  }

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

    return _destination!;
  }
}
