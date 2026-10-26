import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  AppRouter._();

  static const home = '/';
  static const onboarding = '/onboarding';
  static const chatUnlock = '/chat-unlock';
  static const setup = '/setup';
  static const recover = '/recover';
  static const chatCreate = '/chat/create';
  static const chatInvitation = '/chat/invitation';
  static const chatAccept = '/chat/accept';
  static const chatAcceptanceExport = '/chat/acceptance-export';
  static const chatConnected = '/chat/connected';
  static const chatVerify = '/chat/verify';
  static const settings = '/settings';
  static const aboutEncryption = '/settings/about-encryption';
  static const settingsMasterPassword = '/settings/master-password';
  static const settingsRecoveryKey = '/settings/recovery-key';
  static const settingsSafePassword = '/settings/safe-password';
  static const settingsHowItWorks = '/settings/how-it-works';
  static const settingsLegal = '/settings/legal';
  static const basics = '/basics';
  static const vaultHome = '/vault';
  static const vaultItemEditor = '/vault/editor';
  static const vaultItem = '/vault/item';

  /// Reachable without the master password. Everything else — Basics and
  /// the settings included — sits behind it: there is no "lock off".
  static const _unprotectedRoutes = {
    onboarding,
    chatUnlock,
    setup,
    recover,
    aboutEncryption,
  };

  static GoRouter? _routerInstance;

  static GoRouter? get routerInstance => _routerInstance;

  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router({
    required GlobalKey<NavigatorState> navigatorKey,
    required GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey,
  }) {
    _routerInstance ??= GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: sl.get<PreferencesService>().lastSelectedTab,
      redirect: (context, state) {
        // Links belong to FuzzyLinkHandler, never to a page (T-0328). The
        // platforms hand them to app_links only (Flutter's own deep linking
        // is off), so this is a guard: a link path that reaches the router
        // anyway lands on the home page.
        if (FuzzyLinkType.fromPath(state.uri.path) != null) {
          return AppRouter.home;
        }

        final hasSeenOnboarding =
            sl.get<PreferencesService>().hasSeenOnboarding;
        final isOnboarding = state.matchedLocation == onboarding;

        if (!hasSeenOnboarding && !isOnboarding) return onboarding;
        if (hasSeenOnboarding && isOnboarding) return AppRouter.home;

        final authStatus = sl.get<FuzzyAuthStore>().state.status;
        final matchedLocation = state.matchedLocation;
        final isUnprotected = _unprotectedRoutes.contains(matchedLocation);

        // No master password yet: the first run sets one before anything.
        if (authStatus.isSetupRequired) {
          return matchedLocation == setup ? null : setup;
        }
        if (matchedLocation == setup) {
          return authStatus.hasAccess ? AppRouter.home : chatUnlock;
        }

        // `initial` is the boot window while the secure storage is read:
        // gated like `locked`, so nothing is reachable before the store is
        // open (T-0329). A storage error fails closed the same way.
        if (!isUnprotected && !authStatus.hasAccess) {
          return chatUnlock;
        }

        if ((matchedLocation == chatUnlock || matchedLocation == recover) &&
            authStatus.hasAccess) {
          return AppRouter.home;
        }

        return null;
      },
      routes: [
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) {
            return MainShellPage(
              preferencesService: sl.get<PreferencesService>(),
              child: child,
            );
          },
          // The three tabs. Every other page is a full-screen route below.
          routes: [
            GoRoute(
              path: home,
              builder: (_, __) => HomePage(
                onPastedText: sl.get<FuzzyLinkHandler>().openPastedText,
              ),
            ),
            GoRoute(
              path: vaultHome,
              // My safe keeps its own private screen across locked and open.
              builder: (_, __) => const VaultEntryPage(),
              routes: [
                GoRoute(
                  path: 'item',
                  parentNavigatorKey: navigatorKey,
                  builder: (_, state) => SensitiveScreen(
                    child: VaultItemPage(item: state.extra! as VaultItem),
                  ),
                ),
                GoRoute(
                  path: 'editor',
                  // A full screen over the tabs.
                  parentNavigatorKey: navigatorKey,
                  builder: (_, state) {
                    final payload = state.extra! as VaultItemEditorPagePayload;
                    return SensitiveScreen(
                      child: VaultItemEditorPage(payload: payload),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: settings,
              builder: (_, __) => const SettingsPage(),
            ),
          ],
        ),
        GoRoute(
          path: onboarding,
          builder: (_, state) =>
              OnboardingPage(initialPage: state.extra as int? ?? 0),
        ),
        GoRoute(
          path: chatUnlock,
          builder: (_, __) => const SensitiveScreen(child: ChatUnlockPage()),
        ),
        GoRoute(
          path: setup,
          // Its password and recovery-key steps are private screens (the page
          // wraps each in a SensitiveScreen); the fingerprint step and
          // "You're ready" are not, so Fuzzzy Cast can greet there.
          builder: (_, __) => const MasterPasswordSetupPage(),
        ),
        GoRoute(
          path: recover,
          builder: (_, __) =>
              const SensitiveScreen(child: MasterPasswordRecoveryPage()),
        ),
        GoRoute(
          path: chatCreate,
          builder: (_, __) => const ChatCreationPage(),
        ),
        GoRoute(
          path: chatInvitation,
          builder: (_, state) {
            final payload = state.extra! as ChatInvitationPagePayload;
            return ChatInvitationPage(payload: payload);
          },
        ),
        GoRoute(
          path: chatAccept,
          builder: (_, state) {
            final prefill = state.extra as String?;
            return InvitationAcceptancePage(
              prefillInvitationContent: prefill,
            );
          },
        ),
        GoRoute(
          path: chatAcceptanceExport,
          builder: (_, state) {
            final payload = state.extra! as AcceptanceExportPagePayload;
            return AcceptanceExportPage(payload: payload);
          },
        ),
        GoRoute(
          path: chatConnected,
          builder: (_, state) {
            final payload = state.extra! as ConnectedChatPagePayload;
            return SensitiveScreen(child: ConnectedChatPage(payload: payload));
          },
        ),
        GoRoute(
          path: chatVerify,
          builder: (_, state) {
            final chatGeneralData = state.extra! as ChatGeneralData;
            return SafetyNumberPage(chatGeneralData: chatGeneralData);
          },
        ),
        GoRoute(
          path: aboutEncryption,
          builder: (_, __) => const AboutEncryptionPage(),
        ),
        GoRoute(
          path: settingsMasterPassword,
          builder: (_, __) =>
              const SensitiveScreen(child: ChangeMasterPasswordPage()),
        ),
        GoRoute(
          path: settingsRecoveryKey,
          // A new recovery key is shown here.
          builder: (_, __) =>
              const SensitiveScreen(child: NewRecoveryKeyPage()),
        ),
        GoRoute(
          path: settingsSafePassword,
          builder: (_, __) => const SensitiveScreen(child: SafeOpensWithPage()),
        ),
        GoRoute(
          path: settingsHowItWorks,
          builder: (_, __) => const HowItWorksPage(),
        ),
        GoRoute(
          path: settingsLegal,
          builder: (_, __) => const LegalLinksPage(),
        ),
        GoRoute(
          path: basics,
          builder: (_, __) =>
              const SensitiveScreen(child: BasicEncryptionPage()),
        ),
      ],
    );
    return _routerInstance!;
  }
}
