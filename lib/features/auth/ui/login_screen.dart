import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/settings/settings_cubit.dart';
import '../../../core/widgets/app_logo.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/login_cubit.dart';
import '../data/auth_repository.dart';
import '../data/google_auth_service.dart';
import 'onboarding_wizard.dart';

/// Email/username + password login, plus Google sign-in and a route into the
/// registration wizard. This screen is the auth entry point.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => LoginCubit(
        ctx.read<AuthRepository>(),
        ctx.read<GoogleAuthService>(),
      ),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<LoginCubit>().submit(_user.text, _pass.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocListener<LoginCubit, LoginState>(
          listenWhen: (a, b) => a.status != b.status,
          listener: (ctx, state) {
            if (state.status == LoginStatus.success && state.result != null) {
              ctx.read<AuthCubit>().onAuthenticated(state.result!);
            } else if (state.status == LoginStatus.googleNeedsOnboarding &&
                state.googleOnboarding != null) {
              Navigator.of(ctx).push(MaterialPageRoute(
                builder: (_) =>
                    OnboardingWizard(googleOnboarding: state.googleOnboarding),
              ));
            } else if (state.status == LoginStatus.failure) {
              ScaffoldMessenger.of(ctx)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text(state.error ?? ctx.tr('login_failed')),
                ));
            }
          },
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: () =>
                              context.read<SettingsCubit>().toggleLocale(),
                          icon: const Icon(Icons.language, size: 18),
                          label: Text(
                            context.locale.languageCode == 'ar'
                                ? 'EN'
                                : 'العربية',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(child: AppLogo(size: 84)),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('app_name'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _user,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.tr('email'),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? context.tr('required_field')
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pass,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: context.tr('password'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? context.tr('required_field')
                            : null,
                      ),
                      const SizedBox(height: 24),
                      BlocBuilder<LoginCubit, LoginState>(
                        builder: (ctx, state) {
                          final busy = state.status == LoginStatus.submitting;
                          return FilledButton(
                            onPressed: busy ? null : _submit,
                            child: busy
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(context.tr('login')),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      BlocBuilder<LoginCubit, LoginState>(
                        builder: (ctx, state) {
                          final busy =
                              state.status == LoginStatus.googleInProgress;
                          return OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => ctx.read<LoginCubit>().googleSignIn(),
                            icon: busy
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.g_mobiledata, size: 28),
                            label: Text(context.tr('login_with_google')),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OnboardingWizard(),
                          ),
                        ),
                        child: Text(context.tr('create_account')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

