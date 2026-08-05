import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/data_uri_image.dart';
import '../../core/widgets/image_pick_sheet.dart';
import '../../core/widgets/picked_image.dart';
import '../../core/widgets/status_views.dart';
import 'advanced_ai_cubit.dart';

/// Free-form streaming AI chat (cloud Nemotron via `/v1/openrouter-chat`).
class AdvancedAiScreen extends StatelessWidget {
  const AdvancedAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AdvancedAiCubit(ctx.read<ApiClient>()),
      child: const _AdvancedAiView(),
    );
  }
}

class _AdvancedAiView extends StatefulWidget {
  const _AdvancedAiView();
  @override
  State<_AdvancedAiView> createState() => _AdvancedAiViewState();
}

class _AdvancedAiViewState extends State<_AdvancedAiView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  XFile? _attached;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _attach() async {
    final file = await pickImage(context);
    if (file != null) setState(() => _attached = file);
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty && _attached == null) return;
    // The server picks its system prompt — and the language it answers in —
    // from this, so it has to follow the app's locale.
    context.read<AdvancedAiCubit>().send(
      text,
      image: _attached,
      lang: context.locale.languageCode == 'ar' ? 'ar' : 'en',
    );
    _input.clear();
    setState(() => _attached = null);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdvancedAiCubit, AdvancedAiState>(
      listener: (ctx, state) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: state.turns.isEmpty
                  ? const EmptyView(
                      message: 'Ask the AI anything.',
                      icon: Icons.auto_awesome,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.turns.length,
                      itemBuilder: (ctx, i) => _Bubble(turn: state.turns[i]),
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_attached != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: 72,
                                width: 72,
                                child: PickedImage(file: _attached!),
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: IconButton(
                                icon: const Icon(Icons.cancel, size: 20),
                                onPressed: () =>
                                    setState(() => _attached = null),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Attach image',
                          onPressed: state.streaming ? null : _attach,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            onSubmitted: (_) =>
                                state.streaming ? null : _send(),
                            decoration: const InputDecoration(
                              hintText: 'Message…',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          onPressed: state.streaming ? null : _send,
                          child: state.streaming
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                        ),
                      ],
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});
  final AiTurn turn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = turn.isUser;

    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // The model's working, above its answer and collapsed by default.
            if (!isUser && turn.hasThinking) _ThinkingPanel(turn: turn),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: isUser
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (turn.imageDataUrl != null) ...[
                          DataUriImage(
                            dataUri: turn.imageDataUrl!,
                            height: 160,
                          ),
                          if (turn.content.isNotEmpty)
                            const SizedBox(height: 6),
                        ],
                        if (turn.content.isNotEmpty)
                          Text(
                            turn.content,
                            style: TextStyle(color: scheme.onPrimary),
                          ),
                      ],
                    )
                  : (turn.content.isEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                turn.isThinking ? 'Thinking…' : 'Working…',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          )
                        : MarkdownBody(data: turn.content)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible view of the model's chain of thought.
///
/// Expanded while it is still arriving — watching it work is reassuring on a
/// slow answer — then collapsed once the reply itself starts, since the answer
/// is what the user actually wants.
class _ThinkingPanel extends StatelessWidget {
  const _ThinkingPanel({required this.turn});
  final AiTurn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = turn.isThinking;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Theme(
        // Hide the divider lines an ExpansionTile draws by default.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('think-$live'),
          initiallyExpanded: live,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            Icons.psychology_outlined,
            size: 18,
            color: theme.colorScheme.outline,
          ),
          title: Text(
            live ? 'Thinking…' : 'Reasoning',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                turn.thinking.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
