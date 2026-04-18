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
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  product == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Tên sản phẩm',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _stockController,
                  decoration: const InputDecoration(
                    labelText: 'Tồn kho',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị tính (ví dụ: Cái, Bộ, kg...)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.straighten_outlined),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final name = _nameController.text.trim();
                      // Thay đổi dấu phẩy thành dấu chấm để parse double chính xác
                      final stockText = _stockController.text.replaceAll(
                        ',',
                        '.',
                      );
                      final stock = double.tryParse(stockText) ?? 0.0;
                      final unit = _unitController.text.trim();

                      if (name.isNotEmpty && unit.isNotEmpty) {
                        try {
                          final newProduct = Product(
                            id: product?.id,
                            name: name,
                            stock: stock,
                            unit: unit,
                            type: widget.type,
                          );
                          await _service.saveProduct(newProduct);
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập đầy đủ thông tin'),
                          ),
                        );
                      }
                    },
                    child: Text(
                      product == null ? 'THÊM MỚI' : 'CẬP NHẬT',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.type == ProductType.dong
        ? 'Hàng Đà Nẵng'
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
                var products = List<Product>.from(snapshot.data ?? []);

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

                return ReorderableListView.builder(
                  itemCount: products.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = products.removeAt(oldIndex);
                      products.insert(newIndex, item);
                      _service.updateProductsOrder(products);
                    });
                  },
                  itemBuilder: (context, index) {
                    final p = products[index];
                    final isLowStock = p.stock <= 5;

                    return Card(
                      key: ValueKey(p.id),
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
                              onPressed: () => _service.deleteProduct(p),
                            ),
                            const Icon(Icons.drag_handle, color: Colors.grey),
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
