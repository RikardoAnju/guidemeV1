class UserModel {
  final String id;
  final String nama;
  final String email;
  final String role;
  final DateTime lastActive;
  final String photoUrl;
  final String status;

  UserModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.role,
    required this.lastActive,
    required this.photoUrl,
    required this.status,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return UserModel(
      id: docId,
      nama: data['nama'] ?? 'Nama tidak tersedia',
      email: data['email'] ?? 'Email tidak tersedia',
      role: data['role'] ?? 'User',
      lastActive: data['lastActive']?.toDate() ?? DateTime.now(),
      photoUrl: data['photoUrl'] ?? '',
      status: data['status'] ?? 'Aktif',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'email': email,
      'role': role,
      'lastActive': lastActive,
      'photoUrl': photoUrl,
      'status': status,
    };
  }
}