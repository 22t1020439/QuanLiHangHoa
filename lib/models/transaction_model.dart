import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { import, export }

class TransactionItem {
  final String productId;
  final String productName;
  final int quantity;
  final String productType; // 'dong' or 'noiBo'

  TransactionItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.productType,
  });

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'product_type': productType,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '',
      quantity: map['quantity'] ?? 0,
      productType: map['product_type'] ?? 'dong',
    );
  }
}

class TransactionModel {
  final String? id;
  final DateTime date;
  final String note;
  final String? supplierId;
  final String? supplierName;
  final TransactionType type;
  final List<TransactionItem> items;

  TransactionModel({
    this.id,
    required this.date,
    this.note = '',
    this.supplierId,
    this.supplierName,
    required this.type,
    required this.items,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'note': note,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'type': type.name,
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      date: (data['date'] as Timestamp).toDate(),
      note: data['note'] ?? '',
      supplierId: data['supplier_id'],
      supplierName: data['supplier_name'],
      type: data['type'] == 'export' ? TransactionType.export : TransactionType.import,
      items: (data['items'] as List? ?? [])
          .map((i) => TransactionItem.fromMap(i))
          .toList(),
    );
  }
}
