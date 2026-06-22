import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/data_uri_image.dart';
import '../../core/widgets/image_pick_sheet.dart';
import '../../core/widgets/picked_image.dart';
import '../../core/widgets/status_views.dart';
import '../consultant/data/consultant_models.dart';
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
    context.read<AdvancedAiCubit>().send(text, image: _attached);
    _input.clear();
    setState(() => _attached = null);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AdvancedAiCubit, AdvancedAiState>(
      listener: (ctx, state) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: state.messages.isEmpty
                  ? const EmptyView(
                      message: 'Ask the AI anything.',
                      icon: Icons.auto_awesome,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.messages.length,
                      itemBuilder: (ctx, i) =>
                          _Bubble(message: state.messages[i]),
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
                                onPressed: () => setState(() => _attached = null),
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
                            onSubmitted: (_) => state.streaming ? null : _send(),
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
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
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Align(
      alignment:
          isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: isUser
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.imageDataUrl != null) ...[
                    DataUriImage(dataUri: message.imageDataUrl!, height: 160),
                    if (message.content.isNotEmpty) const SizedBox(height: 6),
                  ],
                  if (message.content.isNotEmpty)
                    Text(message.content,
                        style: TextStyle(color: scheme.onPrimary)),
                ],
              )
            : (message.content.isEmpty
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : MarkdownBody(data: message.content)),
      ),
    );
  }
}
