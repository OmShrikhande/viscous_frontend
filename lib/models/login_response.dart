class LoginResponse {
  final bool success;
  final String? token;
  final User? user;
  final String? message;

  LoginResponse({
    required this.success,
    this.token,
    this.user,
    this.message,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return LoginResponse(
      success: json['success'] as bool? ?? false,
      token: data?['token'] as String?,
      user: data?['user'] != null ? User.fromJson(data!['user']) : null,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'token': token,
      'user': user?.toJson(),
      'message': message,
    };
  }
}

class User {
  final String? uid;
  final String? email;
  final String? mobile;
  final int? routeNumber;

  User({
    this.uid,
    this.email,
    this.mobile,
    this.routeNumber,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'] as String? ?? json['id']?.toString(),
      email: json['email'] as String?,
      mobile: json['mobile'] as String?,
      routeNumber: json['routeNumber'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'mobile': mobile,
      'routeNumber': routeNumber,
    };
  }
}