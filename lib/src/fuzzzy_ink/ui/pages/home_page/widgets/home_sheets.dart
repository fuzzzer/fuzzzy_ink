import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// "Add a person": Send an invite (You start) · I got an invite (They
/// started).
Future<void> showAddPersonSheet(BuildContext context) {
  final localizations = context.fuzzzyInkLocalizations;
  return FuzzzyBottomSheet.show<void>(
    context,
    qaId: 'addPerson',
    builder: (sheetContext) => FuzzzyBottomSheet(
      qaId: 'addPerson',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetTitle(localizations.homeAddPerson),
          SheetDoorRow(
            qaId: 'addPerson.send',
            icon: Icons.ios_share,
            emphasised: true,
            title: localizations.addSendInvite,
            hint: localizations.addYouStart,
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push(AppRouter.chatCreate);
            },
          ),
          SheetDoorRow(
            qaId: 'addPerson.got',
            icon: Icons.move_to_inbox_outlined,
            title: localizations.addGotInvite,
            hint: localizations.addTheyStarted,
            divider: false,
            onTap: () {
              Navigator.of(sheetContext).pop();
              context.push(AppRouter.chatAccept);
            },
          ),
        ],
      ),
    ),
  );
}

/// Lock → "Who's it for?" (step 1 of 2): connected people (waiting ones
/// shown but off), then "Lock with a password". With no one connected, "Add
/// a person first". A person goes on to `AppRouter.lockFor`.
Future<void> showLockWhoSheet(
  BuildContext context, {
  required List<ChatGeneralData> people,
  required Set<String> unverifiedChatIds,
}) {
  final localizations = context.fuzzzyInkLocalizations;
  final connected = people
      .where((chat) => chat.setupStatus == ChatSetupStatus.connected)
      .toList();
  final waiting = people
      .where((chat) => chat.setupStatus != ChatSetupStatus.connected)
      .toList();

  return FuzzzyBottomSheet.show<void>(
    context,
    qaId: 'lockWho',
    builder: (sheetContext) {
      void close() => Navigator.of(sheetContext).pop();

      return FuzzzyBottomSheet(
        qaId: 'lockWho',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepsIndicator(
              step: 1,
              total: 2,
              label: localizations.lockStepWho,
              qaId: 'lockWho.steps',
            ),
            SizedBox(height: sheetContext.fuzzzySpace.s),
            _SheetTitle(localizations.lockWhoTitle),
            for (final chat in connected)
              _PersonChoice(
                chat: chat,
                trust: HomePage.trustOf(chat, unverifiedChatIds),
                onTap: () {
                  close();
                  context.push(
                    AppRouter.lockFor,
                    extra: LockPagePayload(chat: chat),
                  );
                },
              ),
            for (final chat in waiting)
              _PersonChoice(
                chat: chat,
                trust: PersonTrust.waiting,
                onTap: null,
              ),
            if (connected.isEmpty) ...[
              SizedBox(height: sheetContext.fuzzzySpace.m),
              FuzzzyButton(
                label: localizations.lockAddPersonFirst,
                icon: const Icon(Icons.person_add_alt),
                qaId: 'lockWho.addFirst',
                onPressed: () {
                  close();
                  showAddPersonSheet(context);
                },
              ),
            ],
            const _OrDivider(),
            SheetDoorRow(
              qaId: 'lockWho.password',
              icon: Icons.key_outlined,
              title: localizations.lockWithPassword,
              hint: localizations.lockNoInviteNeeded,
              divider: false,
              onTap: () {
                close();
                context.push(AppRouter.lockWithPassword);
              },
            ),
          ],
        ),
      );
    },
  );
}

/// A door in a sheet: icon box, title, one hint line, chevron.
class SheetDoorRow extends StatelessWidget {
  const SheetDoorRow({
    super.key,
    required this.qaId,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
    this.emphasised = false,
    this.divider = true,
    this.trailing,
  });

  final String qaId;
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? onTap;
  final bool emphasised;
  final bool divider;

  /// In place of the chevron: the iPhone's own Paste button on a paste row
  /// ([InkPasteButton]).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;

    return Semantics(
      identifier: qaId,
      button: true,
      container: true,
      child: FuzzzyTappable(
        key: Key(qaId),
        onTap: onTap,
        focusRingInset: true,
        builder: (context, active) => Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: EdgeInsets.symmetric(vertical: space.m),
          decoration: BoxDecoration(
            color: active ? colors.surface : null,
            border:
                divider ? Border(bottom: BorderSide(color: colors.line)) : null,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: emphasised ? colors.actionPrimaryBg : colors.surface,
                    border: Border.all(
                      color: emphasised ? colors.actionPrimaryBg : colors.line,
                    ),
                    borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
                  ),
                  child: Icon(
                    icon,
                    size: context.fuzzzyIconSize.l,
                    color: emphasised ? colors.actionPrimaryFg : colors.ink,
                  ),
                ),
              ),
              SizedBox(width: space.m + space.xs / 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: type.titleS.copyWith(color: colors.ink)),
                    Text(
                      hint,
                      style: type.bodyS.copyWith(color: colors.inkMute),
                    ),
                  ],
                ),
              ),
              if (trailing case final trailing?) ...[
                SizedBox(width: space.s),
                trailing,
              ] else
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    size: context.fuzzzyIconSize.m,
                    color: colors.inkFaint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonChoice extends StatelessWidget {
  const _PersonChoice({
    required this.chat,
    required this.trust,
    required this.onTap,
  });

  final ChatGeneralData chat;
  final PersonTrust trust;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final name = chat.chatName.trim();
    final isOff = onTap == null;

    return Semantics(
      identifier: 'lockWho.${chat.chatId}',
      button: true,
      enabled: !isOff,
      container: true,
      child: Opacity(
        opacity: isOff ? 0.5 : 1,
        child: FuzzzyTappable(
          key: Key('lockWho.${chat.chatId}'),
          onTap: onTap,
          focusRingInset: true,
          builder: (context, active) => Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: EdgeInsets.symmetric(vertical: space.m),
            decoration: BoxDecoration(
              color: active ? colors.surface : null,
              border: Border(bottom: BorderSide(color: colors.line)),
            ),
            child: Row(
              children: [
                FuzzzyAvatar(
                  initials:
                      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  size: FuzzzyAvatarSize.s44,
                ),
                SizedBox(width: space.m + space.xs / 2),
                Expanded(
                  child: Text(
                    chat.chatName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.fuzzzyTextStyles.titleS.copyWith(
                      color: colors.ink,
                    ),
                  ),
                ),
                PersonTrustChip(trust: trust),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.fuzzzySpace.s),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: context.fuzzzyTextStyles.titleL.copyWith(
            color: context.fuzzzyColors.ink,
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final line = Expanded(child: Divider(color: colors.line, height: 1));

    return Padding(
      padding: EdgeInsets.only(top: space.l, bottom: space.xs),
      child: Row(
        children: [
          line,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: space.m),
            child: Text(
              context.fuzzzyInkLocalizations.orDivider.toUpperCase(),
              style: context.fuzzzyTextStyles.label.copyWith(
                color: colors.inkFaint,
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}
