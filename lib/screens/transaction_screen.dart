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

class _TransactionScreenState extends State<TransactionScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _service = FirestoreService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide correct FAB
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showTransactionDialog(
    TransactionType type, {
    TransactionModel? existingTx,
  }) async {
    // 1. Get initial data
    final productsDong = await _service.getProducts(ProductType.dong).first;
    final productsNoiBo = await _service.getProducts(ProductType.noiBo).first;
    final suppliers = await _service.getSuppliers().first;

    List<TransactionItem> tempItems = existingTx != null
        ? List.from(existingTx.items)
        : [];
    ProductType selectedCategory = ProductType.dong;
    Product? selectedProduct;
    Supplier? selectedSupplier = suppliers.isNotEmpty ? suppliers.first : null;

    if (existingTx != null && existingTx.supplierId != null) {
      selectedSupplier = suppliers.firstWhere(
        (s) => s.id == existingTx.supplierId,
        orElse: () => suppliers.first,
      );
    }

    final TextEditingController qtyController = TextEditingController();
    final TextEditingController noteController = TextEditingController(
      text: existingTx?.note ?? '',
    );

    void updateSelectedProduct(
      List<Product> products,
      StateSetter setDialogState,
    ) {
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
            List<Product> currentProducts = selectedCategory == ProductType.dong
                ? productsDong
                : productsNoiBo;

            return AlertDialog(
              title: Text(
                existingTx != null
                    ? 'Sửa Phiếu ${existingTx.code}'
                    : (type == TransactionType.import
                          ? 'Phiếu Nhập'
                          : 'Phiếu Xuất'),
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
                                  val == ProductType.dong
                                  ? productsDong
                                  : productsNoiBo;
                              updateSelectedProduct(
                                newProducts,
                                setDialogState,
                              );
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
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.name),
                                ),
                              )
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
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p.name),
                                    ),
                                  )
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
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
                              // Thay đổi dấu phẩy thành dấu chấm để parse double chính xác
                              final qtyText = qtyController.text.replaceAll(
                                ',',
                                '.',
                              );
                              double qty = double.tryParse(qtyText) ?? 0.0;
                              if (qty <= 0) return;

                              setDialogState(() {
                                tempItems.add(
                                  TransactionItem(
                                    productId: selectedProduct!.id!,
                                    productName: selectedProduct!.name,
                                    quantity: qty,
                                    productType: selectedProduct!.type.name,
                                  ),
                                );
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
                                    name: "",
                                    stock: 0,
                                    unit: "",
                                    type: ProductType.dong,
                                  ),
                                ),
                              );
                              unit = p.unit;

                              return Card(
                                child: ListTile(
                                  dense: true,
                                  title: Text(item.productName),
                                  subtitle: Text('SL: ${item.quantity} $unit'),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
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
                          try {
                            final transaction = TransactionModel(
                              id: existingTx?.id,
                              code:
                                  existingTx?.code ??
                                  '${type == TransactionType.import ? "PN" : "PX"}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                              date: existingTx?.date ?? DateTime.now(),
                              type: type,
                              note: noteController.text,
                              supplierId: selectedSupplier?.id,
                              supplierName: selectedSupplier?.name,
                              items: tempItems,
                            );

                            if (existingTx != null) {
                              await _service.updateTransaction(
                                existingTx,
                                transaction,
                              );
                            } else {
                              await _service.processTransaction(transaction);
                            }

                            if (mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Lỗi: $e')),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: type == TransactionType.import
                        ? Colors.green
                        : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    existingTx != null
                        ? 'Lưu thay đổi'
                        : (type == TransactionType.import ? 'Nhập' : 'Xuất'),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  void _showDetailDialog(TransactionModel t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Chi tiết phiếu ${t.code}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(t.date)}'),
              if (t.supplierName != null)
                Text('Nhà cung cấp: ${t.supplierName}'),
              Text('Ghi chú: ${t.note}'),
              const Divider(),
              const Text(
                'Danh sách mặt hàng:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: t.items.length,
                  itemBuilder: (context, index) {
                    final item = t.items[index];
                    return ListTile(
                      dense: true,
                      title: Text(item.productName),
                      subtitle: Text('Số lượng: ${item.quantity}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập / Xuất Kho'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.download), text: 'Nhập Kho'),
            Tab(icon: Icon(Icons.upload), text: 'Xuất Kho'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionList(TransactionType.import),
          _buildTransactionList(TransactionType.export),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              heroTag: 'import',
              onPressed: () => _showTransactionDialog(TransactionType.import),
              backgroundColor: Colors.green,
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              heroTag: 'export',
              onPressed: () => _showTransactionDialog(TransactionType.export),
              backgroundColor: Colors.red,
              child: const Icon(Icons.remove),
            ),
    );
  }

  Widget _buildTransactionList(TransactionType type) {
    return StreamBuilder<List<TransactionModel>>(
      stream: _service.getTransactions(type: type),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Lỗi tải dữ liệu'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final transactions = snapshot.data ?? [];
        if (transactions.isEmpty) {
          return Center(
            child: Text(
              type == TransactionType.import
                  ? 'Chưa có phiếu nhập nào'
                  : 'Chưa có phiếu xuất nào',
            ),
          );
        }
        return ListView.builder(
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final t = transactions[index];
            final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(t.date);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                onTap: () => _showDetailDialog(t),
                leading: CircleAvatar(
                  backgroundColor: type == TransactionType.import
                      ? Colors.green[50]
                      : Colors.red[50],
                  child: Icon(
                    type == TransactionType.import
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: type == TransactionType.import
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                title: Text(
                  '${t.code}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${t.items.length} mặt hàng | $dateStr\n${t.note}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () =>
                          _showTransactionDialog(type, existingTx: t),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(t),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(TransactionModel t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa phiếu ${t.code}?\nSố lượng tồn kho của các mặt hàng sẽ được tự động hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await _service.deleteTransaction(t);
                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              }
            },
            child: const Text('Xóa phiếu'),
          ),
        ],
      ),
    );
  }
}
