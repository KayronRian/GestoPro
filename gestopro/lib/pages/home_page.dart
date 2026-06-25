import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../utils/theme.dart';
import 'dashboard_page.dart';
import 'estoque_page.dart';
import 'caixa_page.dart';
import 'relatorios_page.dart';
import 'usuarios_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final _pages = const [
    DashboardPage(),
    EstoquePage(),
    CaixaPage(),
    RelatoriosPage(),
    UsuariosPage(),
  ];

  @override
  Widget build(BuildContext context) {
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

class _BottomBar extends StatelessWidget {
  final int index;
  final bool isAdmin;
  final ValueChanged<int> onChanged;

  const _BottomBar({
    required this.index,
    required this.isAdmin,
    required this.onChanged,
  });

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
