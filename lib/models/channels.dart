import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ChannelType { category, text, voice, create }

class SubCategory {
  final String id;
  final String name;

  SubCategory({
    required this.id,
    required this.name,
  });

  factory SubCategory.fromMap(Map<String, dynamic> data, String id) {
    return SubCategory(
      id: id,
      name: (data['name'] != null && data['name'].toString().isNotEmpty)
          ? data['name']
          : id,
    );
  }
}

class Channel {
  final String id;
  final String name;
  final bool approved;
  final String? description;

  Channel({
    required this.id,
    required this.name,
    required this.approved,
    this.description,
  });

  factory Channel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Channel(
      id: doc.id,
      name: data['name'] ?? '',
      approved: data['approved'] ?? false,
      description: data['description'],
    );
  }

  // Fetch subcategories stored as a subcollection within the channel document.
  Future<List<SubCategory>> fetchSubCategories() async {
    debugPrint("Fetching subcategories for channel $id");
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('channels')
        .doc(id)
        .collection('subcategories')
        .get();
    debugPrint("Fetched ${snapshot.docs.length} subcategories for channel $id");
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return SubCategory.fromMap(data, doc.id);
    }).toList();
  }
}
