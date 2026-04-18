import 'package:flutter/material.dart';
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats =
              snapshot.data ??
              {'countDong': 0, 'countNoiBo': 0, 'monthExportDong': 0.0};

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
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.orangeAccent,
                          radius: 25,
                          child: Icon(Icons.trending_up, color: Colors.white),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Đà Nẵng xuất tháng này',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${stats['monthExportDong']}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
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
