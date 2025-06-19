import 'package:flutter/material.dart';
import 'package:web_app/models/item.dart';
import 'package:web_app/screens/cart_page.dart';
import 'package:web_app/services/item_repository.dart';
import 'package:web_app/widgets/sidebar.dart';
import '../models/channels.dart';
import 'package:file_picker/file_picker.dart'; // new import for file picker
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import 'package:web_app/widgets/item_card.dart';
import 'package:web_app/widgets/raise_item_request_popup.dart';
import 'package:web_app/services/cart_repository.dart'; // Add this import for CartRepository

class ChannelPage extends StatefulWidget {
  final Channel selectedChannel;
  final bool isBorrowMode; // True for Borrow view, False for Lend view
  final String? selectedSubcategoryId; // Added parameter for selected subcategory
  
  const ChannelPage({
    super.key,
    required this.selectedChannel,
    this.isBorrowMode = true, // Default to Borrow view
    this.selectedSubcategoryId, // Default to null (show all items)
  });
  @override
  _ChannelPageState createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  final ItemRepository _itemRepository = ItemRepository.instance;
  late bool _isBorrowMode;

  // Add variables for user info
  String _userName = 'User';
  int _ecoPoints = 0;
  bool _isLoadingUser = true;

  // Controllers for Lend form
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _otherCategoryController =
      TextEditingController();

  // NEW: State for subcategories and items fetched from Firestore
  List<SubCategory> _subCategories = [];
  SubCategory? _selectedSubCategory;
  List<Item> _subCategoryItems = [];
  Item? _selectedItem;

  // For file picker
  PlatformFile? _pickedImage;

  @override
  void initState() {
    super.initState();
    _isBorrowMode = widget.isBorrowMode;
    debugPrint("Initial mode: ${_isBorrowMode ? 'Borrow' : 'Lend'}");
    if (widget.selectedSubcategoryId != null) {
      debugPrint("Selected subcategory ID: ${widget.selectedSubcategoryId}");
    }
    
    // Load user data when page initializes
    _loadUserData(); 
    
    // Always load subcategories to support filtering in both modes
    debugPrint("Loading subcategories for channel ${widget.selectedChannel.id}");
    _loadSubCategories();
    
    // Initialize the selected subcategory if provided
    if (widget.selectedSubcategoryId != null) {
      _initializeSelectedSubcategory(widget.selectedSubcategoryId!);
    }
  }
  
  // Initialize the selected subcategory when provided via navigation
  Future<void> _initializeSelectedSubcategory(String subcategoryId) async {
    // We need to wait for subcategories to load first
    List<SubCategory> subcategories = await widget.selectedChannel.fetchSubCategories();
    
    if (mounted) {
      setState(() {
        // Find the subcategory by ID
        _selectedSubCategory = subcategories.firstWhere(
          (sub) => sub.id == subcategoryId,
          orElse: () => SubCategory(id: '', name: ''), // Use a default value instead of null
        );
        
        if (_selectedSubCategory?.id.isNotEmpty == true) {
          debugPrint("Found selected subcategory: ${_selectedSubCategory!.name}");
        } else {
          _selectedSubCategory = null; // Reset to null if not found
          debugPrint("Selected subcategory not found: $subcategoryId");
        }
      });
    }
  }

  // Add method to load user data
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get user details from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          if (mounted) {
            // Get the display name from Firestore or Firebase Auth
            String displayName =
                userDoc.data()?['displayName'] ?? user.displayName ?? 'User';

            // Truncate long names to prevent layout issues
            if (displayName.length > 15) {
              displayName = '${displayName.substring(0, 12)}...';
            }

            setState(() {
              _userName = displayName;
              _ecoPoints = userDoc.data()?['ecoPoints'] ?? 0;
              _isLoadingUser = false;
            });
          }
        } else {
          // If user document doesn't exist in Firestore, use Auth display name
          if (mounted) {
            // Get the display name from Firebase Auth
            String displayName = user.displayName ?? 'User';

            // Truncate long names to prevent layout issues
            if (displayName.length > 15) {
              displayName = '${displayName.substring(0, 12)}...';
            }

            setState(() {
              _userName = displayName;
              _isLoadingUser = false;
            });
          }
        }
      } else {
        // Handle not signed in case
        if (mounted) {
          setState(() {
            _isLoadingUser = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
      }
    }
  }

  // NEW: Method to load subcategories from Firestore using channel's method.
  Future<void> _loadSubCategories() async {
    List<SubCategory> subs = await widget.selectedChannel.fetchSubCategories();
    setState(() {
      _subCategories = subs;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _imageUrlController.dispose();
    _distanceController.dispose();
    _otherCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBE4DF), // Updated background color
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar with fixed width - now using dynamic user data
          _isLoadingUser
              ? const SizedBox(
                  width: 240,
                  child: Center(child: CircularProgressIndicator()),
                )
              : SidebarWidget(
                  userName: _userName,
                  ecoPoints: _ecoPoints,
                ),

          // Main content area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.selectedChannel.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.selectedSubcategoryId != null)
                              FutureBuilder<List<SubCategory>>(
                                future: widget.selectedChannel.fetchSubCategories(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Text(
                                      'Loading subcategory...',
                                      style: TextStyle(color: Colors.grey),
                                    );
                                  }
                                  
                                  if (snapshot.hasData) {
                                    final subcategories = snapshot.data!;
                                    final selectedSubcategory = subcategories.firstWhere(
                                      (sub) => sub.id == widget.selectedSubcategoryId,
                                      orElse: () => SubCategory(id: widget.selectedSubcategoryId!, name: 'Unknown'),
                                    );
                                    
                                    return Text(
                                      'Subcategory: ${selectedSubcategory.name}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }
                                  
                                  return const SizedBox.shrink();
                                },
                              )
                            else
                              Text(
                                widget.selectedChannel.description ?? '',
                                style: TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                        // Toggle buttons row: Borrow, Lend, and now Cart button
                        Row(
                          children: [
                            _buildHeaderButton('BORROW', _isBorrowMode),
                            _buildHeaderButton('LEND', !_isBorrowMode),
                            const SizedBox(width: 8),
                            // NEW: Cart button on the right of Lend button
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) {
                                      // Replace with your cart page widget
                                      return const CartPage();
                                    },
                                  ),
                                );
                              },
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFFB37B5F)),
                                ),
                                child: FutureBuilder<int>(
                                  future: cartRepository.instance
                                      .getCartCount(), // Adjust as needed
                                  builder: (context, snapshot) {
                                    int count =
                                        snapshot.hasData ? snapshot.data! : 0;
                                    return Row(
                                      children: [
                                        const Icon(
                                          Icons.shopping_cart,
                                          color: Color(0xFFB37B5F),
                                        ),
                                        if (count > 0)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: 4),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$count',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Content - Either Borrow Grid or Lend Form based on mode
                  _isBorrowMode ? _buildBorrowContent() : _buildLendContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Borrow view with search and grid
  Widget _buildBorrowContent() {
    return FutureBuilder<List<Item>>(
      future: _itemRepository.getItems(
        channelId: widget.selectedChannel.id,
        isBorrow: _isBorrowMode,
        subcategoryId: widget.selectedSubcategoryId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Calculate available height, adjust 200 as needed for your header size.
          final availableHeight = MediaQuery.of(context).size.height - 200;
          return SizedBox(
            height: availableHeight,
            child: Center(
              child: ElevatedButton(
                onPressed: () => RaiseItemRequestPopup.show(
                  context,
                  widget.selectedChannel.id,
                  widget.selectedChannel.name, // add channel name here
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB37B5F),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'Raise a request for an item in community?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        }
        final items = snapshot.data!;
        final int columns = MediaQuery.of(context).size.width < 600 ? 2 : 3;
        return SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return ItemCard(
                      item: items[index],
                      channelId: widget.selectedChannel.id,
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.campaign),
                    label: const Text(
                      'Raise a request for an item in community?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB37B5F),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => RaiseItemRequestPopup.show(
                      context,
                      widget.selectedChannel.id,
                      widget.selectedChannel.name, // add channel name here
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Lend form view
  Widget _buildLendContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You\'re lending an item to "${widget.selectedChannel.name}"',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          // Dropdown for subcategory selection fetched from Firestore
          DropdownButtonFormField<SubCategory>(
            value: _selectedSubCategory,
            hint: const Text(
              'Select subcategory',
              style: TextStyle(fontSize: 16),
            ),
            items: _subCategories.map((subCat) {
              return DropdownMenuItem<SubCategory>(
                value: subCat,
                child: Text(
                  subCat.name.isEmpty ? 'No Name' : subCat.name,
                  style: const TextStyle(fontSize: 16),
                ),
              );
            }).toList(),
            onChanged: (SubCategory? newSubCat) async {
              setState(() {
                _selectedSubCategory = newSubCat;
                _selectedItem = null;
                _subCategoryItems = [];
              });
              if (newSubCat != null) {
                List<Item> items =
                    await ItemRepository.instance.getItemsBySubCategory(
                  channelId: widget.selectedChannel.id,
                  subCategoryId: newSubCat.id,
                );
                setState(() {
                  _subCategoryItems = items;
                });
              }
            },
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
          const SizedBox(height: 20),
          // Always show the items dropdown if a subcategory is selected.
          if (_selectedSubCategory != null)
            _subCategoryItems.isNotEmpty
                ? DropdownButtonFormField<Item>(
                    value: _selectedItem,
                    hint: const Text(
                      'Select item',
                      style: TextStyle(fontSize: 12),
                    ),
                    items: _subCategoryItems.map((item) {
                      return DropdownMenuItem<Item>(
                        value: item,
                        child: Text(
                          item.title,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (Item? newItem) {
                      setState(() {
                        _selectedItem = newItem;
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: const Text(
                      'No items available',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter item name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Photo upload button remains as is
          ElevatedButton(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['jpg', 'jpeg', 'png'],
                allowMultiple: false,
                withData: true, // Important for web to get the actual bytes
              );

              if (result != null && result.files.isNotEmpty) {
                final file = result.files.first;

                // Check file size (1MB = 1048576 bytes)
                if (file.size > 1048576) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('File size must be less than 1MB'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                // Check if extension is valid (additional safety check)
                final extension = file.extension?.toLowerCase() ?? '';
                if (!['jpg', 'jpeg', 'png'].contains(extension)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Only JPG, JPEG and PNG files are allowed'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                setState(() {
                  _pickedImage = file;
                });
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Image selected (${(file.size / 1024).toStringAsFixed(1)} KB)'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: Text(_pickedImage == null
                ? 'Select Image'
                : 'Image Selected (${(_pickedImage?.size ?? 0) / 1024} KB)'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _distanceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Distance (in kms)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              // Check if subcategory and item are selected
              final subcategory = _selectedSubCategory?.name ?? '';
              final itemCategory = _selectedItem?.title ?? '';
              final itemName = _titleController.text.trim();

              if (subcategory.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a subcategory')),
                );
                return;
              }

              if (itemCategory.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please select an item category')),
                );
                return;
              }

              if (itemName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an item name')),
                );
                return;
              }

              try {
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Adding item...')),
                );

                // Create a new item with subcategory and itemCategory
                final newItem = Item(
                  id: DateTime.now().toString(),
                  title: itemName,
                  imageUrl: '', // Will be updated after upload, if any
                  distance: double.tryParse(_distanceController.text) ?? 0.0,
                  channelId: widget.selectedChannel.id,
                  subcategory: subcategory,
                  itemCategory: itemCategory,
                );

                final success = await _itemRepository.submitItem(
                  channelId: widget.selectedChannel.id,
                  isBorrow: true, // Lend mode
                  item: newItem,
                  pickedImage: _pickedImage,
                );

                ScaffoldMessenger.of(context).hideCurrentSnackBar();

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Item added successfully')),
                  );

                  // Clear form fields
                  setState(() {
                    _selectedSubCategory = null;
                    _selectedItem = null;
                    _pickedImage = null;
                    _distanceController.clear();
                    _titleController.clear();
                    // Switch to borrow mode to see the added item
                    _isBorrowMode = true;
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to add item')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
  }

  // Header button styling
  Widget _buildHeaderButton(String text, bool isActive) {
    return GestureDetector(
      onTap: () async {
        if (text == 'LEND' && _isBorrowMode) {
          setState(() {
            _isBorrowMode = false;
            _selectedSubCategory = null; // clear previous selection
            _selectedItem = null;
            _subCategoryItems = [];
          });
          await _loadSubCategories();
        } else if (text == 'BORROW' && !_isBorrowMode) {
          setState(() {
            _isBorrowMode = true;
            _selectedSubCategory = null; // clear previous selection
            _selectedItem = null;
            _subCategoryItems = [];
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFB37B5F)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
