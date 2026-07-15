import 'package:flutter/material.dart';
// Importa serviço de estado global (sessão/perfil de usuário). // Usado para consultar isAdmin e executar logout.
import '../services/app_state.dart';
import '../utils/theme.dart';
import 'dashboard_page.dart';
import 'estoque_page.dart';
import 'caixa_page.dart';
import 'relatorios_page.dart';
import 'usuarios_page.dart';
import 'login_page.dart';

// Tela principal com navegação por abas; é Stateful. // Mantém o índice da aba ativa entre reconstruções.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  // Conecta o StatefulWidget ao seu State privado. // Mantém a lógica e estado separados da UI declarativa.
  @override
  State<HomePage> createState() => _HomePageState();
}

// State responsável por gerenciar o índice e construir o layout.
class _HomePageState extends State<HomePage> {
  // Índice da aba selecionada, usado para navegação.
  int _index = 0;

  // Páginas fixas alinhadas à ordem dos botões. // Com IndexedStack, permanecem montadas preservando estado.
  final _pages = const [
    DashboardPage(),
    EstoquePage(),
    CaixaPage(),
    RelatoriosPage(),
    UsuariosPage(),
  ];

  // Método build monta Scaffold com conteúdo e barra inferior. // Adapta a navegação conforme o papel do usuário.
  @override
  Widget build(BuildContext context) {
    // Consulta no AppState (singleton) se o usuário é admin. // Define quais itens da barra inferior serão exibidos.
    final isAdmin = AppState().isAdmin;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(index: _index, children: _pages),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomBar(
                index: _index,
                isAdmin: isAdmin,
                onChanged: (v) => setState(() => _index = v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Barra inferior customizada com suporte a FAB central. // Expõe índice atual e callback para trocar de aba.
class _BottomBar extends StatelessWidget {
  final int index;
  final bool isAdmin;
  final ValueChanged<int> onChanged;

  const _BottomBar({
    required this.index,
    required this.isAdmin,
    required this.onChanged,
  });

  // Constrói BottomAppBar com notch e sombra suave. // Distribui itens em Row e aplica estilo do tema.
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, -2),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: BottomAppBar(
        height: 84,
        elevation: 0,
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.grid_view_rounded,
              label: 'Início',
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
            _NavItem(
              icon: Icons.inventory_2_outlined,
              label: 'Estoque',
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
            // Botão central de caixa
            FloatingActionButton(
              onPressed: () => onChanged(2),
              backgroundColor: index == 2
                  ? AppColors.primaryDark
                  : AppColors.accentGreen,
              elevation: 4,
              child: const Icon(Icons.shopping_cart_rounded,
                  color: Colors.white, size: 28),
            ),
            _NavItem(
              icon: Icons.bar_chart_outlined,
              label: 'Relatórios',
              selected: index == 3,
              onTap: () => onChanged(3),
            ),
            if (isAdmin)
              _NavItem(
                icon: Icons.group_outlined,
                label: 'Usuários',
                selected: index == 4,
                onTap: () => onChanged(4),
              )
            else
              _NavItem(
                icon: Icons.person_outline,
                label: 'Perfil',
                selected: index == 4,
                onTap: () => _showLogout(context),
              ),
          ],
        ),
      ),
    );
  }

  // Exibe confirmação e realiza o fluxo de logout. // Chama AppState().logout e navega ao Login com mounted check.
  void _showLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja sair do sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AppState().logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              }
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

// Item reutilizável de navegação (ícone + rótulo). // Recebe estado selecionado e callback de toque.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  // Constrói o item variando cor pelo estado selecionado. // InkWell fornece feedback e área de clique segura.
  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDark : const Color(0xFF9AA5B5);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
