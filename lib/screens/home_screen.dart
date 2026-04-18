import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firestore_service.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onNavigateToHistory;
  const HomeScreen({super.key, required this.onNavigateToHistory});

  @override
  Widget build(BuildContext context) {
    final FirestoreService service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Hàng Dã Viên'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () async {
              try {
                await service.exportStockToExcel();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Lỗi xuất file: $e')));
                }
              }
            },
            tooltip: 'Xuất báo cáo Excel',
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: service.getDashboardStats(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats =
              snapshot.data ??
              {'countDong': 0, 'countNoiBo': 0, 'monthExportDong': 0.0};

          if (stats.containsKey('error')) {
            return Center(child: Text('Lỗi hệ thống: ${stats['error']}'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo Dã Viên
                Image.asset(
                  'assets/images/logo.png',
                  height: 150,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.restaurant,
                    size: 100,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tổng quan hàng hóa',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStatCard(
                      'Sản phẩm Đà Nẵng',
                      stats['countDong'].toString(),
                      Icons.inventory,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Sản phẩm Nội Bộ',
                      stats['countNoiBo'].toString(),
                      Icons.inventory_2,
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Thống kê xuất hàng Đà Nẵng trong tháng
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Colors.orangeAccent,
                              radius: 20,
                              child: Icon(
                                Icons.trending_up,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Đà Nẵng xuất tháng này',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    '${stats['monthExportDong']}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        const Text(
                          'Biểu đồ xuất hàng chi tiết',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildExportBarChart(stats['dongExportDetails'] ?? {}),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Trạng thái hệ thống',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_done, color: Colors.green),
                    title: const Text('Dữ liệu Dã Viên'),
                    subtitle: const Text('Đã kết nối trực tuyến'),
                    trailing: const Text('v1.1.0'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExportBarChart(Map<String, dynamic> data) {
    // Lọc bỏ các mặt hàng có số lượng bằng 0
    final filteredData = data.entries
        .where((e) => (e.value as double) > 0)
        .toList();

    if (filteredData.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'Chưa có dữ liệu xuất hàng Đà Nẵng',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY:
              filteredData
                  .map((e) => e.value as double)
                  .reduce((a, b) => a > b ? a : b) *
              1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.blueAccent,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${filteredData[groupIndex].key}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  children: [
                    TextSpan(
                      text: rod.toY.toString(),
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < filteredData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Text(
                          filteredData[index].key,
                          style: const TextStyle(fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              left: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          barGroups: filteredData.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.value as double,
                  color: Colors.blue,
                  width: 30,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
              showingTooltipIndicators: [0],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
