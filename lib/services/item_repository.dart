import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_app/models/item.dart';
import 'package:web_app/services/content_repository.dart';

class ItemRepository {
  ItemRepository._privateConstructor();
  static final ItemRepository instance = ItemRepository._privateConstructor();

  // For API integration when ready
  Future<List<Item>> getItems({
    required String channelId,
    required bool isBorrow,
    ItemFilter? filter,
    String? subcategoryId,
  }) async {
    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;

      // Create a query for all items in the channel
      final QuerySnapshot itemsSnapshot = await FirebaseFirestore.instance
          .collection('channels')
          .doc(channelId)
          .collection('items')
          .get();

      List<Item> items = itemsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Item(
          id: doc.id,
          title: data['title'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          distance: data['distance']?.toDouble() ?? 0.0,
          channelId: data['channelId'] ?? '',
          ownerId: data['ownerId'],
          ownerName: data['ownerName'] ?? 'Unknown User',
          subcategory: data['subcategory'],
          itemCategory: data['itemCategory'],
        );
      }).toList();

      // Filter by subcategory if provided
      if (subcategoryId != null && subcategoryId.isNotEmpty) {
        items = items.where((item) => 
          item.subcategory != null && 
          _getSubcategoryId(item.subcategory!) == subcategoryId
        ).toList();
        debugPrint('Filtered by subcategoryId: $subcategoryId. Found ${items.length} items.');
      }

      // Filter out the current user's items from the borrow view
      if (isBorrow && currentUser != null) {
        items = items.where((item) => item.ownerId != currentUser.uid).toList();
        debugPrint(
            'Filtered out current user\'s items. Showing ${items.length} items.');
      }

      return items;
    } catch (e) {
      debugPrint('Error fetching items from Firestore: $e');

      // Fallback to local storage if Firestore fails
      final items = ContentRepository.instance
          .getBorrowItems(channelId)
          .map((map) => Item.fromMap(map['id'], map))
          .toList();
      return items;
    }
  }
  
  // Helper function to get subcategory ID from full path or name
  String _getSubcategoryId(String subcategory) {
    // This assumes subcategory could be stored as "subcategoryId" or as a path like "subcategories/subcategoryId"
    final parts = subcategory.split('/');
    return parts.last;
  }

  Future<List<Item>> getItemsBySubCategory({
    required String channelId,
    required String subCategoryId,
  }) async {
    try {
      // Directly get the subcategory document that contains the items as fields
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('channels')
              .doc(channelId)
              .collection('subcategories')
              .doc(subCategoryId)
              .get();

      if (!snapshot.exists) {
        debugPrint('Subcategory document not found: $subCategoryId');
        return [];
      }

      final data = snapshot.data() ?? {};
      List<Item> items = [];

      // Store the subcategory name for reference
      final String subcategoryName = data['name'] ?? subCategoryId;

      // Process each field in the document (except special fields like 'name')
      // Fields like 'Bicycles:', 'Car-Sharing:', 'Scooters:', 'Skateboards:'
      data.forEach((key, value) {
        // Skip any metadata fields that aren't item categories
        if (key == 'name' || key == 'id' || value == null) return;

        // Create an item from each field, storing both subcategory and itemCategory
        items.add(Item(
          id: key,
          title: key, // Use the key as the title (e.g., "Bicycles")
          imageUrl: '',
          distance: 0.0,
          channelId: channelId,
          subcategory: subcategoryName, // Store the subcategory name
          itemCategory: key, // Store the item category name
        ));
      });

      debugPrint(
          'Found ${items.length} item categories in subcategory $subCategoryId');
      return items;
    } catch (e) {
      debugPrint(
          'Error fetching item categories for subcategory $subCategoryId: $e');
      return [];
    }
  }

  Future<bool> submitItem({
    required String channelId,
    required bool isBorrow,
    required Item item,
    PlatformFile? pickedImage,
  }) async {
    try {
      // Store locally using ContentRepository if needed.
      if (isBorrow) {
        ContentRepository.instance.addBorrowItem(channelId, item.toMap());
      }

      // Prepare data for Firestore. Include the new channelId field.
      Map<String, dynamic> itemData = {
        'title': item.title,
        'distance': item.distance,
        'timestamp': Timestamp.now(),
        'channelId': channelId, // This must be a valid, non-empty string.
        'ownerId': FirebaseAuth.instance.currentUser?.uid,
        'ownerName':
            FirebaseAuth.instance.currentUser?.displayName ?? 'Unknown User',
        // Add subcategory and itemCategory to stored data
        if (item.subcategory != null) 'subcategory': item.subcategory,
        if (item.itemCategory != null) 'itemCategory': item.itemCategory,
      };

      // Handle image upload if any.
      String? imageUrl;
      if (pickedImage != null && pickedImage.path != null) {
        final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        if (kIsWeb) {
          // Web platform
          final ref = FirebaseStorage.instance
              .ref()
              .child('channels')
              .child(channelId)
              .child('items')
              .child(fileName);
          final metadata = SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {'cacheControl': 'public,max-age=3600'},
          );
          await ref.putData(pickedImage.bytes!, metadata);
          imageUrl = await ref.getDownloadURL();
        } else {
          // Mobile platform
          final file = File(pickedImage.path!);
          final ref = FirebaseStorage.instance
              .ref()
              .child('channels')
              .child(channelId)
              .child('items')
              .child(fileName);
          await ref.putFile(file);
          imageUrl = await ref.getDownloadURL();
        }
        itemData['imageUrl'] = imageUrl;
      } else if (item.imageUrl.isNotEmpty) {
        itemData['imageUrl'] = item.imageUrl;
      }

      // Save to Firestore under the channel's 'items' subcollection.
      await FirebaseFirestore.instance
          .collection('channels')
          .doc(channelId)
          .collection('items')
          .add(itemData);
      return true;
    } catch (e) {
      debugPrint('Error submitting item: $e');
      return false;
    }
  }

  // Existing submitLendItem method
  Future<bool> submitLendItem({
    required String channelId,
    required Item item,
    PlatformFile? pickedImage,
  }) async {
    // Implementation of existing method
    return await submitItem(
      channelId: channelId,
      isBorrow: true,
      item: item,
      pickedImage: pickedImage,
    );
  }
}
