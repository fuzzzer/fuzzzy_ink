import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// The first run after the welcome (DESIGN.md section 4.1, prototype
/// `ob-password`, `ob-recovery`, `ob-bio`, `ob-ready`): the master password
/// (step 1), the recovery key (step 2), the fingerprint shortcut (step 3,
/// only with strong biometrics), then "You're ready". The password and
/// recovery-key steps are private screens; the other two are not, so
/// Fuzzzy Cast can greet on "You're ready".
class MasterPasswordSetupPage extends StatelessWidget {
  const MasterPasswordSetupPage({super.key, this.export});

  /// Print and Save as file for the recovery key (tests pass a fake).
  final RecoveryKeyExport? export;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MasterPasswordSetupCubit>(
      create: (_) => MasterPasswordSetupCubit(
        chatAuthRepository: sl.get<ChatAuthRepository>(),
        appResetRepository: sl.get<AppResetRepository>(),
        fuzzyAuthStore: sl.get<FuzzyAuthStore>(),
        passwordStrengthService: sl.get<PasswordStrengthService>(),
        biometricAuthRepository: sl.get<BiometricAuthRepository>(),
        preferencesService: sl.get<PreferencesService>(),
      )..checkQuickUnlock(),
      child: MasterPasswordSetupView(export: export),
    );
  }
}

/// The steps themselves, below a [MasterPasswordSetupCubit].
class MasterPasswordSetupView extends StatefulWidget {
  const MasterPasswordSetupView({super.key, this.export});

  final RecoveryKeyExport? export;

  @override
  State<MasterPasswordSetupView> createState() =>
      _MasterPasswordSetupViewState();
}

class _MasterPasswordSetupViewState extends State<MasterPasswordSetupView> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _understood = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_rebuild);
    _confirmController.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isReady =>
      _understood &&
      NewPasswordFields.isReady(
        password: _passwordController.text,
        confirm: _confirmController.text,
      );

  void _onCreate() {
    if (!_isReady) return;
    context.read<MasterPasswordSetupCubit>().create(_passwordController.text);
  }

  /// Back from the first step: the welcome's "How it works" again.
  Future<void> _onBack() async {
    await sl.get<PreferencesService>().setHasSeenOnboarding(false);
    if (mounted) context.go(AppRouter.onboarding, extra: 1);
  }

  Future<void> _onFinish({required bool addPerson}) async {
    await context.read<MasterPasswordSetupCubit>().finish();
    if (!mounted) return;
    context.go(AppRouter.home);
    if (addPerson) {
      unawaited(
        runOnTopScreen(showAddPersonSheet),
      );
    }
  }

  void _onStateChanged(BuildContext context, MasterPasswordSetupState state) {
    final localizations = context.fuzzzyInkLocalizations;
    if (state.step != MasterPasswordSetupStep.password &&
        state.step != MasterPasswordSetupStep.recoveryKey &&
        state.step != MasterPasswordSetupStep.quickUnlock) {
      // The password is needed up to the fingerprint step, never after.
      _passwordController.clear();
    }
    if (state.step == MasterPasswordSetupStep.recoveryKey) {
      _confirmController.clear();
    }
    if (!state.status.isFailed) return;
    if (state.failureType != null) {
      showInkToast(
        context,
        message: localizations.masterPasswordFailed,
        kind: FuzzzyToastKind.error,
      );
    }
    final quickUnlockResult = state.quickUnlockResult;
    if (quickUnlockResult != null) {
      showInkToast(
        context,
        message: quickUnlockResult == BiometricEnableResult.notStrongEnough
            ? localizations.biometricNotStrongEnough
            : localizations.biometricNotTurnedOn,
        kind: FuzzzyToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MasterPasswordSetupCubit, MasterPasswordSetupState>(
      listener: _onStateChanged,
      builder: (context, state) {
        final recoveryKey = state.recoveryKey;
        return switch (state.step) {
          MasterPasswordSetupStep.password =>
            SensitiveScreen(child: _passwordStep(context, state)),
          MasterPasswordSetupStep.recoveryKey when recoveryKey != null =>
            SensitiveScreen(
              child: _recoveryKeyStep(context, state, recoveryKey),
            ),
          MasterPasswordSetupStep.recoveryKey =>
            const ColoredBox(color: Colors.transparent),
          MasterPasswordSetupStep.quickUnlock =>
            _quickUnlockStep(context, state),
          MasterPasswordSetupStep.ready ||
          MasterPasswordSetupStep.done =>
            _readyStep(context, state),
        };
      },
    );
  }

  Widget _steps(
    BuildContext context,
    MasterPasswordSetupState state,
    int step,
    String label,
  ) =>
      StepsIndicator(
        step: step,
        total: state.totalSteps,
        label: label,
        qaId: 'setup',
      );

  Widget _passwordStep(BuildContext context, MasterPasswordSetupState state) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final isLoading = state.status.isLoading;
    final previousDataFound =
        context.select<FuzzyAuthStore, bool>((s) => s.state.previousDataFound);

    return AccessPage(
      qaId: 'setup.password',
      onBack: isLoading ? null : _onBack,
      bottom: [
        FuzzzyButton(
          label: isLoading
              ? localizations.chatAuthResecuringKeys
              : localizations.accessContinue,
          size: FuzzzyButtonSize.l,
          loading: isLoading,
          qaId: 'setup.create',
          onPressed: _isReady && !isLoading ? _onCreate : null,
        ),
      ],
      children: [
        _steps(context, state, 1, localizations.accessStepPassword),
        SizedBox(height: space.l),
        AccessTitle(localizations.accessMakeMasterPassword),
        if (state.interruptedBefore) ...[
          SizedBox(height: space.m),
          AccessNote(
            tone: AccessNoteTone.warning,
            text: localizations.accessSetupInterrupted,
            qaId: 'setup.interrupted',
          ),
        ] else if (previousDataFound) ...[
          SizedBox(height: space.m),
          AccessNote(
            tone: AccessNoteTone.warning,
            text: localizations.masterPasswordPreviousData,
            qaId: 'setup.previousData',
          ),
        ],
        SizedBox(height: space.l),
        NewPasswordFields(
          passwordController: _passwordController,
          confirmController: _confirmController,
          label: localizations.masterPassword,
          onSubmitted: _onCreate,
          qaId: 'setup',
        ),
        SizedBox(height: space.l),
        AccessNote(
          tone: AccessNoteTone.danger,
          bold: localizations.accessNoResetBold,
          text: localizations.accessNoResetLine,
          trailing: const WhyLink(topic: InkInfoTopic.noReset),
          qaId: 'setup.noReset',
        ),
        SizedBox(height: space.m),
        FuzzzyCheckbox(
          value: _understood,
          label: localizations.accessUnderstandNoAccess,
          qaId: 'setup.understand',
          onChanged:
              isLoading ? null : (value) => setState(() => _understood = value),
        ),
      ],
    );
  }

  Widget _recoveryKeyStep(
    BuildContext context,
    MasterPasswordSetupState state,
    String recoveryKey,
  ) {
    final localizations = context.fuzzzyInkLocalizations;
    final cubit = context.read<MasterPasswordSetupCubit>();
    return RecoveryKeyStepView(
      recoveryKey: recoveryKey,
      busy: state.status.isLoading,
      onKept: cubit.confirmRecoveryKeySaved,
      onSkipped: cubit.skipRecoveryKey,
      title: localizations.accessYourRecoveryKey,
      line: localizations.accessRecoverySpare,
      steps: _steps(context, state, 2, localizations.recoveryKeyTitle),
      export: widget.export ?? const RecoveryKeyExport(),
    );
  }

  Widget _quickUnlockStep(
    BuildContext context,
    MasterPasswordSetupState state,
  ) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final cubit = context.read<MasterPasswordSetupCubit>();
    final isLoading = state.status.isLoading;

    return AccessPage(
      qaId: 'setup.quickUnlock',
      bottom: [
        FuzzzyButton(
          label: localizations.accessUseBio,
          size: FuzzzyButtonSize.l,
          icon: const Icon(Icons.fingerprint),
          loading: isLoading,
          qaId: 'setup.useBio',
          onPressed: isLoading
              ? null
              : () async {
                  await cubit.enableQuickUnlock(_passwordController.text);
                  if (cubit.state.quickUnlockOn) {
                    unawaited(InkHaptics.light());
                  }
                },
        ),
        FuzzzyButton(
          label: localizations.accessNotNow,
          variant: FuzzzyButtonVariant.ghost,
          qaId: 'setup.notNow',
          onPressed: isLoading ? null : cubit.skipQuickUnlock,
        ),
      ],
      children: [
        _steps(context, state, 3, localizations.accessStepQuickUnlock),
        SizedBox(height: space.xl),
        const Center(
          child: HeroGlyph(icon: Icons.fingerprint, qaId: 'setup.bio'),
        ),
        SizedBox(height: space.l),
        AccessTitle(localizations.accessBioTitle, center: true),
        SizedBox(height: space.s),
        AccessLine(localizations.accessBioLine, center: true),
        SizedBox(height: space.l),
        TipLine(
          icon: Icons.schedule,
          text: localizations.accessBioTip,
          qaId: 'setup.autoLock',
        ),
      ],
    );
  }

  Widget _readyStep(BuildContext context, MasterPasswordSetupState state) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final isDone = state.step == MasterPasswordSetupStep.done;

    return AccessPage(
      qaId: 'setup.ready',
      bottom: [
        FuzzzyButton(
          label: localizations.accessAddFirstPerson,
          size: FuzzzyButtonSize.l,
          icon: const Icon(Icons.person_add_alt),
          qaId: 'setup.addFirst',
          onPressed: isDone ? null : () => _onFinish(addPerson: true),
        ),
        FuzzzyButton(
          label: localizations.accessLookAround,
          variant: FuzzzyButtonVariant.ghost,
          qaId: 'setup.lookAround',
          onPressed: isDone ? null : () => _onFinish(addPerson: false),
        ),
      ],
      children: [
        SizedBox(height: space.l),
        const Center(
          child: FuzzzyCastReaction(
            moment: FuzzzyCastMoment.turnedOn,
            fallback: HeroGlyph(
              tone: HeroGlyphTone.inverted,
              drawCheck: true,
              settle: true,
              qaId: 'setup.ready',
            ),
            qaId: 'setup.ready',
          ),
        ),
        SizedBox(height: space.l),
        AccessTitle(localizations.accessReadyTitle, center: true),
        SizedBox(height: space.xl),
        const FuzzzyCastCard(),
      ],
    );
  }
}

/// "You're ready"'s card: the Fuzzzy Cast switch (off by default) with its
/// one line.
class FuzzzyCastCard extends StatelessWidget {
  const FuzzzyCastCard({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final isOn = context.select<FuzzzyCastSettingsCubit, bool>(
      (cubit) => cubit.state.isEnabled,
    );

    return FuzzzyCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.fuzzzyCast,
                  style: context.fuzzzyTextStyles.titleS
                      .copyWith(color: colors.ink),
                ),
                SizedBox(height: context.fuzzzySpace.xs),
                Text(
                  localizations.fuzzzyCastLine,
                  style: context.fuzzzyTextStyles.bodyS
                      .copyWith(color: colors.inkMute),
                ),
              ],
            ),
          ),
          SizedBox(width: context.fuzzzySpace.m),
          Semantics(
            label: localizations.fuzzzyCast,
            child: FuzzzyToggle(
              value: isOn,
              qaId: 'setup.fuzzzyCast',
              onChanged: (value) {
                unawaited(InkHaptics.selection());
                context.read<FuzzzyCastSettingsCubit>().setEnabled(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
