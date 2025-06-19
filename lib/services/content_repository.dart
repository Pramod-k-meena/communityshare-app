
// Storage object for channel content
class ChannelContent {
  final String channelId;
  final List<Map<String, dynamic>> borrowItems;

  ChannelContent({
    required this.channelId,
    List<Map<String, dynamic>>? borrowItems,
  })  : borrowItems = borrowItems ?? []{
    // Constructor body (can be empty)   
  }
}

// Local data storage
class ContentRepository {
  ContentRepository._privateConstructor();
  static final ContentRepository instance =
      ContentRepository._privateConstructor();

  final Map<String, ChannelContent> _channelContents = {};

  ChannelContent _ensureChannel(String channelId) {
    if (!_channelContents.containsKey(channelId)) {
      _channelContents[channelId] = ChannelContent(channelId: channelId);
    }
    return _channelContents[channelId]!;
  }

  void addBorrowItem(String channelId, Map<String, dynamic> item) {
    _ensureChannel(channelId).borrowItems.add(item);
  }

  List<Map<String, dynamic>> getBorrowItems(String channelId) {
    return _channelContents[channelId]?.borrowItems ?? [];
  }
}
