import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'in_app_log_service.dart';

/// Overlay widget that wraps the entire app, providing a floating toggle button
/// to open/close an in-app error log inspector.
class InAppDebugLogOverlay extends StatefulWidget {
  const InAppDebugLogOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<InAppDebugLogOverlay> createState() => _InAppDebugLogOverlayState();
}

class _InAppDebugLogOverlayState extends State<InAppDebugLogOverlay> {
  bool _isOpen = false;
  Offset _fabPosition = const Offset(16, 100);
  String _searchQuery = '';
  LogLevel? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenSize = media.size;

    return Stack(
      children: [
        widget.child,

        // --- Draggable Floating Toggle Button ---
        Positioned(
          left: _fabPosition.dx,
          top: _fabPosition.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _fabPosition = Offset(
                  (_fabPosition.dx + details.delta.dx)
                      .clamp(8, screenSize.width - 64),
                  (_fabPosition.dy + details.delta.dy)
                      .clamp(40, screenSize.height - 100),
                );
              });
            },
            child: Material(
              elevation: 8,
              shape: const CircleBorder(),
              color: Colors.transparent,
              child: AnimatedBuilder(
                animation: InAppLogService.instance,
                builder: (context, _) {
                  final errCount = InAppLogService.instance.errorCount;
                  final totalCount = InAppLogService.instance.logs.length;
                  final hasErrors = errCount > 0;

                  return FloatingActionButton.small(
                    heroTag: 'in_app_log_fab',
                    backgroundColor: _isOpen
                        ? Colors.redAccent
                        : (hasErrors ? Colors.deepOrange : const Color(0xFF1B263B)),
                    onPressed: () {
                      setState(() => _isOpen = !_isOpen);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          _isOpen
                              ? Icons.close
                              : (hasErrors ? Icons.bug_report : Icons.terminal),
                          color: Colors.white,
                          size: 20,
                        ),
                        if (!_isOpen && totalCount > 0)
                          Positioned(
                            top: -6,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: hasErrors ? Colors.red : Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                hasErrors ? '$errCount' : '$totalCount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // --- Slide-up / Expandable Log Drawer Panel ---
        if (_isOpen)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            top: screenSize.height * 0.15,
            child: Material(
              borderRadius: BorderRadius.circular(16),
              elevation: 16,
              color: const Color(0xFF0F172A), // Dark slate background
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // --- Header Bar ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: const Color(0xFF1E293B),
                    child: Row(
                      children: [
                        const Icon(Icons.terminal,
                            color: Colors.lightGreenAccent, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'In-App Error Logs',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy,
                              color: Colors.white70, size: 18),
                          tooltip: 'Copy all logs',
                          onPressed: () {
                            final logsText =
                                InAppLogService.instance.exportLogs();
                            Clipboard.setData(ClipboardData(text: logsText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('All logs copied to clipboard'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_sweep,
                              color: Colors.white70, size: 20),
                          tooltip: 'Clear logs',
                          onPressed: () {
                            InAppLogService.instance.clear();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                          tooltip: 'Close panel',
                          onPressed: () {
                            setState(() => _isOpen = false);
                          },
                        ),
                      ],
                    ),
                  ),

                  // --- Filter & Search Controls ---
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: const Color(0x801E293B),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Search Field
                        SizedBox(
                          height: 36,
                          child: TextField(
                            onChanged: (val) =>
                                setState(() => _searchQuery = val.trim()),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Filter logs by text / URL...',
                              hintStyle: const TextStyle(
                                  color: Colors.white38, fontSize: 12),
                              prefixIcon: const Icon(Icons.search,
                                  color: Colors.white38, size: 18),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              filled: true,
                              fillColor: const Color(0xFF334155),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Category Chips
                        Row(
                          children: [
                            _buildFilterChip('All', null),
                            const SizedBox(width: 6),
                            _buildFilterChip('Errors', LogLevel.error),
                            const SizedBox(width: 6),
                            _buildFilterChip('Network', LogLevel.network),
                            const SizedBox(width: 6),
                            _buildFilterChip('Info', LogLevel.info),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // --- Log List View ---
                  Expanded(
                    child: AnimatedBuilder(
                      animation: InAppLogService.instance,
                      builder: (context, _) {
                        final rawLogs = InAppLogService.instance.logs;
                        final filtered = rawLogs.where((entry) {
                          if (_selectedFilter != null &&
                              entry.level != _selectedFilter) {
                            return false;
                          }
                          if (_searchQuery.isNotEmpty) {
                            final q = _searchQuery.toLowerCase();
                            final matchMsg =
                                entry.message.toLowerCase().contains(q);
                            final matchTag =
                                entry.tag.toLowerCase().contains(q);
                            final matchDetails =
                                entry.details?.toLowerCase().contains(q) ??
                                    false;
                            return matchMsg || matchTag || matchDetails;
                          }
                          return true;
                        }).toList();

                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text(
                              'No logs captured yet.',
                              style: TextStyle(color: Colors.white38),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (context, index) {
                            final log = filtered[index];
                            return _LogTile(log: log);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String label, LogLevel? level) {
    final isSelected = _selectedFilter == level;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF3B82F6),
      backgroundColor: const Color(0xFF334155),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      onSelected: (val) {
        setState(() {
          _selectedFilter = val ? level : null;
        });
      },
    );
  }
}

class _LogTile extends StatefulWidget {
  const _LogTile({required this.log});

  final LogEntry log;

  @override
  State<_LogTile> createState() => _LogTileState();
}

class _LogTileState extends State<_LogTile> {
  bool _expanded = false;

  Color get _levelColor {
    switch (widget.log.level) {
      case LogLevel.error:
        return Colors.redAccent;
      case LogLevel.warning:
        return Colors.amberAccent;
      case LogLevel.network:
        return Colors.lightBlueAccent;
      case LogLevel.info:
        return Colors.lightGreenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final hasDetails =
        (log.details != null && log.details!.isNotEmpty) ||
        (log.stackTrace != null && log.stackTrace!.isNotEmpty);

    return InkWell(
      onTap: hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time Badge
                Text(
                  log.timeFormatted,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 6),

                // Tag Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _levelColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _levelColor.withAlpha(128)),
                  ),
                  child: Text(
                    log.tag,
                    style: TextStyle(
                      color: _levelColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Main Message
                Expanded(
                  child: Text(
                    log.message,
                    maxLines: _expanded ? null : 2,
                    overflow:
                        _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.log.level == LogLevel.error
                          ? Colors.red[200]
                          : Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),

                if (hasDetails)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                    size: 16,
                  ),

                IconButton(
                  icon: const Icon(Icons.copy, size: 14, color: Colors.white38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Copy entry',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: log.toFullString()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Log entry copied'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),

            // Expanded Details Block
            if (_expanded && hasDetails) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: SelectionArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (log.details != null && log.details!.isNotEmpty) ...[
                        const Text(
                          '--- DETAILS / PAYLOAD ---',
                          style: TextStyle(
                              color: Colors.amberAccent, fontSize: 10),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          log.details!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                      if (log.stackTrace != null &&
                          log.stackTrace!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Text(
                          '--- STACKTRACE ---',
                          style: TextStyle(
                              color: Colors.redAccent, fontSize: 10),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          log.stackTrace!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
