import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/supplier_model.dart';
import '../models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- PRODUCTS ---
  Stream<List<Product>> getProducts(ProductType type) {
    return _db
        .collection('products')
        .where('type', isEqualTo: type.name)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Product.fromFirestore(doc)).toList(),
        );
  }

  Future<void> saveProduct(Product product) {
    var options = SetOptions(merge: true);
    if (product.id == null) {
      return _db.collection('products').add(product.toMap());
    } else {
      return _db
          .collection('products')
          .doc(product.id)
          .set(product.toMap(), options);
    }
  }

  Future<void> deleteProduct(String id) {
    return _db.collection('products').doc(id).delete();
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

  Future<void> saveSupplier(Supplier supplier) {
    if (supplier.id == null) {
      return _db.collection('suppliers').add(supplier.toMap());
    } else {
      return _db
          .collection('suppliers')
          .doc(supplier.id)
          .update(supplier.toMap());
    }
  }

  Future<void> deleteSupplier(String id) {
    return _db.collection('suppliers').doc(id).delete();
  }

  // --- TRANSACTIONS (IMPORT / EXPORT) ---
  Future<void> processTransaction(TransactionModel transaction) async {
    final batch = _db.batch();

    // 1. Create the transaction record
    final transactionRef = _db.collection('transactions').doc();
    batch.set(transactionRef, transaction.toMap());

    // 2. Update stock for each item in the transaction
    for (var item in transaction.items) {
      final productRef = _db.collection('products').doc(item.productId);

      // We use FieldValue.increment for atomic stock update
      int incrementValue = transaction.type == TransactionType.import
          ? item.quantity
          : -item.quantity;

      batch.update(productRef, {
        'stock': FieldValue.increment(incrementValue),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    return batch.commit();
  }

  Stream<List<TransactionModel>> getTransactions() {
    return _db
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TransactionModel.fromFirestore(doc))
              .toList(),
        );
  }

  // --- DASHBOARD STATS ---
  Stream<Map<String, dynamic>> getDashboardStats() {
    return _db.collection('products').snapshots().map((snapshot) {
      final products = snapshot.docs
          .map((doc) => Product.fromFirestore(doc))
          .toList();
      int totalItems = products.length;
      int lowStockCount = products.where((p) => p.stock <= 5).length;
      int totalStock = products.fold(0, (sum, p) => sum + p.stock);

      return {
        'totalItems': totalItems,
        'lowStockCount': lowStockCount,
        'totalStock': totalStock,
      };
    });
  }
}
