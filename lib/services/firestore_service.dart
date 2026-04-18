import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/supplier_model.dart';
import '../models/transaction_model.dart';
import '../models/activity_log_model.dart';
import 'file_helper.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- LOGS ---
  Stream<List<ActivityLog>> getLogs() {
    return _db.collection('logs').snapshots().map((snapshot) {
      final logs = snapshot.docs
          .map((doc) => ActivityLog.fromFirestore(doc))
          .toList();
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    });
  }

  void _addLog(WriteBatch batch, ActivityLog log) {
    final ref = _db.collection('logs').doc();
    batch.set(ref, log.toMap());
  }

  // --- SETTINGS & CLEANUP ---
  Future<int> getRetentionDays() async {
    final doc = await _db.collection('settings').doc('history').get();
    if (doc.exists) {
      return doc.data()?['retentionDays'] ?? 30;
    }
    return 30; // Mặc định 30 ngày
  }

  Future<void> updateRetentionDays(int days) async {
    await _db.collection('settings').doc('history').set({
      'retentionDays': days,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cleanupOldLogs() async {
    final days = await getRetentionDays();
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    final oldLogs = await _db
        .collection('logs')
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();

    if (oldLogs.docs.isNotEmpty) {
      final batch = _db.batch();
      for (var doc in oldLogs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> deleteAllLogs() async {
    final logs = await _db.collection('logs').get();
    if (logs.docs.isNotEmpty) {
      final batch = _db.batch();
      for (var doc in logs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // --- PRODUCTS ---
  Stream<List<Product>> getProducts(ProductType type) {
    return _db
        .collection('products')
        .where('type', isEqualTo: type.name)
        .snapshots()
        .map((snapshot) {
          final products = snapshot.docs
              .map((doc) => Product.fromFirestore(doc))
              .toList();
          products.sort((a, b) => a.order.compareTo(b.order));
          return products;
        });
  }

  Future<void> saveProduct(Product product) async {
    final batch = _db.batch();
    var options = SetOptions(merge: true);

    if (product.id == null) {
      final snapshot = await _db
          .collection('products')
          .where('type', isEqualTo: product.type.name)
          .get();

      int maxOrder = -1;
      for (var doc in snapshot.docs) {
        int currentOrder = doc.data()['order'] ?? 0;
        if (currentOrder > maxOrder) maxOrder = currentOrder;
      }

      final newProductMap = product.toMap();
      newProductMap['order'] = maxOrder + 1;

      final docRef = _db.collection('products').doc();
      batch.set(docRef, newProductMap);

      _addLog(
        batch,
        ActivityLog(
          action: 'Thêm hàng mới',
          details:
              'Tên: ${product.name}, Loại: ${product.type == ProductType.dong ? "Đà Nẵng" : "Hàng Nội Bộ"}, Đơn vị: ${product.unit}',
          timestamp: DateTime.now(),
          type: LogType.product,
        ),
      );
    } else {
      final docRef = _db.collection('products').doc(product.id);
      batch.set(docRef, product.toMap(), options);

      _addLog(
        batch,
        ActivityLog(
          action: 'Cập nhật hàng',
          details: 'Cập nhật thông tin mặt hàng: ${product.name}',
          timestamp: DateTime.now(),
          type: LogType.product,
        ),
      );
    }
    return batch.commit();
  }

  Future<void> updateProductsOrder(List<Product> products) async {
    final batch = _db.batch();
    for (int i = 0; i < products.length; i++) {
      final ref = _db.collection('products').doc(products[i].id);
      batch.update(ref, {'order': i});
    }
    return batch.commit();
  }

  Future<void> deleteProduct(Product product) async {
    final batch = _db.batch();
    batch.delete(_db.collection('products').doc(product.id));
    _addLog(
      batch,
      ActivityLog(
        action: 'Xóa hàng',
        details: 'Đã xóa mặt hàng: ${product.name}',
        timestamp: DateTime.now(),
        type: LogType.product,
      ),
    );
    return batch.commit();
  }

  // --- SUPPLIERS ---
  Stream<List<Supplier>> getSuppliers() {
    return _db
        .collection('suppliers')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Supplier.fromFirestore(doc)).toList(),
        );
  }

  Future<void> saveSupplier(Supplier supplier) async {
    final batch = _db.batch();
    if (supplier.id == null) {
      final docRef = _db.collection('suppliers').doc();
      batch.set(docRef, supplier.toMap());
      _addLog(
        batch,
        ActivityLog(
          action: 'Thêm nhà cung cấp',
          details: 'Tên: ${supplier.name}',
          timestamp: DateTime.now(),
          type: LogType.supplier,
        ),
      );
    } else {
      final docRef = _db.collection('suppliers').doc(supplier.id);
      batch.update(docRef, supplier.toMap());
      _addLog(
        batch,
        ActivityLog(
          action: 'Cập nhật nhà cung cấp',
          details: 'Cập nhật thông tin: ${supplier.name}',
          timestamp: DateTime.now(),
          type: LogType.supplier,
        ),
      );
    }
    return batch.commit();
  }

  Future<void> deleteSupplier(Supplier supplier) async {
    final batch = _db.batch();
    batch.delete(_db.collection('suppliers').doc(supplier.id));
    _addLog(
      batch,
      ActivityLog(
        action: 'Xóa nhà cung cấp',
        details: 'Đã xóa nhà cung cấp: ${supplier.name}',
        timestamp: DateTime.now(),
        type: LogType.supplier,
      ),
    );
    return batch.commit();
  }

  // --- TRANSACTIONS (IMPORT / EXPORT) ---
  Future<void> processTransaction(TransactionModel transaction) async {
    final batch = _db.batch();

    final transactionRef = _db.collection('transactions').doc();
    batch.set(transactionRef, transaction.toMap());

    for (var item in transaction.items) {
      final productRef = _db.collection('products').doc(item.productId);

      double incrementValue = transaction.type == TransactionType.import
          ? item.quantity
          : -item.quantity;

      batch.update(productRef, {
        'stock': FieldValue.increment(incrementValue),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    _addLog(
      batch,
      ActivityLog(
        action: transaction.type == TransactionType.import
            ? 'Nhập kho'
            : 'Xuất kho',
        details:
            'Mã phiếu: ${transaction.code}, ${transaction.items.length} mặt hàng',
        timestamp: DateTime.now(),
        type: LogType.transaction,
      ),
    );

    return batch.commit();
  }

  Future<void> updateTransaction(
    TransactionModel oldTx,
    TransactionModel newTx,
  ) async {
    final batch = _db.batch();
    final docRef = _db.collection('transactions').doc(oldTx.id);

    for (var item in oldTx.items) {
      final productRef = _db.collection('products').doc(item.productId);
      double revertValue = oldTx.type == TransactionType.import
          ? -item.quantity
          : item.quantity;
      batch.update(productRef, {
        'stock': FieldValue.increment(revertValue),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    for (var item in newTx.items) {
      final productRef = _db.collection('products').doc(item.productId);
      double applyValue = newTx.type == TransactionType.import
          ? item.quantity
          : -item.quantity;
      batch.update(productRef, {
        'stock': FieldValue.increment(applyValue),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    batch.set(docRef, newTx.toMap());

    _addLog(
      batch,
      ActivityLog(
        action: 'Cập nhật phiếu',
        details: 'Đã cập nhật chi tiết phiếu: ${oldTx.code}',
        timestamp: DateTime.now(),
        type: LogType.transaction,
      ),
    );

    return batch.commit();
  }

  Stream<List<TransactionModel>> getTransactions({TransactionType? type}) {
    Query<Map<String, dynamic>> query = _db.collection('transactions');

    if (type != null) {
      query = query.where('type', isEqualTo: type.name);
    }

    return query.snapshots().map((snapshot) {
      final transactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
      transactions.sort((a, b) => b.date.compareTo(a.date));
      return transactions;
    });
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    final batch = _db.batch();

    final transactionRef = _db.collection('transactions').doc(transaction.id);
    batch.delete(transactionRef);

    for (var item in transaction.items) {
      final productRef = _db.collection('products').doc(item.productId);

      double revertValue = transaction.type == TransactionType.import
          ? -item.quantity
          : item.quantity;

      batch.update(productRef, {
        'stock': FieldValue.increment(revertValue),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    _addLog(
      batch,
      ActivityLog(
        action: 'Xóa phiếu',
        details: 'Đã xóa phiếu ${transaction.code}',
        timestamp: DateTime.now(),
        type: LogType.transaction,
        extraData: transaction.toMap(),
      ),
    );

    return batch.commit();
  }

  Future<void> restoreTransaction(ActivityLog log) async {
    if (log.extraData == null) return;

    final transaction = TransactionModel.fromMap(log.extraData!);
    final batch = _db.batch();

    final docRef = _db.collection('transactions').doc();
    batch.set(docRef, transaction.toMap());

    for (var item in transaction.items) {
      final productRef = _db.collection('products').doc(item.productId);
      double applyValue = transaction.type == TransactionType.import
          ? item.quantity
          : -item.quantity;
      batch.update(productRef, {
        'stock': FieldValue.increment(applyValue),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    batch.delete(_db.collection('logs').doc(log.id));
    _addLog(
      batch,
      ActivityLog(
        action: 'Khôi phục phiếu',
        details: 'Đã khôi phục phiếu ${transaction.code}',
        timestamp: DateTime.now(),
        type: LogType.transaction,
      ),
    );

    return batch.commit();
  }

  // --- DASHBOARD STATS ---
  Stream<Map<String, dynamic>> getDashboardStats() {
    return _db.collection('products').snapshots().asyncMap((snapshot) async {
      final products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();

      int countDong = products.where((p) => p.type == ProductType.dong).length;
      int countNoiBo = products
          .where((p) => p.type == ProductType.noiBo)
          .length;

      // Tính tổng xuất hàng Đà Nẵng trong tháng này
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final txSnapshot = await _db
          .collection('transactions')
          .where('type', isEqualTo: TransactionType.export.name)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(firstDayOfMonth),
          )
          .get();

      double monthExportDong = 0;
      for (var doc in txSnapshot.docs) {
        final tx = TransactionModel.fromFirestore(doc);
        for (var item in tx.items) {
          if (item.productType == 'dong') {
            monthExportDong += item.quantity;
          }
        }
      }

      return {
        'countDong': countDong,
        'countNoiBo': countNoiBo,
        'monthExportDong': monthExportDong,
      };
    });
  }

  // --- EXPORT ---
  Future<void> exportStockToExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel['Tồn kho'];
    excel.delete('Sheet1');

    sheet.appendRow([
      TextCellValue('Tên sản phẩm'),
      TextCellValue('Loại'),
      TextCellValue('Số lượng'),
      TextCellValue('Đơn vị'),
    ]);

    final productsSnapshot = await _db.collection('products').get();
    for (var doc in productsSnapshot.docs) {
      final p = Product.fromFirestore(doc);
      sheet.appendRow([
        TextCellValue(p.name),
        TextCellValue(p.type == ProductType.dong ? 'Đà Nẵng' : 'Nội bộ'),
        DoubleCellValue(p.stock),
        TextCellValue(p.unit),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      await FileHelper.saveAndShare(fileBytes, 'bao_cao_ton_kho.xlsx');
    }
  }
}
