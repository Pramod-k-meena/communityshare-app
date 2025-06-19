import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RaiseItemRequestPopup extends StatefulWidget {
  final String channelId;
  final String channelName; // New parameter

  const RaiseItemRequestPopup({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  static Future<void> show(
      BuildContext context, String channelId, String channelName) async {
    await showDialog(
      context: context,
      builder: (context) => RaiseItemRequestPopup(
        channelId: channelId,
        channelName: channelName,
      ),
    );
  }

  @override
  State<RaiseItemRequestPopup> createState() => _RaiseItemRequestPopupState();
}

class _RaiseItemRequestPopupState extends State<RaiseItemRequestPopup> {
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedDistance; // Distance in km (e.g., "1", "5", "10")
  bool _isSubmitting = false;

  Future<void> _submitRequest() async {
    if (_descriptionController.text.isEmpty || _selectedDistance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current location of the requestor
      Position position = await Geolocator.getCurrentPosition();
      double radiusKm = double.parse(_selectedDistance!);

      // Save the item request in Firestore under "item_requests"
      DocumentReference requestRef =
          await FirebaseFirestore.instance.collection('item_requests_via_notification').add({
        'channelId': widget.channelId,
        'description': _descriptionController.text,
        'radiusKm': radiusKm,
        'requestedAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'location': GeoPoint(position.latitude, position.longitude),
      });

      // Notify nearby users (iterating over all users; for production consider using geospatial queries)
      await _notifyNearbyUsers(
        requestLocation: position,
        radiusKm: radiusKm,
        requestId: requestRef.id,
      );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Request created and notifications sent')));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _notifyNearbyUsers({
    required Position requestLocation,
    required double radiusKm,
    required String requestId,
  }) async {
    // Get all users; for production, consider using a geospatial query plugin.
    QuerySnapshot usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    User? currentUser = FirebaseAuth.instance.currentUser;

    for (var userDoc in usersSnapshot.docs) {
      // Skip sending notification to the requestor themselves.
      if (userDoc.id == currentUser?.uid) {
        continue;
      }

      // Cast document data to Map.
      final data = userDoc.data() as Map<String, dynamic>;

      // Check user notification preferences.
      final List<dynamic> notifPrefs = data['notificationChannels'] ?? [];
      if (notifPrefs.isNotEmpty && !notifPrefs.contains(widget.channelId)) {
        print(
            "Skipping notification for user ${userDoc.id} due to notification preference.");
        continue;
      }

      if (data['location'] != null) {
        GeoPoint userGeo = data['location'];
        // Calculate distance between the request location and the user's stored location.
        double distance = Geolocator.distanceBetween(
              requestLocation.latitude,
              requestLocation.longitude,
              userGeo.latitude,
              userGeo.longitude,
            ) /
            1000; // Convert to km

        print("User ${userDoc.id} is at distance: $distance km");

        if (distance <= radiusKm) {
          print(
              "Sending notification to user ${userDoc.id} for channel ${widget.channelId}");
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('notifications')
              .add({
            'type': 'item_request',
            'requestId': requestId,
            'requestUser': currentUser?.displayName ?? 'Unknown User',
            'requestUserId': currentUser?.uid, // NEW field
            'channelName': widget.channelName,
            'distance': distance,
            'message':
                'New item request near you: ${_descriptionController.text}',
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      } else {
        print("User ${userDoc.id} has no location data");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Raise Item Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Item Description',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedDistance,
            decoration: const InputDecoration(
              labelText: 'Distance Radius (km)',
            ),
            items: ['1', '5', '10', '20'].map((val) {
              return DropdownMenuItem(
                value: val,
                child: Text('$val km'),
              );
            }).toList(),
            onChanged: (newVal) {
              setState(() {
                _selectedDistance = newVal;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitRequest,
          child: _isSubmitting
              ? const CircularProgressIndicator()
              : const Text('Submit'),
        ),
      ],
    );
  }
}
