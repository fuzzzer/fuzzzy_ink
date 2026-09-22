import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _onNext() async {
    if (_currentPage < 3) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await sl.get<PreferencesService>().setHasSeenOnboarding(true);
      if (mounted) context.go(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = FuzzzyInkLocalizations.of(context)!;
    final fuzzzyColors = context.fuzzzyColors;

    return Scaffold(
      backgroundColor: fuzzzyColors.ground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildSlide(
                    context,
                    Icons.security,
                    l10n.welcomeToFuzzzyInk,
                    l10n.offlineEncryptedClipboard,
                  ),
                  _buildSlide(
                    context,
                    Icons.offline_bolt,
                    l10n.offlineEncryptedClipboard, // Just reusing the title roughly
                    l10n.yourDataNeverLeavesYourDeviceNoServersNoTracking,
                  ),
                  _buildSlide(
                    context,
                    Icons.handshake,
                    l10n.secureHandshake,
                    l10n.connectWithOthersUsingASecureOfflineCodeExchange,
                  ),
                  _buildSlide(
                    context,
                    Icons.lock_clock,
                    l10n.forwardSecrecyTitle,
                    l10n.forwardSecrecyNotice,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? fuzzzyColors.inkFaint
                              : fuzzzyColors.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: fuzzzyColors.inkFaint,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _onNext,
                      child: Text(
                        _currentPage == 3 ? l10n.getStarted : l10n.next,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: fuzzzyColors.ground, // dark text on inkFaint
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildSlide(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);
    final fuzzzyColors = context.fuzzzyColors;
    const padding = EdgeInsets.all(40);

    // Centred when there is room, scrollable when there is not (the longer
    // slides overflow a short window otherwise).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 100,
                  color: fuzzzyColors.inkFaint,
                ),
                const SizedBox(height: 48),
                Text(
                  title,
                  style: _titleStyle(
                    context,
                    title,
                    constraints.maxWidth - padding.horizontal,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: fuzzzyColors.inkMute,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The largest title style whose longest word fits [maxWidth], so the title
  /// only ever wraps between words. A Georgian word can be wider than a phone
  /// column at the display size (T-0335); English never steps down.
  TextStyle? _titleStyle(BuildContext context, String title, double maxWidth) {
    final textTheme = Theme.of(context).textTheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final ink = context.fuzzzyColors.ink;
    final candidates = [
      textTheme.headlineMedium,
      textTheme.titleLarge,
      textTheme.titleMedium,
    ].map((style) => style?.copyWith(fontWeight: FontWeight.w800, color: ink));

    bool wordFits(String word, TextStyle? style) {
      final textPainter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      return textPainter.width <= maxWidth;
    }

    return candidates.firstWhere(
      (style) => title.split(' ').every((word) => wordFits(word, style)),
      orElse: () => candidates.last,
    );
  }
}
