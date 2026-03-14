import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/presentation/providers/lost_mode_provider.dart';

/// Shell principal avec bottom navigation, piloté par Go Router (StatefulShellRoute).
/// [navigationShell] est fourni par Go Router pour changer d'onglet et afficher le contenu.
class MainShell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onItemTapped(context, index),
        items: navItems
            .asMap()
            .entries
            .map(
              (entry) {
                final index = entry.key;
                final item = entry.value;
                if (index == 2) {
                  return const BottomNavigationBarItem(
                    icon: AlertsNavIcon(selected: false),
                    label: 'Alertes',
                    activeIcon: AlertsNavIcon(selected: true),
                  );
                }
                return BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.label,
                );
              },
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

class AlertsNavIcon extends ConsumerWidget {
  final bool selected;
  const AlertsNavIcon({super.key, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLost = ref.watch(lostModeProvider);
    final showBadge = isLost;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          selected ? Icons.notifications : Icons.notifications_outlined,
        ),
        if (showBadge)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

