import 'package:flutter/material.dart';
import 'package:web_app/services/cart_repository.dart';
import '../models/item.dart';
import '../widgets/item_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Simple model for a delivery option.
class DeliveryOption {
  final String date; // e.g. "Tomorrow", "In 2 Days", etc.
  final double fee;
  DeliveryOption({required this.date, required this.fee});
}

// A dialog widget for selecting a delivery option.
class DeliveryOptionsDialog extends StatelessWidget {
  final List<DeliveryOption> options;
  const DeliveryOptionsDialog({super.key, required this.options});

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Select Delivery Option'),
      children: options.map((option) {
        return SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context, option);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(option.date),
              Text('\$${option.fee.toStringAsFixed(2)}'),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _isProcessing = false;
  Future<List<Item>>? _cartedItems;
  List<Item> _approvedItems = []; // Track approved items

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    _cartedItems = cartRepository.instance.getcartedItems();
    // We'll check each item's approval status when displaying them
  }

  // Check if an item is approved for borrowing
  Future<bool> _isItemApproved(Item item) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      // Query the user's requests collection to see if this item has been approved
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('requests')
          .where('itemId', isEqualTo: item.id)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking item approval: $e');
      return false;
    }
  }

  // Show the delivery options dialog and return user's choice.
  Future<DeliveryOption?> _selectDeliveryOption() async {
    print("Opening DeliveryOptionsDialog...");
    List<DeliveryOption> options = [
      DeliveryOption(date: 'Tomorrow', fee: 5.0),
      DeliveryOption(date: 'In 2 Days', fee: 3.0),
      DeliveryOption(date: 'In 3 Days', fee: 2.0),
    ];
    DeliveryOption? option = await showDialog<DeliveryOption>(
      context: context,
      builder: (context) => DeliveryOptionsDialog(options: options),
    );
    print("Selected delivery option: ${option?.date}");
    return option;
  }

  Future<void> _checkout() async {
    // First, let the user choose a delivery option.
    DeliveryOption? selectedOption = await _selectDeliveryOption();
    if (selectedOption == null) {
      print("No delivery option selected.");
      return; // User cancelled selection.
    }

    setState(() {
      _isProcessing = true;
    });

    bool success = await cartRepository.instance.checkoutCart(
      deliveryDate: selectedOption.date,
      deliveryFee: selectedOption.fee,
    );

    setState(() {
      _isProcessing = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Order placed. Delivery charges applied.')),
      );
      // Optionally clear the cart UI.
      setState(() {
        _cartedItems = null;
        _approvedItems = [];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order failed. Please try again.')),
      );
    }
  }

  // Check if all items have been approved
  bool _areAllItemsApproved(List<Item> items) {
    if (items.isEmpty) return false;
    return _approvedItems.length == items.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        backgroundColor: const Color(0xFFA76D4B),
      ),
      body: FutureBuilder<List<Item>>(
        future: _cartedItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFA76D4B),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No carted items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            );
          }

          final items = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width < 600
                        ? 2
                        : MediaQuery.of(context).size.width < 900
                            ? 3
                            : 4,
                    childAspectRatio: 1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return FutureBuilder<bool>(
                        future: _isItemApproved(items[index]),
                        builder: (context, approvalSnapshot) {
                          final isApproved = approvalSnapshot.data ?? false;

                          // Track approved items for the CHECKOUT ALL button
                          if (isApproved &&
                              !_approvedItems.contains(items[index])) {
                            _approvedItems.add(items[index]);
                          }

                          return ItemCard(
                            item: items[index],
                            channelId: items[index].ownerId ?? '',
                            showRequestButton:
                                !isApproved, // Only show REQUEST if not approved
                            borrowApproved:
                                isApproved, // Show CHECKOUT if approved
                          );
                        });
                  },
                ),
              ),

              // Add CHECKOUT ALL button if all items are approved
              if (_areAllItemsApproved(items) && items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: const Text(
                      'CHECKOUT ALL ITEMS',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _checkout,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
