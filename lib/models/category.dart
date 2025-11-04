import 'package:uuid/uuid.dart';

class Category {
  final String id;
  final String name;
  final int color; // Color value as int (0xAARRGGBB)

  Category({
    String? id,
    required this.name,
    required this.color,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      color: map['color'],
    );
  }

  Category copyWith({
    String? name,
    int? color,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}
