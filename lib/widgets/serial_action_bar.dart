import 'package:flutter/material.dart';

/// 串口页顶部：左边状态说明，右边主操作按钮。
///
/// 未连接时按钮是「扫描 / 停止扫描」，已连接时变成「断开连接」；
/// 按钮用了紧凑尺寸，状态文字占剩下的宽度，整行只占一行高度。
class SerialActionBar extends StatelessWidget {
  const SerialActionBar({
    super.key,
    required this.status,
    required this.connected,
    required this.scanning,
    required this.busy,
    required this.onScanToggle,
    required this.onDisconnect,
  });

  final String status;
  final bool connected;
  final bool scanning;
  final bool busy;
  final VoidCallback onScanToggle;
  final VoidCallback onDisconnect;

  /// 比默认按钮矮一圈、左右留白也更小
  static final ButtonStyle _compactButtonStyle = FilledButton.styleFrom(
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    minimumSize: const Size(0, 36),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: <Widget>[
          Icon(
            connected ? Icons.link : Icons.link_off,
            size: 16,
            color: connected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              status,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (busy) ...<Widget>[
            const SizedBox(width: 8),
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
          const SizedBox(width: 8),
          if (connected)
            FilledButton.icon(
              style: _compactButtonStyle,
              onPressed: busy ? null : onDisconnect,
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('断开连接'),
            )
          else
            FilledButton.icon(
              style: _compactButtonStyle,
              onPressed: busy ? null : onScanToggle,
              icon: Icon(scanning ? Icons.stop : Icons.search, size: 18),
              label: Text(scanning ? '停止扫描' : '扫描设备'),
            ),
        ],
      ),
    );
  }
}
