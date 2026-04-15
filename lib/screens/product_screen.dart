import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';

class ProductScreen extends StatefulWidget {
  final ProductType type;
  const ProductScreen({super.key, required this.type});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final FirestoreService _service = FirestoreService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _showForm([Product? product]) {
    if (product != null) {
      _nameController.text = product.name;
      _stockController.text = product.stock.toString();
      _unitController.text = product.unit;
    } else {
      _nameController.clear();
      _stockController.clear();
      _unitController.clear();
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
              product == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tên sản phẩm'),
            ),
            TextField(
              controller: _stockController,
              decoration: const InputDecoration(labelText: 'Tồn kho'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _unitController,
              decoration: const InputDecoration(labelText: 'Đơn vị tính'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final newProduct = Product(
                  id: product?.id,
                  name: _nameController.text,
                  stock: int.tryParse(_stockController.text) ?? 0,
                  unit: _unitController.text,
                  type: widget.type,
                );
                await _service.saveProduct(newProduct);
                if (mounted) Navigator.pop(context);
              },
              child: Text(product == null ? 'Thêm' : 'Lưu'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.type == ProductType.dong
        ? 'Hàng Dòng'
        : 'Hàng Nội Bộ';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm...',
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
            child: StreamBuilder<List<Product>>(
              stream: _service.getProducts(widget.type),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(child: Text('Lỗi tải dữ liệu'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var products = snapshot.data ?? [];

                if (_searchQuery.isNotEmpty) {
                  products = products
                      .where((p) => p.name.toLowerCase().contains(_searchQuery))
                      .toList();
                }

                if (products.isEmpty) {
                  return const Center(
                    child: Text('Không tìm thấy sản phẩm nào'),
                  );
                }

                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final isLowStock = p.stock <= 5;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLowStock
                              ? Colors.red[100]
                              : Colors.blue[100],
                          child: Icon(
                            isLowStock ? Icons.warning : Icons.inventory,
                            color: isLowStock ? Colors.red : Colors.blue,
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Tồn: ${p.stock} ${p.unit}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showForm(p),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _service.deleteProduct(p.id!),
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
