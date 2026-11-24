import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../bluetooth/ble_serial_service.dart';
import '../../bluetooth/ble_uart_profile.dart';
import '../../bluetooth/uuid_text.dart';

/// 服务与特征列表：把连上时发现的服务和特征全列出来，手动指定用哪两条收发。
///
/// 有些模块的数据通道不用 NUS / FFE1 那套 UUID，自动挑特征会挑错，
/// 这一页就是给这种情况留的手动开关：点「写」换成发数据的特征，点「收」换成收通知的特征。
class BleCharacteristicPage extends StatelessWidget {
  const BleCharacteristicPage({super.key, required this.service});

  final BleSerialService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('服务与特征')),
      body: ListenableBuilder(
        listenable: service,
        builder: (BuildContext context, Widget? child) {
          final List<BluetoothService> services = service.services;
          if (services.isEmpty) {
            return const Center(child: Text('还没有发现服务，先连接设备'));
          }
          return Column(
            children: <Widget>[
              _buildHint(context),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: services.length,
                  itemBuilder: (BuildContext context, int index) =>
                      _buildService(context, services[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHint(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Text(
        '点「写」把它设为发送用的特征，点「收」把它设为接收通知的特征',
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  Widget _buildService(BuildContext context, BluetoothService bluetoothService) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                bluetoothService.isPrimary ? '服务（主要）' : '服务（次要）',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 2),
              SelectableText(
                labeledUuid(
                  bluetoothService.uuid,
                  serviceNameOf(bluetoothService.uuid),
                ),
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        for (final BluetoothCharacteristic characteristic
            in bluetoothService.characteristics)
          _buildCharacteristic(context, characteristic),
        if (bluetoothService.characteristics.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('这个服务下没有特征', style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }

  Widget _buildCharacteristic(
    BuildContext context,
    BluetoothCharacteristic characteristic,
  ) {
    final ThemeData theme = Theme.of(context);
    final CharacteristicProperties properties = characteristic.properties;
    final bool canWrite = properties.write || properties.writeWithoutResponse;
    final bool canReceive = properties.notify || properties.indicate;
    final bool usable = service.isConnected && !service.isBusy;

    final String? name = characteristicNameOf(characteristic.uuid);
    final String propertiesText = BleUartProfile.describeProperties(properties);

    return ListTile(
      dense: true,
      title: SelectableText(
        name ?? formatUuid(characteristic.uuid),
        style: name == null
            ? theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')
            : theme.textTheme.bodyMedium,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          name == null
              ? propertiesText
              : '${formatUuid(characteristic.uuid)} · $propertiesText',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _TargetButton(
            label: '写',
            selected: characteristic == service.writeCharacteristic,
            enabled: canWrite && usable,
            onPressed: () => service.selectWriteCharacteristic(characteristic),
          ),
          const SizedBox(width: 6),
          _TargetButton(
            label: '收',
            selected: characteristic == service.notifyCharacteristic,
            enabled: canReceive && usable,
            onPressed: () => service.selectNotifyCharacteristic(characteristic),
          ),
        ],
      ),
    );
  }
}

/// 「写 / 收」两个小按钮：选中时实心，没选时描边
class _TargetButton extends StatelessWidget {
  const _TargetButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  static final ButtonStyle _baseStyle = ButtonStyle(
    visualDensity: VisualDensity.compact,
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.zero,
    ),
    minimumSize: const WidgetStatePropertyAll<Size>(Size(44, 32)),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context) {
    final Widget child = Text(label, style: const TextStyle(fontSize: 12));
    if (selected) {
      return FilledButton(
        style: _baseStyle,
        onPressed: enabled ? onPressed : null,
        child: child,
      );
    }
    return OutlinedButton(
      style: _baseStyle,
      onPressed: enabled ? onPressed : null,
      child: child,
    );
  }
}
