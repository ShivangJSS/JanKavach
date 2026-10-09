class LoginResponse {
  final bool success;
  final String message;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  LoginResponse({
    required this.success,
    required this.message,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory LoginResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    final tokens = json["data"]["tokens"];

    return LoginResponse(
      success: json["success"] ?? false,
      message: json["message"] ?? "",
      accessToken: tokens["access_token"] ?? "",
      refreshToken: tokens["refresh_token"] ?? "",
      tokenType: tokens["token_type"] ?? "Bearer",
      expiresIn: tokens["expires_in"] ?? 0,
    );
  }
}