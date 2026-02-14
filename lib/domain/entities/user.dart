import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role; // 'PT' or 'Admin'
  final bool emailVerified;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.emailVerified = false,
  });

  String get fullName => '$firstName $lastName';

  @override
  List<Object> get props => [id, email, firstName, lastName, role, emailVerified];
}
