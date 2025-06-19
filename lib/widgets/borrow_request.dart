import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BorrowApprovalSection extends StatefulWidget {
  const BorrowApprovalSection({super.key});

  @override
  State<BorrowApprovalSection> createState() => _BorrowApprovalSectionState();
}

class _BorrowApprovalSectionState extends State<BorrowApprovalSection> {
  Future<void> createBorrowRequest(dynamic item) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please sign in to create a borrow request')),
      );
      return;
    }
    try {
      // Create the request in the owner's approvals collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(item.ownerId)
          .collection('approvals')
          .add({
        'itemId': item.id,
        'itemTitle': item.title,
        'channelId': item.channelId,
        'ownerId': item.ownerId,
        'ownerName': item.ownerName,
        'requestorId': currentUser.uid,
        'requestorName': currentUser.displayName ?? 'Unknown',
        'status': 'pending', // pending, approved, or rejected
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // Also record the request in the requester's requests collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('requests')
          .add({
        'itemId': item.id,
        'itemTitle': item.title,
        'channelId': item.channelId,
        'ownerId': item.ownerId,
        'ownerName': item.ownerName,
        'status': 'pending', // pending, approved, or rejected
        'requestedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrow request created successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create borrow request: $e')),
      );
    }
  }

  // Method to handle the approval action
  Future<void> _handleApproval(String requestId, String channelId,
      String itemId, String requestorId, bool isApproved) async {
    try {
      // Get the item's document reference
      final itemRef = FirebaseFirestore.instance
          .collection('channels')
          .doc(channelId)
          .collection('items')
          .doc(itemId);

      // Check if the document exists
      final itemSnapshot = await itemRef.get();
      if (!itemSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item not found.')),
        );
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You must be signed in to approve requests')),
        );
        return;
      }

      final timestamp = FieldValue.serverTimestamp();

      // Update the approval status in the owner's collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('approvals')
          .doc(requestId)
          .update({
        'status': isApproved ? 'approved' : 'rejected',
        'actionDate': timestamp,
      });

      // Also update the same request in the requestor's collection
      // First find the matching request
      final requestorRequestsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(requestorId)
          .collection('requests');

      final matchingRequests = await requestorRequestsRef
          .where('itemId', isEqualTo: itemId)
          .where('ownerId', isEqualTo: currentUser.uid)
          .get();

      // Update all matching requests (should be just one)
      for (final doc in matchingRequests.docs) {
        await requestorRequestsRef.doc(doc.id).update({
          'status': isApproved ? 'approved' : 'rejected',
          'actionDate': timestamp,
        });
      }

      // If approved, update the item visibility and approval status
      if (isApproved) {
        await itemRef.update({
          'visible': false,
          'borrowApproved': true,
          'borrowerId': requestorId,
        });
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApproved
              ? 'Borrow request approved.'
              : 'Borrow request rejected.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating request: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please sign in'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('approvals')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return const Center(child: Text('No pending borrow requests'));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final data = requests[index].data() as Map<String, dynamic>;
            final channelId = (data['channelId'] as String?)?.trim() ?? '';
            final itemId = (data['itemId'] as String?)?.trim() ?? '';
            final requestorId = (data['requestorId'] as String?)?.trim() ?? '';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title:
                    Text('Request for: ${data['itemTitle'] ?? 'Unknown Item'}'),
                subtitle:
                    Text('Requested by: ${data['requestorName'] ?? 'Unknown'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Approve button
                    ElevatedButton(
                      onPressed: () => _handleApproval(requests[index].id,
                          channelId, itemId, requestorId, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Approve'),
                    ),
                    const SizedBox(width: 8),
                    // Reject button
                    ElevatedButton(
                      onPressed: () => _handleApproval(requests[index].id,
                          channelId, itemId, requestorId, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class BorrowRequestHistory extends StatelessWidget {
  const BorrowRequestHistory({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const SizedBox();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('approvals')
          .where('status', whereIn: ['approved', 'rejected'])
          .orderBy('actionDate', descending: true)
          .limit(10) // Limit to recent 10 records to avoid performance issues
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!.docs;
        if (requests.isEmpty) {
          return const Center(child: Text('No request history'));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Request History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final data = requests[index].data() as Map<String, dynamic>;
                final isApproved = data['status'] == 'approved';
                final actionDate = data['actionDate'] as Timestamp?;
                final dateText = actionDate != null
                    ? _formatDate(actionDate.toDate())
                    : 'Unknown date';

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: isApproved ? Colors.green.shade50 : Colors.red.shade50,
                  child: ListTile(
                    title: Text(
                      'Request for: ${data['itemTitle'] ?? 'Unknown Item'}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Requested by: ${data['requestorName'] ?? 'Unknown'}'),
                        Text('Date: $dateText'),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isApproved ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isApproved ? 'APPROVED' : 'REJECTED',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
