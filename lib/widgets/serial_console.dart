import 'package:flutter/material.dart';

import '../bluetooth/serial_message.dart';
import '../bluetooth/serial_view_settings.dart';

/// 串口控制台：收发记录 + 可开关的显示模块 + HEX 发送开关 + 输入栏。
///
/// 经典蓝牙和 BLE 两个页面共用；显示哪些模块由 [SerialViewSettings] 决定，
/// 收发数据和输入解析都交给外层的服务处理，这里只负责显示和收集输入。
class SerialConsole extends StatefulWidget {
  const SerialConsole({
    super.key,
    required this.messages,
    required this.canSend,
    required this.settings,
    required this.onSend,
    required this.onClear,
    this.onOpenCharacteristics,
    this.txBytes = 0,
    this.rxBytes = 0,
  });

  final List<SerialMessage> messages;
  final bool canSend;

  /// 显示配置（模式、时间戳、字节计数等开关）
  final SerialViewSettings settings;

  /// 第二个参数表示是否按 HEX 发送
  final void Function(String text, bool hexMode) onSend;
  final VoidCallback onClear;

  /// 非空时在工具栏显示「服务与特征」入口，只有 BLE 模式会传
  final VoidCallback? onOpenCharacteristics;

  /// 累计发送字节数
  final int txBytes;

  /// 累计接收字节数
  final int rxBytes;

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

  void _send([String? text]) {
    final String value = text ?? _controller.text;
    if (value.isEmpty) return;
    widget.onSend(value, _hexMode);
    if (text == null) {
      _controller.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (BuildContext context, Widget? child) {
        return Column(
          children: <Widget>[
            _buildToolbar(context),
            const Divider(height: 1),
            Expanded(child: _buildMessageList(context)),
            if (widget.settings.showQuickCommands) _buildQuickCommands(context),
            const Divider(height: 1),
            _buildInputBar(context),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: <Widget>[
              Text('收发记录', style: theme.textTheme.labelLarge),
              const SizedBox(width: 8),
              Text(
                '${widget.messages.length} 条',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              if (widget.onOpenCharacteristics != null)
                IconButton(
                  icon: const Icon(Icons.account_tree_outlined),
                  tooltip: '服务与特征',
                  onPressed: widget.onOpenCharacteristics,
                ),
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
        ),
        if (widget.settings.showByteCount)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '发送 ${widget.txBytes} 字节 · 接收 ${widget.rxBytes} 字节',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
          ),
      ],
    );
  }

  /// 自定义模式下的快捷指令栏：点一下按文本发出去
  Widget _buildQuickCommands(BuildContext context) {
    final List<String> commands = widget.settings.quickCommands;
    if (commands.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: commands.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final String command = commands[index];
          return ActionChip(
            label: Text(command),
            onPressed: widget.canSend ? () => _send(command) : null,
          );
        },
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
        return _MessageRow(message: message, settings: widget.settings);
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
                  hintMaxLines: 1,
                  hintText: _hexMode ? '输入 HEX' : '输入内容',
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

/// 单条记录：方向、时间、内容，按配置决定显示哪些
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.settings, super.key});

  final SerialMessage message;
  final SerialViewSettings settings;

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

    // HEX 视图只影响真实收发的内容，系统提示照旧显示文字
    final String content =
        settings.showHexView && message.hex.isNotEmpty ? message.hex : message.body;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (settings.showDirection) ...<Widget>[
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
          ],
          if (settings.showTimestamp) ...<Widget>[
            Text(
              message.timeLabel,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SelectableText(
              content,
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
