import 'package:flutter/material.dart';

import '../bluetooth/serial_message.dart';

/// 串口控制台：收发记录 + HEX 开关 + 输入栏。
///
/// 经典蓝牙和 BLE 两个页面共用，收发数据和输入解析都交给外层的服务处理，
/// 这里只负责显示和收集输入。
class SerialConsole extends StatefulWidget {
  const SerialConsole({
    super.key,
    required this.messages,
    required this.canSend,
    required this.onSend,
    required this.onClear,
  });

  final List<SerialMessage> messages;
  final bool canSend;

  /// 第二个参数表示是否按 HEX 发送
  final void Function(String text, bool hexMode) onSend;
  final VoidCallback onClear;

  @override
  State<SerialConsole> createState() => _SerialConsoleState();
}

class _SerialConsoleState extends State<SerialConsole> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hexMode = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final String text = _controller.text;
    if (text.isEmpty) return;
    widget.onSend(text, _hexMode);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildToolbar(context),
        const Divider(height: 1),
        Expanded(child: _buildMessageList(context)),
        const Divider(height: 1),
        _buildInputBar(context),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: <Widget>[
          Text('收发记录', style: theme.textTheme.labelLarge),
          const SizedBox(width: 8),
          Text('${widget.messages.length} 条', style: theme.textTheme.bodySmall),
          const Spacer(),
          Text('HEX', style: theme.textTheme.bodySmall),
          Switch(
            value: _hexMode,
            onChanged: (bool value) => setState(() => _hexMode = value),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空记录',
            onPressed: widget.onClear,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    if (widget.messages.isEmpty) {
      return Center(
        child: Text('暂无数据', style: Theme.of(context).textTheme.bodySmall),
      );
    }

    // reverse: true 让最新的记录贴在底部，不用手动滚动
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: widget.messages.length,
      itemBuilder: (BuildContext context, int index) {
        final SerialMessage message =
            widget.messages[widget.messages.length - 1 - index];
        return _MessageRow(message: message);
      },
    );
  }

  Widget _buildInputBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.canSend,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  hintText: _hexMode
                      ? '输入 HEX，例如 01 0A FF'
                      : '输入要发送的内容，例如 AT+RESET',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: widget.canSend ? _send : null,
              icon: const Icon(Icons.send),
              tooltip: '发送',
            ),
          ],
        ),
      ),
    );
  }
}

/// 单条记录：方向 + 时间 + 内容
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, super.key});

  final SerialMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String label = switch (message.direction) {
      SerialDirection.tx => '发送',
      SerialDirection.rx => '接收',
      SerialDirection.system => '提示',
    };
    final Color color = switch (message.direction) {
      SerialDirection.tx => theme.colorScheme.primary,
      SerialDirection.rx => theme.colorScheme.tertiary,
      SerialDirection.system => theme.colorScheme.outline,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            padding: const EdgeInsets.symmetric(vertical: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            message.timeLabel,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              message.body,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
