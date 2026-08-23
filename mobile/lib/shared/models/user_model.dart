class UserModel {
  final int id;
  final String username;
  final String email;
  final String? avatarUrl;
  final bool isPrivate;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.isPrivate = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        username: json['username'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatar_url'] as String?,
        isPrivate: json['is_private'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar_url': avatarUrl,
        'is_private': isPrivate,
      };
}
