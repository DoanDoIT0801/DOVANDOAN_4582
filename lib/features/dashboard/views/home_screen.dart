import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:do_van_doan_4582/features/admin/views/admin_home_screen.dart';
import 'package:do_van_doan_4582/features/auth/providers/auth_provider.dart';
import 'package:do_van_doan_4582/features/classroom/views/student_home_view.dart';
import 'package:do_van_doan_4582/features/classroom/views/teacher_home_view.dart';

// Chọn màn hình chính theo role lấy từ JWT khi đăng nhập.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role;
    switch (role) {
      case 'Admin':
        return const AdminHomeScreen();
      case 'GiangVien':
        return const TeacherHomeScreen();
      default:
        return const StudentHomeScreen();
    }
  }
}
