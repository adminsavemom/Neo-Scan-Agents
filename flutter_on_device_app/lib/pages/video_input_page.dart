import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';
import 'agent_page.dart';

class VideoInputPage extends StatefulWidget {
  const VideoInputPage({super.key});

  @override
  State<VideoInputPage> createState() => _VideoInputPageState();
}

class _VideoInputPageState extends State<VideoInputPage> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;
  bool _isInitialized = false;
  final RxInt _recordDuration = 0.obs;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _controller = CameraController(
          _cameras![0],
          ResolutionPreset.high,
          enableAudio: true,
        );
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _startTimer() {
    _recordDuration.value = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _recordDuration.value++;
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _toggleRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isRecording) {
      final XFile video = await _controller!.stopVideoRecording();
      _stopTimer();
      setState(() {
        _isRecording = false;
      });

      // Save to gallery
      try {
        await Gal.putVideo(video.path);
      } catch (e) {
        debugPrint('Error saving video: $e');
      }

      // Move to AgentPage
      Get.off(() => AgentPage(videoFile: File(video.path)));
    } else {
      await _controller!.startVideoRecording();
      _startTimer();
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      Get.off(() => AgentPage(videoFile: File(video.path)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.cyan)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        height: Get.height,
        child: Stack(
          children: [
            // Camera Preview
            Positioned.fill(child: CameraPreview(_controller!)),

            // Top Controls
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () => Get.back(),
                    ),
                    if (_isRecording)
                      Obx(
                        () => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDuration(_recordDuration.value),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Controls
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery Icon
                  _bottomIconButton(
                    icon: Icons.photo_library_rounded,
                    onPressed: _isRecording ? null : _pickFromGallery,
                  ),

                  // Record Button
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: _isRecording ? 30 : 64,
                          width: _isRecording ? 30 : 64,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(
                              _isRecording ? 5 : 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Spacer or Flip Camera
                  _bottomIconButton(
                    icon: Icons.flip_camera_ios_rounded,
                    onPressed: _isRecording
                        ? null
                        : () {
                            // Logic to flip camera can be added here
                          },
                  ),
                ],
              ),
            ),

            // Helper Text
            if (!_isRecording)
              const Positioned(
                bottom: 140,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'RECORD BABY FOR ANALYSIS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontSize: 12,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bottomIconButton({required IconData icon, VoidCallback? onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 28),
        onPressed: onPressed,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
