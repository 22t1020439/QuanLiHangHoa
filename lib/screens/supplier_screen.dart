import 'package:flutter/material.dart';
import '../models/supplier_model.dart';
import '../services/firestore_service.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _showForm([Supplier? supplier]) {
    if (supplier != null) {
      _nameController.text = supplier.name;
      _addressController.text = supplier.address;
      _phoneController.text = supplier.phone;
    } else {
      _nameController.clear();
      _addressController.clear();
      _phoneController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              supplier == null ? 'Thêm nhà cung cấp' : 'Sửa nhà cung cấp',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tên NCC'),
            ),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Địa chỉ'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final newSupplier = Supplier(
                  id: supplier?.id,
                  name: _nameController.text,
                  address: _addressController.text,
                  phone: _phoneController.text,
                );
                await _service.saveSupplier(newSupplier);
                if (mounted) Navigator.pop(context);
              },
              child: Text(supplier == null ? 'Thêm' : 'Lưu'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhà Cung Cấp')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm nhà cung cấp...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Supplier>>(
              stream: _service.getSuppliers(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(child: Text('Lỗi tải dữ liệu'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var suppliers = snapshot.data ?? [];

                if (_searchQuery.isNotEmpty) {
                  suppliers = suppliers
                      .where((s) => s.name.toLowerCase().contains(_searchQuery))
                      .toList();
                }

                if (suppliers.isEmpty) {
                  return const Center(
                    child: Text('Không tìm thấy nhà cung cấp nào'),
                  );
                }

                return ListView.builder(
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final s = suppliers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.business),
                        ),
                        title: Text(
                          s.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${s.phone} - ${s.address}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showForm(s),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _service.deleteSupplier(s.id!),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
