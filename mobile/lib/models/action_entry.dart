class ActionEntry {
  final String id;
  final String quoteId;
  final String quoteTitle;
  final String localDate;
  final String note;
  final String createdAt;

  ActionEntry({
    required this.id,
    required this.quoteId,
    required this.quoteTitle,
    required this.localDate,
    required this.note,
    required this.createdAt,
  });

  factory ActionEntry.fromMap(Map<String, dynamic> map) {
    return ActionEntry(
      id: map['id']?.toString() ?? '',
      quoteId: map['quoteId']?.toString() ?? '',
      quoteTitle: map['quoteTitle']?.toString() ?? '',
      localDate: map['localDate']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      createdAt: map['createdAt']?.toString() ?? '',
    );
  }
}

