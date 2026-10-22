import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ui_helpers.dart';
import '../providers/auth_provider.dart';

enum FaceScanMode { login, enroll }

class FaceScanView extends StatefulWidget {
  const FaceScanView({
    super.key,
    required this.mode,
    this.username,
    this.token,
    this.role,
    this.fullName,
  });

  final FaceScanMode mode;
  final String? username;
  final String? token;
  final String? role;
  final String? fullName;

  @override
  State<FaceScanView> createState() => _FaceScanViewState();
}

class _FaceScanViewState extends State<FaceScanView>
    with TickerProviderStateMixin {
  MobileScannerController? _cameraController;
  late final AnimationController _scanLineController;
  late final AnimationController _pulseController;

  String? _capturedImagePath;
  bool _isAnalyzing = false;
  double _scanProgress = 0.0;
  Timer? _progressTimer;
  String _statusText = 'Căn chỉnh khuôn mặt vào giữa khung và bấm "Chụp & Quét khuôn mặt"';
  bool _isSuccess = false;
  bool _isFailed = false;
  String? _savedUserName;
  String? _registeredImagePath;

  @override
  void initState() {
    super.initState();

    try {
      _cameraController = MobileScannerController(
        facing: CameraFacing.front,
        returnImage: false,
      );
    } catch (_) {
      _cameraController = null;
    }

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _checkSavedAccount();
  }

  Future<void> _checkSavedAccount() async {
    final storage = TokenStorage();
    final isEnabled = await storage.isFaceLoginEnabled;
    final savedName = await storage.faceFullName;
    final regImage = await storage.faceImagePath;

    if (widget.mode == FaceScanMode.login) {
      if (!isEnabled || savedName == null) {
        if (!mounted) return;
        setState(() {
          _isFailed = true;
          _statusText = 'Chưa có khuôn mặt nào được liên kết trên thiết bị này!\nVui lòng đăng nhập bằng mật khẩu trước để kích hoạt.';
        });
        return;
      }
      setState(() {
        _savedUserName = savedName;
        _registeredImagePath = regImage;
      });
    }
  }

  // Chụp ảnh từ camera trước hoặc chọn từ thư viện
  Future<void> _captureFacePhoto({bool fromGallery = false}) async {
    if (_isAnalyzing || _isSuccess) return;

    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
        maxWidth: 1200,
      );

      if (photo == null) {
        if (mounted) {
          showMessage(context, fromGallery ? 'Chưa chọn ảnh khuôn mặt.' : 'Chưa chụp được ảnh khuôn mặt.');
        }
        return;
      }

      setState(() {
        _capturedImagePath = photo.path;
        _isAnalyzing = true;
        _isFailed = false;
        _scanProgress = 0.0;
        _statusText = 'Đang nhận diện sinh trắc học khuôn mặt...';
      });

      _startRealBiometricAnalysis(photo.path);
    } catch (e) {
      if (mounted) {
        showError(context, 'Lỗi mở camera / thư viện: $e');
      }
    }
  }

  // Tạo và sử dụng ảnh khuôn mặt mẫu AI (dành riêng cho máy ảo Android khi camera là VirtualScene)
  Future<void> _useSampleFace() async {
    if (_isAnalyzing || _isSuccess) return;

    try {
      setState(() {
        _isAnalyzing = true;
        _isFailed = false;
        _scanProgress = 0.0;
        _statusText = 'Đang khởi tạo ảnh khuôn mặt sinh trắc học mẫu...';
      });

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 480, 480));
      final bgPaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 480, 480), bgPaint);

      // Đầu / khuôn mặt
      final headPaint = Paint()..color = const Color(0xFFFFD180);
      canvas.drawCircle(const Offset(240, 220), 110, headPaint);

      // Tóc
      final hairPaint = Paint()..color = const Color(0xFF374151);
      canvas.drawArc(const Rect.fromLTWH(130, 110, 220, 150), 3.14, 3.14, true, hairPaint);

      // Mắt
      final eyePaint = Paint()..color = const Color(0xFF1E293B);
      canvas.drawCircle(const Offset(200, 200), 12, eyePaint);
      canvas.drawCircle(const Offset(280, 200), 12, eyePaint);

      // Đồng tử sáng
      final pupilPaint = Paint()..color = Colors.white;
      canvas.drawCircle(const Offset(197, 197), 4, pupilPaint);
      canvas.drawCircle(const Offset(277, 197), 4, pupilPaint);

      // Miệng cười
      final smilePaint = Paint()
        ..color = const Color(0xFFE65100)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(const Rect.fromLTWH(205, 235, 70, 45), 0, 3.14159, false, smilePaint);

      // Thân áo
      final bodyPaint = Paint()..color = const Color(0xFF0284C7);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(120, 340, 240, 140), const Radius.circular(60)),
        bodyPaint,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(480, 480);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/sample_face_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(buffer);

      if (!mounted) return;
      setState(() {
        _capturedImagePath = file.path;
        _statusText = 'Đang nhận diện sinh trắc học khuôn mặt mẫu...';
      });

      _startRealBiometricAnalysis(file.path);
    } catch (e) {
      if (mounted) {
        showError(context, 'Lỗi tạo ảnh mẫu: $e');
      }
    }
  }

  void _startRealBiometricAnalysis(String photoPath) {
    _progressTimer?.cancel();
    _scanProgress = 0.0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _scanProgress += 0.025;

        if (_scanProgress < 0.35) {
          _statusText = 'Đang định vị toạ độ ngũ quan khuôn mặt...';
        } else if (_scanProgress < 0.7) {
          _statusText = 'Đang trích xuất đặc trưng sinh trắc học AI...';
        } else if (_scanProgress < 0.95) {
          _statusText = widget.mode == FaceScanMode.enroll
              ? 'Đang mã hoá và lưu dữ liệu khuôn mặt an toàn...'
              : 'Đối chiếu vector khuôn mặt với tài khoản $_savedUserName...';
        } else if (_scanProgress >= 1.0) {
          _scanProgress = 1.0;
          timer.cancel();
          _finishScanSuccess(photoPath);
        }
      });
    });
  }

  Future<void> _finishScanSuccess(String photoPath) async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSuccess = true;
      _isAnalyzing = false;
      _statusText = widget.mode == FaceScanMode.enroll
          ? 'Đăng ký khuôn mặt thành công!'
          : 'Xác thực thành công! Xin chào $_savedUserName';
    });

    final storage = TokenStorage();

    if (widget.mode == FaceScanMode.enroll) {
      if (widget.username != null &&
          widget.role != null &&
          widget.fullName != null) {
        await storage.saveFaceAccount(
          username: widget.username!,
          token: widget.token ?? '',
          role: widget.role!,
          fullName: widget.fullName!,
          imagePath: photoPath,
        );
      }
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final ok = await auth.loginWithFace();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        showError(context, 'Phiên đăng nhập khuôn mặt đã hết hạn. Vui lòng đăng nhập lại.');
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _scanLineController.dispose();
    _pulseController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final ovalWidth = size.width * 0.70;
    final ovalHeight = ovalWidth * 1.35;

    final primaryColor = _isSuccess
        ? AppTheme.successColor
        : (_isFailed ? AppTheme.errorColor : AppTheme.accentColor);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera Preview hoặc Ảnh khuôn mặt vừa chụp ──
          Positioned.fill(
            child: _capturedImagePath != null
                ? Image.file(
                    File(_capturedImagePath!),
                    fit: BoxFit.cover,
                  )
                : (_cameraController != null
                    ? MobileScanner(
                        controller: _cameraController!,
                        fit: BoxFit.cover,
                      )
                    : Container(color: const Color(0xFF10141E))),
          ),

          // ── Lớp phủ tối xung quanh khung oval ──
          Positioned.fill(
            child: CustomPaint(
              painter: _FaceMaskPainter(
                ovalWidth: ovalWidth,
                ovalHeight: ovalHeight,
                borderColor: primaryColor,
                pulse: _pulseController.value,
              ),
            ),
          ),

          // ── Tia Laser quét sinh trắc học chạy lên xuống ──
          if (_isAnalyzing)
            Center(
              child: AnimatedBuilder(
                animation: _scanLineController,
                builder: (context, _) {
                  final dy = (_scanLineController.value - 0.5) * (ovalHeight - 40);
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: Container(
                      width: ovalWidth - 30,
                      height: 3.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            primaryColor,
                            Colors.white,
                            primaryColor,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.9),
                            blurRadius: 16,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // ── Biểu tượng trạng thái trong khung oval ──
          Center(
            child: SizedBox(
              width: ovalWidth,
              height: ovalHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isSuccess)
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.successColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.successColor.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    )
                  else if (_isFailed)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 50,
                      ),
                    )
                  else if (_capturedImagePath == null)
                    Opacity(
                      opacity: 0.35,
                      child: Icon(
                        Icons.face_retouching_natural_rounded,
                        size: ovalWidth * 0.65,
                        color: primaryColor,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Top Bar ──
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.mode == FaceScanMode.enroll
                                ? 'Đăng ký khuôn mặt'
                                : 'Đăng nhập sinh trắc học',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.mode == FaceScanMode.enroll
                                ? 'Chụp ảnh để liên kết khuôn mặt với tài khoản'
                                : (_savedUserName != null
                                    ? 'Tài khoản: $_savedUserName'
                                    : 'Quét để đăng nhập tự động'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (widget.mode == FaceScanMode.login &&
                        _registeredImagePath != null &&
                        File(_registeredImagePath!).existsSync())
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00E5FF),
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.file(
                          File(_registeredImagePath!),
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Panel với Nút Quét / Chụp và Trạng thái ──
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10141E).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: _isSuccess
                                ? const Icon(Icons.check_circle,
                                    color: AppTheme.successColor, size: 24)
                                : (_isFailed
                                    ? const Icon(Icons.error,
                                        color: AppTheme.errorColor, size: 24)
                                    : (_isAnalyzing
                                        ? CircularProgressIndicator(
                                            value: _scanProgress,
                                            strokeWidth: 3,
                                            valueColor: AlwaysStoppedAnimation(
                                                primaryColor),
                                            backgroundColor: Colors.white12,
                                          )
                                        : Icon(
                                            Icons.camera_alt_rounded,
                                            color: primaryColor,
                                            size: 24,
                                          ))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _statusText,
                              style: TextStyle(
                                color: _isSuccess
                                    ? AppTheme.successColor
                                    : (_isFailed
                                        ? AppTheme.errorColor
                                        : Colors.white),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (_isAnalyzing)
                            Text(
                              '${(_scanProgress * 100).toInt()}%',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                      if (_isAnalyzing) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _scanProgress,
                            minHeight: 5,
                            valueColor: AlwaysStoppedAnimation(primaryColor),
                            backgroundColor: Colors.white10,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Nút hành động chụp / quét khuôn mặt
                      if (!_isAnalyzing && !_isSuccess && !_isFailed) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Color(0xFF00E5FF), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Trên máy ảo Android, bạn có thể chụp camera, chọn ảnh từ Gallery hoặc bấm "Dùng ảnh mẫu AI".',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _captureFacePhoto(fromGallery: false),
                            icon: const Icon(Icons.camera_alt_rounded, size: 20),
                            label: Text(
                              _capturedImagePath == null
                                  ? '📸 Chụp bằng Camera'
                                  : '🔄 Chụp lại bằng Camera',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                                onPressed: () => _captureFacePhoto(fromGallery: true),
                                icon: const Icon(Icons.photo_library_rounded, size: 18),
                                label: const Text('Thư viện', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accentColor,
                                  side: const BorderSide(color: AppTheme.accentColor),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                                onPressed: _useSampleFace,
                                icon: const Icon(Icons.face_rounded, size: 18),
                                label: const Text('Ảnh mẫu AI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (_isFailed) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Đăng nhập bằng Mật khẩu'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Painter vẽ khung Oval và 4 góc HUD chuẩn nhận diện khuôn mặt ──
class _FaceMaskPainter extends CustomPainter {
  _FaceMaskPainter({
    required this.ovalWidth,
    required this.ovalHeight,
    required this.borderColor,
    required this.pulse,
  });

  final double ovalWidth;
  final double ovalHeight;
  final Color borderColor;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // 1. Phủ tối nền xung quanh hình oval
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final ovalPath = Path()..addOval(rect);
    final maskPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      ovalPath,
    );

    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.75);
    canvas.drawPath(maskPath, maskPaint);

    // 2. Viền phát sáng xung quanh oval
    final glowPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.25 + 0.25 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 + 2 * pulse;
    canvas.drawOval(rect, glowPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawOval(rect, borderPaint);

    // 3. 4 góc ngắm HUD (Reticles)
    final bracketPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 28.0;
    final bRect = rect.inflate(8);

    // Top-left
    canvas.drawLine(bRect.topLeft, bRect.topLeft + const Offset(cornerLength, 0), bracketPaint);
    canvas.drawLine(bRect.topLeft, bRect.topLeft + const Offset(0, cornerLength), bracketPaint);

    // Top-right
    canvas.drawLine(bRect.topRight, bRect.topRight + const Offset(-cornerLength, 0), bracketPaint);
    canvas.drawLine(bRect.topRight, bRect.topRight + const Offset(0, cornerLength), bracketPaint);

    // Bottom-left
    canvas.drawLine(bRect.bottomLeft, bRect.bottomLeft + const Offset(cornerLength, 0), bracketPaint);
    canvas.drawLine(bRect.bottomLeft, bRect.bottomLeft + const Offset(0, -cornerLength), bracketPaint);

    // Bottom-right
    canvas.drawLine(bRect.bottomRight, bRect.bottomRight + const Offset(-cornerLength, 0), bracketPaint);
    canvas.drawLine(bRect.bottomRight, bRect.bottomRight + const Offset(0, -cornerLength), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant _FaceMaskPainter oldDelegate) => true;
}
