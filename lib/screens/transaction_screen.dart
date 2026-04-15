import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/supplier_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final FirestoreService _service = FirestoreService();

  void _showTransactionDialog(TransactionType type) async {
    // 1. Get initial data
    final productsDong = await _service.getProducts(ProductType.dong).first;
    final productsNoiBo = await _service.getProducts(ProductType.noiBo).first;
    final suppliers = await _service.getSuppliers().first;

    List<TransactionItem> tempItems = [];
    ProductType selectedCategory = ProductType.dong;
    Product? selectedProduct;
    Supplier? selectedSupplier = suppliers.isNotEmpty ? suppliers.first : null;
    final TextEditingController qtyController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    void updateSelectedProduct(List<Product> products, StateSetter setDialogState) {
      if (products.isNotEmpty) {
        selectedProduct = products.first;
      } else {
        selectedProduct = null;
      }
    }

    // Initial product selection
    selectedProduct = productsDong.isNotEmpty ? productsDong.first : null;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            List<Product> currentProducts =
                selectedCategory == ProductType.dong ? productsDong : productsNoiBo;

            return AlertDialog(
              title: Text(
                type == TransactionType.import ? 'Phiếu Nhập' : 'Phiếu Xuất',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Selection
                      DropdownButtonFormField<ProductType>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Loại Hàng',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: ProductType.dong,
                            child: Text('Hàng Đà Nẵng'),
                          ),
                          DropdownMenuItem(
                            value: ProductType.noiBo,
                            child: Text('Hàng Nội Bộ'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedCategory = val;
                              List<Product> newProducts =
                                  val == ProductType.dong ? productsDong : productsNoiBo;
                              updateSelectedProduct(newProducts, setDialogState);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Supplier Selection (Only for Import)
                      if (type == TransactionType.import) ...[
                        DropdownButtonFormField<Supplier>(
                          value: selectedSupplier,
                          decoration: const InputDecoration(
                            labelText: 'Nhà cung cấp',
                            border: OutlineInputBorder(),
                          ),
                          items: suppliers
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.name),
                                  ))
                              .toList(),
                          onChanged: (val) =>
                              setDialogState(() => selectedSupplier = val),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Product Selection Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<Product>(
                              value: selectedProduct,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Tên Hàng',
                                border: OutlineInputBorder(),
                              ),
                              items: currentProducts
                                  .map((p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(p.name),
                                      ))
                                  .toList(),
                              onChanged: (val) =>
                                  setDialogState(() => selectedProduct = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: qtyController,
                              decoration: const InputDecoration(
                                labelText: 'SL',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Đơn vị: ${selectedProduct?.unit ?? ""}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (selectedProduct == null) return;
                              int qty = int.tryParse(qtyController.text) ?? 0;
                              if (qty <= 0) return;

                              setDialogState(() {
                                tempItems.add(TransactionItem(
                                  productId: selectedProduct!.id!,
                                  productName: selectedProduct!.name,
                                  quantity: qty,
                                  productType: selectedProduct!.type.name,
                                ));
                                qtyController.clear();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Thêm'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Items List
                      const Text(
                        'Danh Sách Mặt Hàng',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Divider(),
                      if (tempItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Chưa có mặt hàng nào'),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: tempItems.length,
                            itemBuilder: (context, index) {
                              final item = tempItems[index];
                              // Find unit from original lists
                              String unit = "";
                              var p = productsDong.firstWhere(
                                (p) => p.id == item.productId,
                                orElse: () => productsNoiBo.firstWhere(
                                  (p) => p.id == item.productId,
                                  orElse: () => Product(
                                      name: "", stock: 0, unit: "", type: ProductType.dong),
                                ),
                              );
                              unit = p.unit;

                              return Card(
                                child: ListTile(
                                  dense: true,
                                  title: Text(item.productName),
                                  subtitle: Text('SL: ${item.quantity} $unit'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setDialogState(() {
                                        tempItems.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú phiếu',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: tempItems.isEmpty
                      ? null
                      : () async {
                          final transaction = TransactionModel(
                            date: DateTime.now(),
                            type: type,
                            note: noteController.text,
                            supplierId: selectedSupplier?.id,
                            supplierName: selectedSupplier?.name,
                            items: tempItems,
                          );

                          await _service.processTransaction(transaction);
                          if (mounted) Navigator.pop(ctx);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        type == TransactionType.import ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    type == TransactionType.import ? 'Nhập' : 'Xuất',
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập / Xuất Kho')),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _service.getTransactions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Lỗi tải dữ liệu'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final transactions = snapshot.data ?? [];
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final t = transactions[index];
              final isImport = t.type == TransactionType.import;
              final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(t.date);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Icon(
                    isImport ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isImport ? Colors.green : Colors.red,
                  ),
                  title: Text('${isImport ? "NHẬP" : "XUẤT"}: ${t.items.first.productName}'),
                  subtitle: Text('SL: ${t.items.first.quantity} | $dateStr\n${t.note}'),
                  trailing: Text(t.supplierName ?? '', style: const TextStyle(fontSize: 12)),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'export',
            onPressed: () => _showTransactionDialog(TransactionType.export),
            backgroundColor: Colors.red,
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'import',
            onPressed: () => _showTransactionDialog(TransactionType.import),
            backgroundColor: Colors.green,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
