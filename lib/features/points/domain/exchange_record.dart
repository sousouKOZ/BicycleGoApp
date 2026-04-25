/// ポイント交換の履歴エントリ。端末ローカルに永続化される。
class ExchangeRecord {
  final String id;
  final String itemId;
  final String itemTitle;
  final int costPoints;
  final DateTime exchangedAt;

  const ExchangeRecord({
    required this.id,
    required this.itemId,
    required this.itemTitle,
    required this.costPoints,
    required this.exchangedAt,
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'itemId': itemId,
        'itemTitle': itemTitle,
        'costPoints': costPoints,
        'exchangedAt': exchangedAt.toIso8601String(),
      };

  factory ExchangeRecord.fromJson(Map<String, Object?> j) {
    return ExchangeRecord(
      id: j['id'] as String,
      itemId: j['itemId'] as String,
      itemTitle: j['itemTitle'] as String,
      costPoints: (j['costPoints'] as num).toInt(),
      exchangedAt: DateTime.parse(j['exchangedAt'] as String),
    );
  }
}
