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

  /// Lock for one person: `extra` is a [LockPagePayload] (or the person, or
  /// their chat id; `?chat=<id>` works too).
  static const lockFor = '/lock/for';

  /// Lock with a password (no person).
  static const lockWithPassword = '/lock/password';

  /// Open what you got: `extra` is an [OpenPagePayload] (or an
  /// [OpenRequest]), none for the choice of Paste it / Choose a file.
  static const open = '/open';

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
              builder: (_, __) => const HomePage(),
            ),
            GoRoute(
              path: vaultHome,
              builder: (_, __) =>
                  const SensitiveScreen(child: VaultEntryPage()),
              routes: [
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
          builder: (_, __) => const OnboardingPage(),
        ),
        GoRoute(
          path: chatUnlock,
          builder: (_, __) => const SensitiveScreen(child: ChatUnlockPage()),
        ),
        GoRoute(
          path: setup,
          // The master password is typed and the recovery key is shown here.
          builder: (_, __) =>
              const SensitiveScreen(child: MasterPasswordSetupPage()),
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
        // Each flow marks its own private steps (typing, opened content).
        GoRoute(
          path: lockFor,
          builder: (_, state) => LockPage(
            payload: LockPagePayload.fromRoute(
              state.extra,
              state.uri.queryParameters['chat'],
            ),
          ),
        ),
        GoRoute(
          path: lockWithPassword,
          builder: (_, __) =>
              const LockPage(payload: LockPagePayload.password()),
        ),
        GoRoute(
          path: open,
          builder: (_, state) =>
              OpenPage(payload: OpenPagePayload.fromRoute(state.extra)),
        ),
        GoRoute(
          path: aboutEncryption,
          builder: (_, __) => const AboutEncryptionPage(),
        ),
        GoRoute(
          path: auth,
          // Password change and a new recovery key are shown here.
          builder: (_, __) => const SensitiveScreen(child: FuzzyUserAuthPage()),
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
