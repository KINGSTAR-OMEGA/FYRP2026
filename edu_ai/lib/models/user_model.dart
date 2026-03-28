class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'admin' | 'student'

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
      };
}

// ─── Demo Data ────────────────────────────────────────────────────────────────

const demoAdmin = UserModel(
  id: 'admin_1',
  name: 'Admin User',
  email: 'admin@eduai.com',
  role: 'admin',
);

const demoStudents = [
  UserModel(id: 'student_1', name: 'Alice Johnson', email: 'alice@eduai.com', role: 'student'),
  UserModel(id: 'student_2', name: 'Bob Smith', email: 'bob@eduai.com', role: 'student'),
  UserModel(id: 'student_3', name: 'Carol Davis', email: 'carol@eduai.com', role: 'student'),
  UserModel(id: 'student_4', name: 'David Lee', email: 'david@eduai.com', role: 'student'),
];
