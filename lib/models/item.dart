class Item {
  final String id;
  final String title;
  final String imageUrl;
  final double distance;
  final String? ownerId;
  final String? ownerName;
  final String channelId; // Channel id field
  final bool visible; // Controls visibility of the item
  final String? subcategory; // New field for subcategory
  final String? itemCategory; // New field for item category

  Item({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.distance,
    required this.channelId,
    this.ownerId,
    this.ownerName,
    this.visible = true,
    this.subcategory, // Initialize subcategory
    this.itemCategory, // Initialize itemCategory
  });

  factory Item.fromMap(String id, Map<String, dynamic> data) {
    return Item(
      id: id,
      title: data['title'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      distance: (data['distance'] ?? 0).toDouble(),
      channelId: data['channelId'] ?? '',
      ownerId: data['ownerId'],
      ownerName: data['ownerName'] ?? 'Unknown User',
      visible: data['visible'] ?? true,
      subcategory: data['subcategory'],
      itemCategory: data['itemCategory'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'distance': distance,
      'channelId': channelId,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'visible': visible,
      if (subcategory != null) 'subcategory': subcategory,
      if (itemCategory != null) 'itemCategory': itemCategory,
    };
  }
}

class ItemFilter {
  final String? searchQuery;
  final double? maxDistance;
  final String? category;

  ItemFilter({this.searchQuery, this.maxDistance, this.category});

  Map<String, dynamic> toMap() {
    return {
      if (searchQuery != null) 'query': searchQuery,
      if (maxDistance != null) 'maxDistance': maxDistance,
      if (category != null) 'category': category,
    };
  }
}
