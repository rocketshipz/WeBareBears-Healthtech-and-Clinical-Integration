import '../localization.dart';
import 'package:flutter/material.dart';

import '../services/triage_chat_service.dart';
import '../theme.dart';
import 'triage_report.dart';

class _ChatMessage {
  final String text;
  final bool fromUser;
  const _ChatMessage(this.text, {required this.fromUser});
}

class TriagePage extends StatefulWidget {
  const TriagePage({super.key});

  @override
  State<TriagePage> createState() => _TriagePageState();
}

class _TriagePageState extends State<TriagePage> {
  /// Selection lists up to this size render as buttons, longer ones as a dropdown.
  static const int _maxButtonOptions = 4;

  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      'Hi, I will ask a few questions to understand your condition. '
      'What is the main problem you are experiencing?',
      fromUser: false,
    ),
  ];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _sessionId;
  String? _firstComplaint;
  String? _lastSent;
  List<String>? _lastSelected;
  TriageChatReply? _current; // null until the first reply = free-text prompt
  String? _dropdownValue;
  final Set<String> _checked = {}; // ticked options of a multi-select question
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isSelection => _current?.isSelection ?? false;

  /// [selected]: the option(s) picked from the current selection, sent so the
  /// backend can record them exactly.
  Future<void> _send(String message, {List<String>? selected}) async {
    final text = message.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMessage(text, fromUser: true));
      _firstComplaint ??= text;
      _lastSent = text;
      _lastSelected = selected;
      _textController.clear();
      _dropdownValue = null;
      _checked.clear();
      _loading = true;
      _error = null;
    });
    _scrollToEnd();

    try {
      final reply = await TriageChatService.sendMessage(
        text,
        sessionId: _sessionId,
        selectedOptions: selected,
      );
      if (!mounted) return;
      setState(() {
        _sessionId = reply.sessionId ?? _sessionId;
        _current = reply;
        _loading = false;
        _messages.add(_ChatMessage(reply.text, fromUser: false));
      });
      _scrollToEnd();
      if (reply.assessment != null) _openReport(reply.assessment!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the triage service. Please try again.';
      });
    }
  }

  void _openReport(TriageAssessmentData a) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TriageReportPage(
          report: TriageReportData(
            symptom: _firstComplaint,
            severity: a.urgencyDescription,
            duration: null,
            dangerSigns: a.primaryConcerns,
            levelOverride: a.level,
            recommendationOverride:
                a.immediateActions.isEmpty ? null : a.immediateActions.join(' '),
          ),
        ),
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        CircleBackButton(onTap: () => Navigator.pop(context)),
                        const SizedBox(width: 14),
                        const BrandWordmark(),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: LocalizedText('AI Triage', style: AppText.display),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (final m in _messages) _bubble(m),
                        if (_loading) _typingIndicator(),
                        if (_error != null) _errorBanner(),
                      ],
                    ),
                  ),
                  _answerPanel(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CHAT BUBBLES
  // ============================================================

  Widget _bubble(_ChatMessage m) {
    return Align(
      alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: m.fromUser
            ? BoxDecoration(
                color: AppColors.darkTeal,
                borderRadius: BorderRadius.circular(18),
              )
            : cardDecoration(radius: 18),
        child: Text(
          m.text,
          style: m.fromUser
              ? AppText.style(14, FontWeight.w500, Colors.white, height: 1.4)
              : AppText.body,
        ),
      ),
    );
  }

  Widget _typingIndicator() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _error!,
              style: AppText.style(12, FontWeight.w600, AppColors.textDark),
            ),
          ),
          TextButton(
            onPressed: _lastSent == null ? null : _retry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _retry() {
    // Drop the failed user bubble; _send adds it back.
    final last = _lastSent;
    if (last == null) return;
    setState(() {
      if (_messages.isNotEmpty && _messages.last.fromUser) {
        _messages.removeLast();
      }
    });
    _send(last, selected: _lastSelected);
  }

  // ============================================================
  // ANSWER PANEL: checkboxes, option buttons, dropdown or text box
  // ============================================================

  Widget _answerPanel() {
    final Widget content;
    if (_isSelection) {
      final options = _current!.options;
      if (_current!.multiSelect) {
        content = _checkboxList(options);
      } else {
        content = options.length <= _maxButtonOptions
            ? _optionButtons(options)
            : _optionDropdown(options);
      }
    } else {
      content = _textBox();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: AbsorbPointer(absorbing: _loading, child: content),
    );
  }

  Widget _optionButtons(List<String> options) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final o in options)
          _option(text: o, onTap: () => _send(o, selected: [o])),
      ],
    );
  }

  /// Tick-all-that-apply list. Exclusive options ("None of these", "Not sure")
  /// clear every other tick, and ticking anything else clears them.
  void _toggle(String option) {
    final exclusive = _current?.exclusiveOptions ?? const <String>[];
    setState(() {
      if (_checked.contains(option)) {
        _checked.remove(option);
      } else if (exclusive.contains(option)) {
        _checked
          ..clear()
          ..add(option);
      } else {
        _checked
          ..removeAll(exclusive)
          ..add(option);
      }
    });
  }

  Widget _checkboxList(List<String> options) {
    // Keep the screen's option order, not the tap order.
    final picked = [for (final o in options) if (_checked.contains(o)) o];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final o in options)
                CheckboxListTile(
                  value: _checked.contains(o),
                  onChanged: (_) => _toggle(o),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.darkTeal,
                  title: Text(
                    o,
                    style: AppText.style(
                      14,
                      FontWeight.w500,
                      AppColors.darkTeal,
                      height: 1.25,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: picked.isEmpty
              ? null
              : () => _send(picked.join('; '), selected: picked),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _optionDropdown(List<String> options) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _dropdownValue,
            isExpanded: true,
            hint: const Text('Select an answer'),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.field,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
            items: [
              for (final o in options)
                DropdownMenuItem(
                  value: o,
                  child: Text(o, overflow: TextOverflow.ellipsis, maxLines: 2),
                ),
            ],
            onChanged: (v) => setState(() => _dropdownValue = v),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          onPressed:
              _dropdownValue == null
                  ? null
                  : () => _send(_dropdownValue!, selected: [_dropdownValue!]),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ],
    );
  }

  Widget _textBox() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: _send,
            decoration: InputDecoration(
              hintText: 'Type your answer',
              filled: true,
              fillColor: AppColors.field,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          onPressed: () => _send(_textController.text),
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    );
  }

  // ============================================================
  // SINGLE-SELECT OPTION BUTTON (sized to its label)
  // ============================================================

  Widget _option({required String text, required VoidCallback onTap}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppText.style(
            14,
            FontWeight.w500,
            AppColors.darkTeal,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}
