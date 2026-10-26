import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "What's the password?" for a password-locked text or file (private). A
/// wrong one turns the field red with one short line, no shake, one firm
/// buzz (DESIGN.md section 10, "Wrong password").
class OpenPasswordView extends StatefulWidget {
  const OpenPasswordView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<OpenPasswordView> createState() => _OpenPasswordViewState();
}

class _OpenPasswordViewState extends State<OpenPasswordView> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _open() =>
      context.read<OpenFlowCubit>().openWithPassword(_password.text);

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    return BlocConsumer<OpenFlowCubit, OpenFlowState>(
      listenWhen: (previous, current) =>
          !previous.isPasswordWrong && current.isPasswordWrong,
      listener: (_, __) => InkHaptics.heavy(),
      builder: (context, state) => InkFlowScaffold(
        qaId: 'open.password',
        title: localizations.openLockedWithPassword,
        onLeading: widget.onBack,
        footer: FuzzzyButton(
          label: localizations.open,
          icon: const Icon(Icons.lock_open_outlined),
          size: FuzzzyButtonSize.l,
          loading: state.isBusy,
          qaId: 'open.password.open',
          onPressed: _open,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FlowHero(
              glyph: HeroGlyph(
                icon: Icons.key_outlined,
                qaId: 'open.password.glyph',
              ),
            ),
            FlowTitle(title: localizations.openPasswordTitle),
            SizedBox(height: context.fuzzzySpace.l),
            FuzzzyTextField(
              controller: _password,
              label: localizations.openPasswordLabel,
              obscure: true,
              autofocus: true,
              errorText: state.isPasswordWrong
                  ? localizations.openPasswordWrong
                  : null,
              onSubmitted: (_) => _open(),
              qaId: 'open.password',
            ),
          ],
        ),
      ),
    );
  }
}
