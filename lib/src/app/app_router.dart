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
  static const auth = '/auth';
  static const basics = '/basics';
  static const vaultHome = '/vault';
  static const vaultItemEditor = '/vault/editor';

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
            return MainShellPage(child: child);
          },
          routes: [
            GoRoute(
              path: home,
              builder: (_, __) => const ChatListPage(),
            ),
            GoRoute(
              path: vaultHome,
              builder: (_, __) =>
                  const SensitiveScreen(child: VaultEntryPage()),
              routes: [
                GoRoute(
                  path: 'editor',
                  builder: (_, state) {
                    final payload = state.extra! as VaultItemEditorPagePayload;
                    return SensitiveScreen(
                      child: VaultItemEditorPage(payload: payload),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: onboarding,
          builder: (_, __) => const OnboardingPage(),
        ),
        GoRoute(
          path: chatUnlock,
          builder: (_, __) => const SensitiveScreen(child: ChatUnlockPage()),
        ),
        GoRoute(
          path: setup,
          builder: (_, __) => const MasterPasswordSetupPage(),
        ),
        GoRoute(
          path: recover,
          builder: (_, __) => const MasterPasswordRecoveryPage(),
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
          path: settings,
          builder: (_, __) => const SettingsPage(),
        ),
        GoRoute(
          path: aboutEncryption,
          builder: (_, __) => const AboutEncryptionPage(),
        ),
        GoRoute(
          path: auth,
          builder: (_, __) => const FuzzyUserAuthPage(),
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
