/// 合集数据模型
/// audioItemIds 已移至 Drift junction 表（collection_audio_items）
class Collection {
  final String id;
  final String name;
  final DateTime createdDate;
  final bool isStarred;

  Collection({
    required this.id,
    required this.name,
    required this.createdDate,
    this.isStarred = false,
  });

  /// 用于 SP → Drift 迁移时读取旧格式的 JSON
  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
    id: json['id'],
    name: json['name'],
    createdDate: DateTime.parse(json['createdDate']),
    isStarred: json['isStarred'] ?? false,
  );

  /// 从旧 JSON 中提取 audioItemIds（仅迁移用）
  static List<String> audioItemIdsFromJson(Map<String, dynamic> json) {
    return List<String>.from(json['audioItemIds'] ?? []);
  }

  Collection copyWith({
    String? id,
    String? name,
    DateTime? createdDate,
    bool? isStarred,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      createdDate: createdDate ?? this.createdDate,
      isStarred: isStarred ?? this.isStarred,
    );
  }
}
