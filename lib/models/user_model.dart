class UserModel {
  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.role,
  });

  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final String role;
}
