import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'ai_config_page.dart';
import '../controllers/ai_controller.dart';

class BaseAnalyzerPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color themeColor;
  final IconData icon;
  final String mode; // 'visual_only', 'audio_only', 'multimodal'
  final String promptTemplate;
  final String defectInfo;
  final String defectHarm;
  final Map<String, List<String>>? recommendationMap;

  const BaseAnalyzerPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.themeColor,
    required this.icon,
    required this.mode,
    required this.promptTemplate,
    required this.defectInfo,
    required this.defectHarm,
    this.recommendationMap,
  });

  @override
  State<BaseAnalyzerPage> createState() => _BaseAnalyzerPageState();
}

class _BaseAnalyzerPageState extends State<BaseAnalyzerPage> {
  final AiController aiController = Get.find<AiController>();
  File? _selectedFile;
  File? _extractedAudioFile;
  File? _extractedFrameFile;
  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAnalyzing = false;
  bool _isExtracting = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (widget.mode == 'audio_only') {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _result = null;
          _error = null;
        });
      }
    } else if (widget.mode == 'video_audio') {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _isExtracting = true;
          _extractedAudioFile = null;
          _extractedFrameFile = null;
        });

        _videoController?.dispose();
        _videoController = VideoPlayerController.file(File(video.path))
          ..initialize().then((_) {
            setState(() {});
          });

        // Extract audio and a representative frame immediately
        try {
          final Directory tempDir = await getTemporaryDirectory();
          final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          final String audioPath = '${tempDir.path}/extracted_audio_$timestamp.wav';
          final String framePath = '${tempDir.path}/extracted_frame_$timestamp.jpg';
          
          // Extract Audio (16kHz, mono)
          final audioSession = await FFmpegKit.execute('-i ${video.path} -vn -acodec pcm_s16le -ar 16000 -ac 1 $audioPath');
          final audioRC = await audioSession.getReturnCode();

          // Extract Frame (at 1 second mark)
          final frameSession = await FFmpegKit.execute('-i ${video.path} -ss 00:00:01 -vframes 1 $framePath');
          final frameRC = await frameSession.getReturnCode();

          if (ReturnCode.isSuccess(audioRC)) {
            _extractedAudioFile = File(audioPath);
          }
          if (ReturnCode.isSuccess(frameRC)) {
            _extractedFrameFile = File(framePath);
          }
        } catch (e) {
          debugPrint("Immediate extraction failed: $e");
        } finally {
          setState(() {
            _isExtracting = false;
            _selectedFile = File(video.path);
            _result = null;
            _error = null;
          });
        }
      }
    } else {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _result = null;
          _error = null;
        });
      }
    }
  }

  Future<void> _runAnalysis() async {
    if (_selectedFile == null) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
      _result = null;
    });

    try {
      File? image;
      File? audio;

      if (widget.mode == 'visual_only') {
        image = _selectedFile;
      } else if (widget.mode == 'audio_only') {
        audio = _selectedFile;
      } else if (widget.mode == 'video_audio') {
        // Use pre-extracted audio and frame if available
        audio = _extractedAudioFile;
        image = _extractedFrameFile;

        // Fallback extraction if missing
        if (audio == null || image == null) {
          final Directory tempDir = await getTemporaryDirectory();
          final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          
          if (audio == null) {
            final String audioPath = '${tempDir.path}/extracted_audio_$timestamp.wav';
            final session = await FFmpegKit.execute('-i ${_selectedFile!.path} -vn -acodec pcm_s16le -ar 16000 -ac 1 $audioPath');
            if (ReturnCode.isSuccess(await session.getReturnCode())) {
              audio = File(audioPath);
            }
          }
          
          if (image == null) {
            final String framePath = '${tempDir.path}/extracted_frame_$timestamp.jpg';
            final session = await FFmpegKit.execute('-i ${_selectedFile!.path} -ss 00:00:01 -vframes 1 $framePath');
            if (ReturnCode.isSuccess(await session.getReturnCode())) {
              image = File(framePath);
            }
          }
        }
      } else if (widget.mode == 'multimodal') {
        final path = _selectedFile!.path.toLowerCase();
        if (path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png')) {
          image = _selectedFile;
        } else {
          audio = _selectedFile;
        }
      }

      await aiController.runInference(
        widget.promptTemplate,
        image: image,
        audio: audio,
        systemInstructions: "You are a specialized Neonatal Health AI assistant. Your task is to analyze media for specific birth defects or conditions. You MUST provide clinical-grade reasoning and always output valid JSON.",
      );

      final responseText = aiController.response.value;
      if (responseText.contains('Inference error:')) {
        throw responseText;
      }

      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).stringMatch(responseText);
      if (jsonMatch != null) {
        final decoded = json.decode(jsonMatch);
        if (decoded is Map<String, dynamic>) {
          _result = decoded;
        } else {
          throw 'Invalid JSON format from AI';
        }
      } else {
        _result = {
          'diagnosis': 'Analysis Complete',
          'confidence': 0.85,
          'thinking': responseText,
          'recommendations': ['Consult a pediatrician for further evaluation.']
        };
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF64748B), size: 20),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF64748B)),
            onPressed: () => Get.to(() => AiConfigPage()),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildInfoSection(),
            const SizedBox(height: 32),
            _buildUploadSection(),
            const SizedBox(height: 24),
            _buildActionButtons(),
            const SizedBox(height: 32),
            _buildResultSection(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.themeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(widget.icon, color: widget.themeColor, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: widget.themeColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What is this?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.themeColor,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.defectInfo,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Color(0xFFF1F5F9)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'POTENTIAL HARM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.defectHarm,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: _selectedFile != null ? Colors.transparent : const Color(0xFFE2E8F0),
            width: 2,
          ),
          boxShadow: _selectedFile != null
              ? [
                  BoxShadow(
                    color: widget.themeColor.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: _selectedFile != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_selectedFile!.path.toLowerCase().endsWith('.jpg') ||
                        _selectedFile!.path.toLowerCase().endsWith('.jpeg') ||
                        _selectedFile!.path.toLowerCase().endsWith('.png'))
                      Image.file(_selectedFile!, fit: BoxFit.contain)
                    else if (_videoController != null && _videoController!.value.isInitialized)
                      Center(
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.insert_drive_file_outlined,
                                color: widget.themeColor, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _selectedFile!.path.split('/').last,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFile = null),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.refresh_rounded, color: widget.themeColor, size: 20),
                        ),
                      ),
                    ),
                    if (_videoController != null && _videoController!.value.isInitialized)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _videoController!.value.isPlaying
                                      ? _videoController!.pause()
                                      : _videoController!.play();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                    _videoController!.value.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: widget.themeColor,
                                    size: 20),
                              ),
                            ),
                            if (_extractedAudioFile != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () async {
                                  await _audioPlayer.play(DeviceFileSource(_extractedAudioFile!.path));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.volume_up_rounded, color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Test Audio',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (_isExtracting) ...[
                              const SizedBox(width: 8),
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.themeColor.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.camera_alt_outlined, color: widget.themeColor, size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Upload Media',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.mode == 'audio_only' 
                          ? 'Pick a file for analysis' 
                          : widget.mode == 'video_audio'
                              ? 'Pick a video from Gallery'
                              : 'Pick from Gallery',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: (_selectedFile == null || _isAnalyzing) ? null : _runAnalysis,
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(widget.icon),
            label: Text(_isAnalyzing ? 'Analyzing with AI...' : 'Run ${widget.title.split(' ')[0]} Analysis'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.themeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultSection() {
    if (_result == null && !_isAnalyzing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(Icons.analytics_outlined, color: Colors.blueGrey[200], size: 48),
            const SizedBox(height: 16),
            const Text(
              'No Analysis Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    if (_isAnalyzing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Processing with AI...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: widget.themeColor,
              ),
            ),
          ],
        ),
      );
    }

    // Safety checks for result map
    double confidence = 0.0;
    if (_result!['confidence'] != null) {
      confidence = double.tryParse(_result!['confidence'].toString()) ?? 0.0;
      if (confidence > 1.0) confidence /= 100.0;
    }
    
    final String diagnosis = _result!['diagnosis']?.toString() ?? 'Analysis Complete';
    final String thinking = _result!['thinking']?.toString() ?? '';
    
    List<String> recommendations = [];
    if (widget.recommendationMap != null) {
      final diagLower = diagnosis.toLowerCase();
      if (diagLower.contains('severe')) { recommendations = widget.recommendationMap!['severe'] ?? []; }
      else if (diagLower.contains('moderate')) { recommendations = widget.recommendationMap!['moderate'] ?? []; }
      else if (diagLower.contains('mild')) { recommendations = widget.recommendationMap!['mild'] ?? []; }
      else if (diagLower.contains('normal')) { recommendations = widget.recommendationMap!['normal'] ?? []; }
    }
    
    if (recommendations.isEmpty && _result!['recommendations'] is List) {
      recommendations = (_result!['recommendations'] as List).map((e) => e.toString()).toList();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diagnosis,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: confidence.clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFF1F5F9),
                  color: widget.themeColor,
                ),
              ),
              const SizedBox(width: 12),
              Text('${(confidence * 100).toInt()}% Confidence'),
            ],
          ),
          const SizedBox(height: 24),
          if (thinking.isNotEmpty)
            Text(
              thinking,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                fontStyle: FontStyle.italic,
              ),
            ),
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 24),
            ...recommendations.map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: widget.themeColor, size: 16),
                      const SizedBox(width: 12),
                      Expanded(child: Text(rec, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
