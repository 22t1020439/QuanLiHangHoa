import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDMC2mgA28jKAP6cKSDdX8qw7-lsThqXSQ",
        appId: "1:778899215488:web:39d3fd024fe1db5b8f4265",
        messagingSenderId: "778899215488",
        projectId: "inventory-app-276db",
        authDomain: "inventory-app-276db.firebaseapp.com",
        storageBucket: "inventory-app-276db.firebasestorage.app",
        measurementId: "G-Q8QGJG914P",
      ),
    );
    runApp(const MyApp());
  } catch (e) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "Lỗi khởi tạo Firebase!\n\nNguyên nhân: $e\n\nBạn đã thêm file google-services.json vào android/app/ chưa?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: HomePage());
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  final CollectionReference items = FirebaseFirestore.instance.collection(
    'items',
  );

  void addItem() {
    final String name = nameController.text.trim();
    final String quantityStr = quantityController.text.trim();

    if (name.isEmpty || quantityStr.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin")));
      return;
    }

    final int? quantity = int.tryParse(quantityStr);
    if (quantity == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Số lượng phải là một số nguyên")));
      return;
    }

    items.add({'name': name, 'quantity': quantity});
    nameController.clear();
    quantityController.clear();
  }

  void deleteItem(String id) {
    items.doc(id).delete().catchError((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Không thể xóa sản phẩm: $error")));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Quản lý hàng hóa")),
      body: Column(
        children: [
          // FORM NHẬP
          Padding(
            padding: EdgeInsets.all(10),
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: "Tên sản phẩm"),
                ),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: "Số lượng"),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: addItem,
                  child: Text("Thêm sản phẩm"),
                ),
              ],
            ),
          ),

          // DANH SÁCH
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: items.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Đã xảy ra lỗi khi tải dữ liệu\nKiểm tra lại cấu hình Firebase",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("Chưa có sản phẩm nào"));
                }

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final String name = data['name'] ?? 'Không tên';
                    final int quantity = data['quantity'] ?? 0;

                    return ListTile(
                      title: Text(name),
                      subtitle: Text("Số lượng: $quantity"),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () => deleteItem(doc.id),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
