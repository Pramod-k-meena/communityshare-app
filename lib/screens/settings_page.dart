import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


// Simple Channel model class for settings list.
class Channel {
  final String id;
  final String name;
  Channel({required this.id, required this.name});
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late DocumentReference userDocRef;
  List<String> selectedChannels =
      []; // channels the user wants notifications from
  List<Channel> availableChannels = [];
  String _selectedDistanceFilter = '10'; // Default to 10 km
  final List<String> _distanceOptions = ['1', '5', '10', '20', '50'];

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      userDocRef =
          FirebaseFirestore.instance.collection('users').doc(currentUser!.uid);
      _loadUserSettings();
      _loadAvailableChannels();
    }
  }

  Future<void> _loadUserSettings() async {
    final doc = await userDocRef.get();
    final data = doc.data() as Map<String, dynamic>?;
    setState(() {
      selectedChannels = data != null && data['notificationChannels'] != null
          ? List<String>.from(data['notificationChannels'])
          : [];
      _selectedDistanceFilter =
          data != null && data['notificationDistance'] != null
              ? data['notificationDistance'].toString()
              : '10';
    });
  }

  Future<void> _loadAvailableChannels() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('channels')
        .where('approved', isEqualTo: true)
        .get();
    setState(() {
      availableChannels = snapshot.docs.map((doc) {
        final data = doc.data();
        return Channel(
          id: doc.id,
          name: data['name'] ?? 'Unnamed Channel',
        );
      }).toList();
    });
  }

  Future<void> _updateSettings() async {
    await userDocRef.update({
      'notificationChannels': selectedChannels,
      'notificationDistance': double.parse(_selectedDistanceFilter),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in first.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFFA76D4B),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select channels for notifications:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: availableChannels.length,
                itemBuilder: (context, index) {
                  final channel = availableChannels[index];
                  final isSelected = selectedChannels.contains(channel.id);
                  return CheckboxListTile(
                    title: Text(channel.name),
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          selectedChannels.add(channel.id);
                        } else {
                          selectedChannels.remove(channel.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Maximum distance for notifications (km):",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String>(
              value: _selectedDistanceFilter,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _distanceOptions.map((String dist) {
                return DropdownMenuItem(
                  value: dist,
                  child: Text("$dist km"),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedDistanceFilter = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: _updateSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB37B5F),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'Save Settings',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
