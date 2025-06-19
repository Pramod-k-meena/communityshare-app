class ChannelContent {
  final String channelId;
  final List<String> borrowItems;

  ChannelContent({
    required this.channelId,
    List<String>? borrowItems,
  }) : borrowItems = borrowItems ?? [] {
    // Constructor body (can be empty)   
  }
}