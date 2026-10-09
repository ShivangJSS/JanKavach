class LoginRequest {
  final String username;
  final String password;
  final String language;

  LoginRequest({
    required this.username,
    required this.password,
    required this.language,
  });

  Map<String, dynamic> toJson() {
    return {
      "username": username,
      "password": password,
      "language": language,
    };
  }
}