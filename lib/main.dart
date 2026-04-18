import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/product_screen.dart';
import 'screens/supplier_screen.dart';
import 'screens/transaction_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
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
