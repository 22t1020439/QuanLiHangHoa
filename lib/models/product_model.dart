import 'package:cloud_firestore/cloud_firestore.dart';

enum ProductType { dong, noiBo }

class Product {
  final String? id;
  final String name;
  final int stock;
  final String unit;
  final ProductType type;
  final DateTime? updatedAt;

  Product({
    this.id,
    required this.name,
    required this.stock,
    required this.unit,
    required this.type,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'stock': stock,
      'unit': unit,
      'type': type.name,
      'updated_at': updatedAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      stock: data['stock'] ?? 0,
      unit: data['unit'] ?? '',
      type: data['type'] == 'noiBo' ? ProductType.noiBo : ProductType.dong,
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }
}
