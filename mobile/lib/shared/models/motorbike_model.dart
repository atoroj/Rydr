class MotorbikeModel {
  final int id;
  final int userId;
  final String type;
  final String brand;
  final String model;
  final int cc;
  final String? alias;

  const MotorbikeModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.brand,
    required this.model,
    required this.cc,
    this.alias,
  });

  factory MotorbikeModel.fromJson(Map<String, dynamic> json) => MotorbikeModel(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        type: json['type'] as String,
        brand: json['brand'] as String,
        model: json['model'] as String,
        cc: json['cc'] as int,
        alias: json['alias'] as String?,
      );

  String get displayName => alias ?? '$brand $model';
}
