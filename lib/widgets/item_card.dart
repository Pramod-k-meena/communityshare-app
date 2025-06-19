import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web_app/models/item.dart';
import 'package:web_app/widgets/cart_button.dart';
import 'package:web_app/widgets/chat.dart';
import 'package:share_plus/share_plus.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final String channelId;
  final bool showRequestButton;
  final bool isProfile; // New parameter to indicate if shown in profile page
  final bool borrowApproved; // New parameter to indicate if borrow is approved

  const ItemCard({
    super.key,
    required this.item,
    required this.channelId,
    this.showRequestButton = false,
    this.isProfile = false, // Default to false
    this.borrowApproved = false, // Default to false
  });

  void _contact(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to contact the owner')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFEBE4DF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: ChatWidget(
            ownerId: item.ownerId ?? 'unknown',
            itemId: item.id,
            itemTitle: item.title,
            currentUserId: currentUser.uid,
          ),
        ),
      ),
    );
  }

  Future<void> _requestOwner(BuildContext context) async {
    if (channelId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid ChannelId on item')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('borrow_requests').add({
      'itemId': item.id,
      'itemTitle': item.title,
      'channelId': channelId, // Ensure the channelId gets stored in the request
      'ownerId': item.ownerId,
      'ownerName': item.ownerName,
      'requestorId': FirebaseAuth.instance.currentUser!.uid,
      'requestorName':
          FirebaseAuth.instance.currentUser!.displayName ?? 'Unknown',
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Borrow request sent to owner')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return LayoutBuilder(
      builder: (context, constraints) {
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F1),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Container(
                            width: double.infinity,
                            color: Colors.grey[200],
                            child: Image.network(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            (loadingProgress
                                                    .expectedTotalBytes ??
                                                1)
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.broken_image,
                                      size: 64, color: Colors.grey),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: const Icon(Icons.info_outline,
                              color: Colors.brown),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Item Info'),
                                backgroundColor: const Color(0xFFBA8B64),
                                content: const Text(
                                  'Borrowing this item can enable you to save 50 kg CO2:\nYou\'re a Climate Champion!',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                                titleTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text(
                                      'OK',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${item.distance} kms away',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share_outlined,
                                  color: Color(0xFFB37B5F)),
                              onPressed: () async {
                                try {
                                  final String shareText =
                                      'Check out this item: ${item.title}\n'
                                      'Only ${item.distance} km away!\n\n'
                                      'Share and promote sustainable consumption 🌱';

                                  final String shareUrl =
                                      'https://reviveandthrive.app/items/${item.id}';

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Opening share dialog...')),
                                  );

                                  await Share.share(
                                    '$shareText\n$shareUrl',
                                    subject: 'Check out ${item.title}',
                                  );

                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Failed to share: ${e.toString()}')),
                                  );
                                }
                              },
                            ),
                            // Always show delete option in profile view
                            if (currentUser != null &&
                                (currentUser.uid == item.ownerId || isProfile))
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Delete Item'),
                                        content: const Text(
                                            'Are you sure you want to delete this item?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (confirmed == true) {
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('channels')
                                          .doc(channelId)
                                          .collection('items')
                                          .doc(item.id)
                                          .delete();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Item deleted successfully')),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Error deleting item: $e')),
                                      );
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                        // Only show Contact button if not in profile view
                        if (!isProfile)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB37B5F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => _contact(context),
                            child: const Text('CONTACT'),
                          ),
                        // Only show Request button if not in profile view and showRequestButton is true
                        if (showRequestButton && !isProfile)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB37B5F),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () => _requestOwner(context),
                            child: const Text('REQUEST'),
                          ),
                        // Edit button for profile view
                        if (isProfile)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () {
                              // Show edit dialog or navigate to edit page
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Edit functionality will be implemented soon'),
                                ),
                              );
                            },
                            child: const Text('EDIT'),
                          ),
                        // Only show cart button if not in profile view
                        if (!isProfile) cartButton(item: item),
                        // Show CHECKOUT button if borrow is approved
                        if (borrowApproved)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Checkout functionality will be implemented soon'),
                                ),
                              );
                            },
                            child: const Text('CHECKOUT'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
