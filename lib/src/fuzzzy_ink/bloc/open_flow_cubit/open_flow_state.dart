part of 'open_flow_cubit.dart';

/// What Open was given.
sealed class OpenRequest {
  const OpenRequest();
}

/// Pasted text (read from the clipboard only on the tap), or a pasted link.
class OpenPastedText extends OpenRequest {
  const OpenPastedText(this.text);

  final String text;
}

/// A chosen or dropped file.
class OpenChosenFile extends OpenRequest {
  const OpenChosenFile(this.filePath);

  final String filePath;
}

/// A tapped message link: the blob only. It is recognised (nothing spent)
/// and opened only when the person taps Open (security review 2026-10-26).
class OpenMessageLink extends OpenRequest {
  const OpenMessageLink({required this.encryptedMessage});

  /// The blob without its `Fuzz/` prefix.
  final String encryptedMessage;
}

enum OpenPhase {
  choose,
  reading,
  working,
  password,

  /// A message that came by link, recognised and waiting for the person's
  /// Open: "Open the message from {name}?".
  confirmMessage,
  openedText,
  openedFile,
  problem;

  bool get isBusy => this == reading || this == working;
}

/// The "can't open" screens (DESIGN.md section 7, errors).
enum OpenProblem {
  alreadyOpened,
  notFromYourPeople,
  damaged,
  tooOld,
  newerApp,
  ownInvite,
  alreadyConnected,
  notFuzzzy,
  stillArriving,

  /// A file whose message is spent but did not open: only a resend helps.
  askResend,
  failed,
}

/// Where Open hands over to the adding-a-person flow.
sealed class OpenRoute {
  const OpenRoute();
}

/// An invite from someone else: "Who sent it?" next.
class OpenRouteInvite extends OpenRoute {
  const OpenRouteInvite(this.invitation);

  final String invitation;
}

/// The reply to an invite this phone sent: finish connecting.
class OpenRouteReply extends OpenRoute {
  const OpenRouteReply({required this.chat, required this.acceptance});

  final ChatGeneralData chat;
  final String acceptance;
}

/// A second, different reply to an invite already answered: the
/// "someone else may have answered" warning.
class OpenRouteSecondReply extends OpenRoute {
  const OpenRouteSecondReply(this.chat);

  final ChatGeneralData chat;
}

/// A password item waiting for its password.
class PendingPasswordItem {
  const PendingPasswordItem.text(String this.text) : filePath = null;

  const PendingPasswordItem.file(String this.filePath) : text = null;

  final String? text;
  final String? filePath;
}

/// An opened file: a person's file is kept locked ([keptRow], opened again
/// on demand); a password file is one hand-off copy ([plainPath]) that lives
/// only while it is shown.
class OpenedFile {
  const OpenedFile({required this.name, this.keptRow, this.plainPath});

  final String name;
  final MessageData? keptRow;
  final String? plainPath;

  OpenedFile withKeptRow(MessageData row) =>
      OpenedFile(name: name, keptRow: row, plainPath: plainPath);
}

class OpenFlowState {
  const OpenFlowState({
    this.phase = OpenPhase.choose,
    this.chat,
    this.openedText,
    this.openedFile,
    this.historyRowId,
    this.problem,
    this.route,
    this.progress = 0,
    this.workingName,
    this.pendingPassword,
    this.isPasswordWrong = false,
    this.isBusy = false,
    this.pendingMessage,
  });

  final OpenPhase phase;

  /// The person it came from, when there is one.
  final ChatGeneralData? chat;

  /// Opened text: shown, never copyable; kept only in the sealed history.
  final String? openedText;
  final OpenedFile? openedFile;

  /// The new row in the person's history (the glow on their page).
  final int? historyRowId;
  final OpenProblem? problem;

  /// One-shot: the page leaves for another flow.
  final OpenRoute? route;
  final double progress;
  final String? workingName;
  final PendingPasswordItem? pendingPassword;
  final bool isPasswordWrong;
  final bool isBusy;

  /// The `Fuzz/` blob [OpenPhase.confirmMessage] waits to open.
  final String? pendingMessage;

  OpenFlowState copyWith({
    double? progress,
    bool? isPasswordWrong,
    bool? isBusy,
    int? historyRowId,
    OpenedFile? openedFile,
  }) {
    return OpenFlowState(
      phase: phase,
      chat: chat,
      openedText: openedText,
      openedFile: openedFile ?? this.openedFile,
      historyRowId: historyRowId ?? this.historyRowId,
      problem: problem,
      route: route,
      progress: progress ?? this.progress,
      workingName: workingName,
      pendingPassword: pendingPassword,
      isPasswordWrong: isPasswordWrong ?? this.isPasswordWrong,
      isBusy: isBusy ?? this.isBusy,
      pendingMessage: pendingMessage,
    );
  }

  // Never the opened text: states end up in logs.
  @override
  String toString() =>
      'OpenFlowState($phase, problem: $problem, route: ${route.runtimeType}, '
      'progress: $progress, wrong: $isPasswordWrong, busy: $isBusy)';
}
