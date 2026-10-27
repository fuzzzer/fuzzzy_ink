import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "It's really Tamar" (DESIGN.md section 4.3, prototype `checked`): the
/// numbers matched and are saved. The shield check draws (or Fuzzz is in
/// love), the Checked chip rises into place, one medium buzz. Done opens
/// Tamar's page, where the chip stands where the banner was.
class PersonCheckedPage extends StatefulWidget {
  const PersonCheckedPage({super.key, required this.chat});

  final ChatGeneralData chat;

  @override
  State<PersonCheckedPage> createState() => _PersonCheckedPageState();
}

class _PersonCheckedPageState extends State<PersonCheckedPage> {
  bool _showChip = false;

  @override
  void initState() {
    super.initState();
    unawaited(InkHaptics.medium());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showChip = true);
    });
  }

  void _done() =>
      PersonPage.goTo(context, widget.chat.chatId, justChecked: true);

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    return FlowScaffold(
      qaId: 'checked',
      leading: FlowLeading.close,
      onLeading: _done,
      footer: FuzzzyButton(
        qaId: 'checked.done',
        label: localizations.itemDone,
        onPressed: _done,
      ),
      children: [
        const InkHeroSlot(
          qaId: 'checked',
          moment: FuzzzyCastMoment.checked,
          glyph: HeroGlyph(
            tone: HeroGlyphTone.inverted,
            drawCheck: true,
            qaId: 'checked',
          ),
        ),
        InkScreenTitle(
          localizations.checkedTitle(widget.chat.chatName),
          large: true,
        ),
        SizedBox(height: context.fuzzzySpace.m),
        Center(
          child: ChipSwap(
            child: _showChip
                ? const PersonTrustChip(
                    key: ValueKey('checked'),
                    trust: PersonTrust.checked,
                    qaId: 'checked',
                  )
                : const SizedBox(key: ValueKey('none'), height: 24),
          ),
        ),
      ],
    );
  }
}
