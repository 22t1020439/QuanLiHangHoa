import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity_log_model.dart';
import '../services/firestore_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  void _showSettings(BuildContext context, FirestoreService service) async {
    int currentDays = await service.getRetentionDays();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        int selectedDays = currentDays;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Cài đặt lịch sử'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Số ngày lưu trữ lịch sử (1-30 ngày):'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: selectedDays.toDouble(),
                          min: 1,
                          max: 30,
                          divisions: 29,
                          label: '$selectedDays ngày',
                          onChanged: (value) {
                            setState(() => selectedDays = value.round());
                          },
                        ),
                      ),
                      Text(
                        '$selectedDays ngày',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await service.updateRetentionDays(selectedDays);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmRestore(
    BuildContext context,
    FirestoreService service,
    ActivityLog log,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi phục phiếu'),
        content: Text('Bạn có chắc chắn muốn khôi phục ${log.details}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await service.restoreTransaction(log);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Khôi phục thành công')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Lỗi khôi phục: $e')));
                }
              }
            },
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FirestoreService service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch Sử Hoạt Động'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context, service),
            tooltip: 'Cài đặt xóa lịch sử',
          ),
        ],
      ),
      body: StreamBuilder<List<ActivityLog>>(
        stream: service.getLogs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Lỗi tải lịch sử'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return const Center(
              child: Text('Chưa có hoạt động nào được ghi lại'),
            );
          }

          return ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final log = logs[index];
              final dateStr = DateFormat(
                'dd/MM/yyyy HH:mm',
              ).format(log.timestamp);

              final bool canRestore =
                  log.type == LogType.transaction && log.extraData != null;

              return ListTile(
                leading: _buildLeadingIcon(log.type),
                title: Text(
                  log.action,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.details),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: canRestore
                    ? IconButton(
                        icon: const Icon(Icons.restore, color: Colors.blue),
                        onPressed: () => _confirmRestore(context, service, log),
                        tooltip: 'Khôi phục phiếu',
                      )
                    : null,
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLeadingIcon(LogType type) {
    IconData icon;
    Color color;

    switch (type) {
      case LogType.product:
        icon = Icons.inventory_2_outlined;
        color = Colors.blue;
        break;
      case LogType.transaction:
        icon = Icons.swap_horiz_outlined;
        color = Colors.green;
        break;
      case LogType.supplier:
        icon = Icons.business_outlined;
        color = Colors.orange;
        break;
      case LogType.system:
        icon = Icons.settings_outlined;
        color = Colors.grey;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
