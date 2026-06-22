import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/register_cubit.dart';

/// Email OTP verification. Expects to be hosted under an existing
/// [RegisterCubit] (provided by the onboarding wizard) that already holds the
/// captured email + password for auto-login after verification.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _verify() {
    if (_code.text.trim().length < 4) return;
    context.read<RegisterCubit>().verifyOtpAndLogin(_code.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('otp_title'))),
      body: BlocConsumer<RegisterCubit, RegisterState>(
        listener: (ctx, state) {
          if (state.status == RegisterStatus.success && state.result != null) {
            ctx.read<AuthCubit>().onAuthenticated(state.result!);
            // Auth redirect takes over; close the auth sub-flow.
            Navigator.of(ctx).popUntil((r) => r.isFirst);
          } else if (state.error != null &&
              state.status == RegisterStatus.awaitingOtp) {
            ScaffoldMessenger.of(ctx)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (ctx, state) {
          final busy = state.status == RegisterStatus.verifying;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('otp_subtitle'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (state.email != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        state.email!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                        labelText: context.tr('otp_code'),
                      ),
                      onSubmitted: (_) => _verify(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : _verify,
                      child: busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(context.tr('verify')),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
