import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/shell_bloc.dart';
import '../../../welcome/presentation/pages/welcome_screen.dart';
import '../../../alerts/presentation/pages/alerts_screen.dart';
import '../../../placeholder/presentation/pages/placeholder_screen.dart';

/// Main shell with bottom navigation. Uses [ShellBloc] for selected tab index.
class MainShell extends StatelessWidget {
  const MainShell({super.key});

  static const List<_NavItem> navItems = [
    _NavItem(icon: Icons.home_outlined, label: 'Maison'),
    _NavItem(icon: Icons.map_outlined, label: 'Carte'),
    _NavItem(icon: Icons.notifications_outlined, label: 'Alertes'),
    _NavItem(icon: Icons.pets, label: 'Profil animal'),
    _NavItem(icon: Icons.person_outline, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShellBloc(),
      child: const _MainShellView(),
    );
  }
}

class _MainShellView extends StatelessWidget {
  const _MainShellView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShellBloc, ShellState>(
      buildWhen: (prev, curr) => prev.selectedIndex != curr.selectedIndex,
      builder: (context, state) {
        return Scaffold(
          body: IndexedStack(
            index: state.selectedIndex,
            children: const [
              WelcomeScreen(),
              PlaceholderScreen(title: 'Carte', icon: Icons.map_outlined),
              AlertsScreen(),
              PlaceholderScreen(title: 'Profil animal', icon: Icons.pets),
              PlaceholderScreen(title: 'Profil utilisateur', icon: Icons.person_outline),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: state.selectedIndex,
            onTap: (index) => context.read<ShellBloc>().add(ShellTabSelected(index)),
            items: MainShell.navItems
                .map(
                  (e) => BottomNavigationBarItem(
                    icon: Icon(e.icon),
                    label: e.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
