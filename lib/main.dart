import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:do_van_doan_4582/core/storage/token_storage.dart';
import 'package:do_van_doan_4582/core/theme/app_theme.dart';
import 'package:do_van_doan_4582/core/network/api_service.dart';
import 'package:do_van_doan_4582/features/auth/providers/auth_provider.dart';
import 'package:do_van_doan_4582/features/auth/views/login_screen.dart';
import 'package:do_van_doan_4582/features/dashboard/views/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final storage = TokenStorage();
  runApp(MultiProvider(
    providers: [
      Provider<ApiService>(create: (_) => ApiService(storage)),
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider(storage)..restore()),
    ],
    child: const DiemDanhApp(),
  ));
}

class DiemDanhApp extends StatelessWidget {
  const DiemDanhApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Điểm Danh SV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.ready) return const _SplashScreen();
          return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              scheme.primary.withValues(alpha: 0.85),
              scheme.secondary,
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _ctrl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Icon(Icons.how_to_reg_rounded, size: 52, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Điểm Danh SV',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  'Quản lý điểm danh sinh viên',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
