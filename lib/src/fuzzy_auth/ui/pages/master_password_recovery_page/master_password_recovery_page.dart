import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// "Forgot your password?": the recovery key sets a new master password.
/// Functional screen in the current kit; the redesign restyles it.
class MasterPasswordRecoveryPage extends StatelessWidget {
  const MasterPasswordRecoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MasterPasswordRecoveryCubit>(
      create: (_) => MasterPasswordRecoveryCubit(
        chatAuthRepository: sl.get<ChatAuthRepository>(),
        fuzzyAuthStore: sl.get<FuzzyAuthStore>(),
        passwordStrengthService: sl.get<PasswordStrengthService>(),
      ),
      child: const _MasterPasswordRecoveryView(),
    );
  }
}

class _MasterPasswordRecoveryView extends StatefulWidget {
  const _MasterPasswordRecoveryView();

  @override
  State<_MasterPasswordRecoveryView> createState() =>
      _MasterPasswordRecoveryViewState();
}

class _MasterPasswordRecoveryViewState
    extends State<_MasterPasswordRecoveryView> {
  final _recoveryKeyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _recoveryKeyController,
      _passwordController,
      _confirmController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _recoveryKeyController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isReady =>
      _recoveryKeyController.text.trim().isNotEmpty &&
      NewPasswordFields.isReady(
        password: _passwordController.text,
        confirm: _confirmController.text,
      );

  void _onRecover() {
    if (!_isReady) return;
    context.read<MasterPasswordRecoveryCubit>().recover(
          recoveryKey: _recoveryKeyController.text,
          newPassword: _passwordController.text,
        );
  }

  String? _errorOf(MasterPasswordRecoveryState state) {
    final localizations = context.fuzzzyInkLocalizations;
    if (!state.status.isFailed || state.tooWeak) return null;
    return switch (state.failureType) {
      CryptoCoreFailureType.corrupt => localizations.recoveryKeyTypo,
      CryptoCoreFailureType.wrongPassword => localizations.recoveryKeyWrong,
      _ => localizations.unknownError,
    };
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;

    return BlocBuilder<MasterPasswordRecoveryCubit,
        MasterPasswordRecoveryState>(
      builder: (context, state) {
        final isLoading = state.status.isLoading;
        final error = _errorOf(state);

        return Scaffold(
          backgroundColor: colors.ground,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(space.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FuzzzyIconButton(
                      icon: const Icon(Icons.arrow_back),
                      semanticLabel: localizations.cancel,
                      qaId: 'recover.back',
                      onPressed: isLoading
                          ? null
                          : () => context.go(AppRouter.chatUnlock),
                    ),
                  ),
                  SizedBox(height: space.l),
                  Text(
                    localizations.recoveryTitle,
                    style: context.fuzzzyTextStyles.titleL
                        .copyWith(color: colors.ink),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: space.m),
                  Text(
                    localizations.recoveryDescription,
                    style: context.fuzzzyTextStyles.body
                        .copyWith(color: colors.inkMute),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: space.xl),
                  FuzzzyTextField(
                    controller: _recoveryKeyController,
                    label: localizations.recoveryKeyField,
                    hint: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
                    errorText: error,
                    qaId: 'recover.key',
                  ),
                  SizedBox(height: space.l),
                  NewPasswordFields(
                    passwordController: _passwordController,
                    confirmController: _confirmController,
                    label: localizations.chatAuthNewPassword,
                    onSubmitted: _onRecover,
                    qaId: 'recover',
                  ),
                  SizedBox(height: space.xl),
                  FuzzzyButton(
                    label: localizations.recoverySubmit,
                    qaId: 'recover.submit',
                    loading: isLoading,
                    onPressed: _isReady && !isLoading ? _onRecover : null,
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
