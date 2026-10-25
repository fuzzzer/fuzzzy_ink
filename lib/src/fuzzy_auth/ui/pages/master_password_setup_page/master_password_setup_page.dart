import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The first run, right after onboarding: one master password, then the
/// recovery key. Functional screen in the current kit; the redesign
/// restyles it.
class MasterPasswordSetupPage extends StatelessWidget {
  const MasterPasswordSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MasterPasswordSetupCubit>(
      create: (_) => MasterPasswordSetupCubit(
        chatAuthRepository: sl.get<ChatAuthRepository>(),
        appResetRepository: sl.get<AppResetRepository>(),
        fuzzyAuthStore: sl.get<FuzzyAuthStore>(),
        passwordStrengthService: sl.get<PasswordStrengthService>(),
      ),
      child: const _MasterPasswordSetupView(),
    );
  }
}

class _MasterPasswordSetupView extends StatefulWidget {
  const _MasterPasswordSetupView();

  @override
  State<_MasterPasswordSetupView> createState() =>
      _MasterPasswordSetupViewState();
}

class _MasterPasswordSetupViewState extends State<_MasterPasswordSetupView> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isReady => NewPasswordFields.isReady(
        password: _passwordController.text,
        confirm: _confirmController.text,
      );

  void _onCreate() {
    if (!_isReady) return;
    context.read<MasterPasswordSetupCubit>().create(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final previousDataFound =
        context.watch<FuzzyAuthStore>().state.previousDataFound;

    return BlocConsumer<MasterPasswordSetupCubit, MasterPasswordSetupState>(
      listenWhen: (previous, current) =>
          current.status.isFailed && current.failureType != null,
      listener: (context, state) {
        FuzzzyToast.show(
          context,
          message: localizations.masterPasswordFailed,
          kind: FuzzzyToastKind.error,
        );
      },
      builder: (context, state) {
        final isLoading = state.status.isLoading;
        final recoveryKey = state.recoveryKey;

        return Scaffold(
          backgroundColor: colors.ground,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(space.l),
              child: recoveryKey != null &&
                      state.step == MasterPasswordSetupStep.recoveryKey
                  ? RecoveryKeyPanel(
                      recoveryKey: recoveryKey,
                      busy: isLoading,
                      onConfirmed: context
                          .read<MasterPasswordSetupCubit>()
                          .confirmRecoveryKeySaved,
                      onSkipped: context
                          .read<MasterPasswordSetupCubit>()
                          .skipRecoveryKey,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: space.xl),
                        Icon(Icons.key_rounded, size: 64, color: colors.ink),
                        SizedBox(height: space.l),
                        Text(
                          localizations.masterPasswordSetupTitle,
                          style: context.fuzzzyTextStyles.titleL
                              .copyWith(color: colors.ink),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: space.m),
                        Text(
                          localizations.masterPasswordSetupDescription,
                          style: context.fuzzzyTextStyles.body
                              .copyWith(color: colors.inkMute),
                          textAlign: TextAlign.center,
                        ),
                        if (previousDataFound) ...[
                          SizedBox(height: space.m),
                          Text(
                            localizations.masterPasswordPreviousData,
                            key: const ValueKey('setup.previousData'),
                            style: context.fuzzzyTextStyles.bodyS
                                .copyWith(color: colors.destructiveText),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        SizedBox(height: space.xl),
                        NewPasswordFields(
                          passwordController: _passwordController,
                          confirmController: _confirmController,
                          label: localizations.masterPassword,
                          onSubmitted: _onCreate,
                          qaId: 'setup',
                        ),
                        SizedBox(height: space.xl),
                        FuzzzyButton(
                          label: isLoading
                              ? localizations.masterPasswordCreating
                              : localizations.masterPasswordCreate,
                          qaId: 'setup.create',
                          loading: isLoading,
                          onPressed: _isReady && !isLoading ? _onCreate : null,
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
