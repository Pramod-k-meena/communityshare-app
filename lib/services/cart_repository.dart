import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item.dart';
import 'dtdc_integration.dart'; // import DTDC integration file

class cartRepository {
  static final cartRepository instance = cartRepository._();
  cartRepository._();

  // Add an item to cart
  Future<bool> cartItem(Item item) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Add to user's carts collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('carts')
          .doc(item.id)
          .set({
        'itemId': item.id,
        'title': item.title,
        'imageUrl': item.imageUrl,
        'distance': item.distance,
        'ownerId': item.ownerId,
        'ownerName': item.ownerName,
        'cartedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      print('Error carting item: $e');
      return false;
    }
  }

  // Remove an item from cart
  Future<bool> removecart(String itemId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('carts')
          .doc(itemId)
          .delete();

      return true;
    } catch (e) {
      print('Error removing cart: $e');
      return false;
    }
  }

  // Check if an item is carted
  Future<bool> isItemcarted(String itemId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final cartDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('carts')
          .doc(itemId)
          .get();

      return cartDoc.exists;
    } catch (e) {
      print('Error checking cart status: $e');
      return false;
    }
  }

  // Get all carted items
  Future<List<Item>> getcartedItems() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final cartsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('carts')
          .orderBy('cartedAt', descending: true)
          .get();

      return cartsSnapshot.docs.map((doc) {
        final data = doc.data();
        return Item(
          id: doc.id,
          title: data['title'] ?? '',
          imageUrl: data['imageUrl'] ?? '',
          channelId: data['channelId'] ?? '',
          distance: (data['distance'] ?? 0).toDouble(),
          ownerId: data['ownerId'],
          ownerName: data['ownerName'],
        );
      }).toList();
    } catch (e) {
      print('Error getting carted items: $e');
      return [];
    }
  }

  // Updated checkoutCart method with delivery details.
  Future<bool> checkoutCart(
      {required String deliveryDate, required double deliveryFee}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Retrieve carted items from Firestore.
      final cartsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('carts')
          .get();

      // Prepare order details. Customize these fields per DTDC API requirements.
      final orderDetails = {
        'userId': user.uid,
        'orderDate': DateTime.now().toIso8601String(),
        'deliveryDate': deliveryDate,
        'deliveryFee': deliveryFee,
        'items': cartsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'itemId': doc.id,
            'title': data['title'],
            // add additional fields if needed.
          };
        }).toList(),
        // Optionally include other order details (shipping address, etc.)
      };

      // Call DTDC integration call.
      bool success = await DTDCIntegration.integrate(orderDetails);
      return success;
    } catch (e) {
      print('Error during checkout: $e');
      return false;
    }
  }

  // NEW: Method to get count of carted items.
  Future<int> getCartCount() async {
    final items = await getcartedItems();
    return items.length;
  }

  // NEW: Checkout for borrow basket with DTDC integration.
  Future<bool> checkoutBorrowBasket() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Retrieve borrow basket items from Firestore.
      final cartsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('carts')
          .get();

      // Prepare order details according to DTDC requirements.
      final orderDetails = {
        'userId': user.uid,
        'orderDate': DateTime.now().toIso8601String(),
        'items': cartsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'itemId': doc.id,
            'title': data['title'],
            // Add additional fields such as quantity, price, etc.
          };
        }).toList(),
        // Optionally include shipping address, total price, etc.
      };

      // Trigger DTDC integration.
      bool success = await DTDCIntegration.integrate(orderDetails);
      return success;
    } catch (e) {
      print('Error during borrow basket checkout: $e');
      return false;
    }
  }
}
