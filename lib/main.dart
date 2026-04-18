import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/product_screen.dart';
import 'screens/supplier_screen.dart';
import 'screens/transaction_screen.dart';
import 'screens/history_screen.dart';
import 'models/product_model.dart';
import 'services/firestore_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBh7FoVWJs3pMDPDjC07-IW7xG1XPMOZN0",
        appId: "1:778899215488:web:39d3fd024fe1db5b8f4265",
        messagingSenderId: "778899215488",
        projectId: "inventory-app-276db",
        authDomain: "inventory-app-276db.firebaseapp.com",
        storageBucket: "inventory-app-276db.firebasestorage.app",
        // measurementId: "G-Q8QGJG914P", // Bỏ đo lường nếu gây lỗi build web
      ),
    );

    // Tạm thời tắt Persistence để kiểm tra lỗi build
    /*
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    }
    */

    // Tự động dọn dẹp lịch sử cũ
    FirestoreService().cleanupOldLogs();

    runApp(const InventoryApp());
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text("Lỗi khởi tạo: $e"))),
      ),
    );
  }
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý kho hàng',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(onNavigateToHistory: () => setState(() => _selectedIndex = 5)),
      const ProductScreen(type: ProductType.dong),
      const ProductScreen(type: ProductType.noiBo),
      const SupplierScreen(),
      const TransactionScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.inventory), label: 'Đà Nẵng'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Nội Bộ'),
          NavigationDestination(icon: Icon(Icons.business), label: 'NCC'),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz),
            label: 'Nhập/Xuất',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Lịch Sử'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final VoidCallback onNavigateToHistory;
  const HomeScreen({super.key, required this.onNavigateToHistory});

  @override
  Widget build(BuildContext context) {
    final FirestoreService service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho Hàng Thông Minh'),
        centerTitle: true,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: service.getDashboardStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats =
              snapshot.data ??
              {'totalItems': 0, 'lowStockCount': 0, 'totalStock': 0};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tổng quan kho hàng',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                      'Sản phẩm',
                      stats['totalItems'].toString(),
                      Icons.inventory,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Tồn kho thấp',
                      stats['lowStockCount'].toString(),
                      Icons.warning_amber_rounded,
                      stats['lowStockCount'] > 0 ? Colors.red : Colors.green,
                    ),
                    _buildStatCard(
                      'Tổng số lượng',
                      stats['totalStock'].toString(),
                      Icons.summarize,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      'Hoạt động',
                      'Lịch sử',
                      Icons.history,
                      Colors.purple,
                      onTap: onNavigateToHistory,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  'Trạng thái kết nối',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cloud_done, color: Colors.green),
                    title: const Text('Firebase Cloud Firestore'),
                    subtitle: const Text('Đã kết nối thời gian thực'),
                    trailing: const Text('v1.0.0'),
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
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
