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

  /// A person's page: `?chat=<chat id>` (see `PersonPage.location`).
  static const person = '/person';
  static const personItem = '/person/item';
  static const personConnected = '/person/connected';
  static const personAnsweredTwice = '/person/answered-twice';
  static const personChecked = '/person/checked';

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

  /// Screens that show a secret or plain text: not returned to after a
  /// lock. Their parent comes back instead (the person, My safe, Home).
  static const _privateRoutes = {
    vaultItem,
    vaultItemEditor,
    personItem,
    lockFor,
    lockWithPassword,
    open,
    basics,
    settingsMasterPassword,
    settingsRecoveryKey,
    settingsSafePassword,
  };

  /// Where the app was when it locked, private screens left out; restored
  /// by [returnAfterUnlock].
  static RouteMatchList? _returnPlace;

  /// Remembers where the app is as it locks (QA 2026-10-26: after an
  /// auto-lock, unlocking went to Home). The screens on top that are
  /// private are dropped first, so nothing they held is kept while locked.
  static void rememberReturnPlace(GoRouter router) {
    var place = router.routerDelegate.currentConfiguration;
    if (place.isEmpty ||
        _unprotectedRoutes.contains(place.uri.path) ||
        place.uri.path == onboarding) {
      return;
    }
    while (place.isNotEmpty && _holdsPrivate(place.matches)) {
      place = place.remove(place.last);
    }
    _returnPlace = place.isEmpty ? null : place;
  }

  /// Back to where the app was when it locked, or Home.
  static void returnAfterUnlock(GoRouter router) {
    final place = _returnPlace;
    _returnPlace = null;
    if (place == null) {
      router.go(home);
    } else {
      router.restore(place);
    }
  }

  /// Forgets the place (the first run, an erase).
  static void forgetReturnPlace() => _returnPlace = null;

  static bool _holdsPrivate(List<RouteMatchBase> matches) => matches.any(
        (match) => match is ShellRouteMatch
            ? _holdsPrivate(match.matches)
            : _privateRoutes.contains(Uri.parse(match.matchedLocation).path),
      );

  @visibleForTesting
  static RouteMatchList? get debugReturnPlace => _returnPlace;

  static GoRouter? _routerInstance;

  static GoRouter? get routerInstance => _routerInstance;

  /// Lets a test stand its own router in for [routerInstance].
  @visibleForTesting
  static GoRouter? get debugRouterInstance => _routerInstance;

  @visibleForTesting
  static set debugRouterInstance(GoRouter? router) => _routerInstance = router;

  static final _homeNavigatorKey = GlobalKey<NavigatorState>();
  static final _vaultNavigatorKey = GlobalKey<NavigatorState>();
  static final _settingsNavigatorKey = GlobalKey<NavigatorState>();

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

        // The welcome comes first and is final while unseen: falling
        // through to the first-run rule below would send it to /setup,
        // which sends it back here (a redirect loop, QA 2026-10-26).
        if (!hasSeenOnboarding) return isOnboarding ? null : onboarding;
        if (isOnboarding) return AppRouter.home;

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
        // The three tabs, each kept alive with its own stack (its place is
        // still there after a switch). Every other page is a full-screen
        // route below.
        StatefulShellRoute(
          builder: (context, state, navigationShell) {
            return MainShellPage(
              preferencesService: sl.get<PreferencesService>(),
              navigationShell: navigationShell,
            );
          },
          navigatorContainerBuilder: MainShellPage.tabStack,
          branches: [
            StatefulShellBranch(
              navigatorKey: _homeNavigatorKey,
              routes: [
                GoRoute(
                  path: home,
                  builder: (_, __) => const HomePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _vaultNavigatorKey,
              routes: [
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
                        final payload =
                            state.extra! as VaultItemEditorPagePayload;
                        return SensitiveScreen(
                          child: VaultItemEditorPage(payload: payload),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _settingsNavigatorKey,
              routes: [
                GoRoute(
                  path: settings,
                  builder: (_, __) => const SettingsPage(),
                ),
              ],
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
          builder: (_, state) =>
              ChatCreationPage(prefillName: state.extra as String?),
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
          path: person,
          builder: (_, state) => PersonPage.fromState(state),
        ),
        GoRoute(
          path: personItem,
          // Private items wrap themselves in a SensitiveScreen.
          builder: (_, state) => HistoryItemPage(
            payload: state.extra! as HistoryItemPagePayload,
          ),
        ),
        GoRoute(
          path: personConnected,
          builder: (_, state) =>
              PersonConnectedPage(chat: state.extra! as ChatGeneralData),
        ),
        GoRoute(
          path: personAnsweredTwice,
          builder: (_, state) =>
              AnsweredTwicePage(chat: state.extra! as ChatGeneralData),
        ),
        GoRoute(
          path: personChecked,
          builder: (_, state) =>
              PersonCheckedPage(chat: state.extra! as ChatGeneralData),
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
