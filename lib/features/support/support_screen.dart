import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/status_views.dart';
import '../auth/bloc/auth_cubit.dart';
import 'support_cubit.dart';

/// Live technical-support chat (1 credit per session).
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthCubit>().state.userId;
    if (uid == null) {
      return const EmptyView(message: 'Sign in to use support.');
    }
    return BlocProvider(
      create: (ctx) => SupportCubit(ctx.read<ApiClient>(), uid)..init(),
      child: const _SupportView(),
    );
  }
}

class _SupportView extends StatefulWidget {
  const _SupportView();
  @override
  State<_SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends State<_SupportView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    context.read<SupportCubit>().send(text);
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SupportCubit, SupportState>(
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: state.messages.isEmpty
                  ? const EmptyView(
                      message: 'Send a message to start a support chat.',
                      icon: Icons.support_agent,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.messages.length,
                      itemBuilder: (ctx, i) {
                        final m = state.messages[i];
                        final scheme = Theme.of(ctx).colorScheme;
                        return Align(
                          alignment: m.isUser
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(ctx).size.width * 0.78),
                            decoration: BoxDecoration(
                              color: m.isUser
                                  ? scheme.primary
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              m.message,
                              style: TextStyle(
                                  color: m.isUser ? scheme.onPrimary : null),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Type a message…',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton.small(
                      onPressed: _send,
                      child: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
