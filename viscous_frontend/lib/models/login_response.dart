class LoginResponse {
  final bool success;
  final String? token;
  final User? user;
  final String? message;

  LoginResponse({required this.success, this.token, this.user, this.message});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] as bool? ?? false,
      token: json['token'] as String?,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
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
  final String? id;
  final String? college;
  final String? createdAt;
  final String? email;
  final String? name;
  final String? phone;
  final String? role;
  final String? route;
  final String? status;
  final String? userstop;
  final Map<String, dynamic>? notificationPreferences;
  final Map<String, dynamic>? notificationQuietHours;

  User({
    this.id,
    this.college,
    this.createdAt,
    this.email,
    this.name,
    this.phone,
    this.role,
    this.route,
    this.status,
    this.userstop,
    this.notificationPreferences,
    this.notificationQuietHours,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String?,
      college: json['college'] as String?,
      createdAt: json['createdAt'] as String?,
      email: json['email'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String?,
      route: json['route'] as String?,
      status: json['status'] as String?,
      userstop: json['userstop'] as String?,
      notificationPreferences:
          (json['notificationPreferences'] is Map<String, dynamic>)
          ? json['notificationPreferences'] as Map<String, dynamic>
          : null,
      notificationQuietHours:
          (json['notificationQuietHours'] is Map<String, dynamic>)
          ? json['notificationQuietHours'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'college': college,
      'createdAt': createdAt,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'route': route,
      'status': status,
      'userstop': userstop,
      'notificationPreferences': notificationPreferences,
      'notificationQuietHours': notificationQuietHours,
    };
  }
}
