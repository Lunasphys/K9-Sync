import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell principal avec bottom navigation, piloté par Go Router (StatefulShellRoute).
/// [navigationShell] est fourni par Go Router pour changer d'onglet et afficher le contenu.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<ShellNavItem> navItems = [
    ShellNavItem(icon: Icons.home_outlined, label: 'Maison', path: '/home/accueil'),
    ShellNavItem(icon: Icons.map_outlined, label: 'Carte', path: '/home/carte'),
    ShellNavItem(icon: Icons.notifications_outlined, label: 'Alertes', path: '/home/alertes'),
    ShellNavItem(icon: Icons.favorite_outline, label: 'Santé', path: '/home/sante'),
    ShellNavItem(icon: Icons.person_outline, label: 'Profil', path: '/home/profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onItemTapped(context, index),
        items: navItems
            .map(
              (e) => BottomNavigationBarItem(
                icon: Icon(e.icon),
                label: e.label,
              ),
            )
            .toList(),
      ),
    );
  }

  void _onItemTapped(BuildContext context, int index) {
    navigationShell.goBranch(index);
  }
}

/// Élément de la bottom nav (Go Router path par onglet).
class ShellNavItem {
  final IconData icon;
  final String label;
  final String path;
  const ShellNavItem({required this.icon, required this.label, required this.path});
}
