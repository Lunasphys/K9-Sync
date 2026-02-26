import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k9sync/core/theme/app_theme.dart';
import 'package:k9sync/presentation/router/route_guards.dart';

/// Onboarding 3 slides (mockup) : Localisez, Santé, Partagez.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_SlideData> _slides = [
    _SlideData(
      emoji: '📍',
      bgColor: Color(0xFFFFF0E8),
      circleColor: Color(0xFFFFD6B0),
      title: 'Localisez votre chien\nen temps réel',
      subtitle:
          'Suivez chaque promenade sur une carte interactive. Recevez une alerte dès que Bucky sort de sa zone.',
    ),
    _SlideData(
      emoji: '❤️',
      bgColor: Color(0xFFFFE8F0),
      circleColor: Color(0xFFFFB3CC),
      title: 'Surveillez sa santé\nchaque jour',
      subtitle:
          'Fréquence cardiaque, température, sommeil et activité. Détectez les anomalies avant qu\'elles deviennent des problèmes.',
    ),
    _SlideData(
      emoji: '👨‍👩‍👧',
      bgColor: Color(0xFFE8F5EC),
      circleColor: Color(0xFFA8E6C0),
      title: 'Partagez avec\nvotre famille',
      subtitle:
          'Invitez votre famille et votre dog-sitter. Chacun reçoit les alertes importantes et peut voir Bucky en temps réel.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: Text(
                  'Passer',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Container(
                    color: s.bgColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: s.circleColor,
                            border: Border.all(color: AppColors.border, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.border,
                                offset: const Offset(4, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(s.emoji, style: const TextStyle(fontSize: 90)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            s.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _currentPage ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AppColors.orange
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _slides.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          context.go(AppRoutes.login);
                        }
                      },
                      child: Text(
                        _currentPage < _slides.length - 1
                            ? 'Suivant →'
                            : 'Commencer 🐾',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  final String emoji;
  final Color bgColor;
  final Color circleColor;
  final String title;
  final String subtitle;
  const _SlideData({
    required this.emoji,
    required this.bgColor,
    required this.circleColor,
    required this.title,
    required this.subtitle,
  });
}
