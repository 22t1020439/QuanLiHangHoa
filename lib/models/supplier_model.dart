import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  final String? id;
  final String name;
  final String address;
  final String phone;

  Supplier({
    this.id,
    required this.name,
    this.address = '',
    this.phone = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
    };
  }

  factory Supplier.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Supplier(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
    );
  }
}
