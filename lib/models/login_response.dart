class LoginResponse {
  final bool success;
  final String? token;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? user;
  final String? message;

  LoginResponse({
    required this.success,
    this.token,
    this.data,
    this.user,
    this.message,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return LoginResponse(
      success: json['success'] as bool? ?? false,
      token: data?['token'] as String?,
      data: data,
      user: data?['user'] as Map<String, dynamic>?,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'token': token,
      'data': data,
      'user': user,
      'message': message,
    };
  }
}