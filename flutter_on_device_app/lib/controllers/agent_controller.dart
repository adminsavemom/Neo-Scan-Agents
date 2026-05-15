import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'ai_controller.dart';

class AnalysisStep {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final String mode; // 'visual', 'audio', 'multimodal'
  final RxString status; // 'pending', 'processing', 'completed', 'error'

  AnalysisStep({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.mode,
    String initialStatus = 'pending',
  }) : status = initialStatus.obs;
}

class AnalysisResult {
  final String module;
  final String diagnosis;
  final double confidence;
  final String thinking;
  final List<String> recommendations;
  final Color color;
  final IconData icon;

  AnalysisResult({
    required this.module,
    required this.diagnosis,
    required this.confidence,
    required this.thinking,
    this.recommendations = const [],
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
    'module': module,
    'diagnosis': diagnosis,
    'confidence': confidence,
    'thinking': thinking,
    'recommendations': recommendations,
  };
}

class ChatMessage {
  final String id;
  final String role; // 'user', 'assistant'
  final String content;
  final DateTime timestamp;
  final AnalysisResult? result;
  final bool isSystem;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.result,
    this.isSystem = false,
  });
}

class AgentController extends GetxController {
  final AiController aiController = Get.find<AiController>();

  final RxList<AnalysisStep> steps = <AnalysisStep>[
    AnalysisStep(id: 'jaundice', label: 'Jaundice', description: 'Bilirubin', icon: Icons.search_rounded, mode: 'visual'),
    AnalysisStep(id: 'cry', label: 'Cry', description: 'Acoustic', icon: Icons.volume_up_rounded, mode: 'audio'),
    AnalysisStep(id: 'asphyxia', label: 'Asphyxia', description: 'Oxygen', icon: Icons.favorite_rounded, mode: 'multimodal'),
    AnalysisStep(id: 'rds', label: 'RDS', description: 'Breathing', icon: Icons.air_rounded, mode: 'multimodal'),
    AnalysisStep(id: 'cyanosis', label: 'Cyanosis', description: 'SPO2', icon: Icons.shield_rounded, mode: 'visual'),
    AnalysisStep(id: 'synthesis', label: 'Summary', description: 'Holistic', icon: Icons.auto_awesome_rounded, mode: 'multimodal'),
  ].obs;

  final RxList<ChatMessage> messages = <ChatMessage>[
    ChatMessage(
      id: 'welcome',
      role: 'assistant',
      content: 'Hello! I am your AI Health Agent. Upload a video of the baby, and I will perform a systematic AI analysis across all diagnostic modules to identify any potential health issues.',
      timestamp: DateTime.now(),
    ),
  ].obs;

  final RxBool isAnalyzing = false.obs;
  final RxBool allCompleted = false.obs;
  final RxString chatInput = ''.obs;
  final Rxn<File> videoFile = Rxn<File>();
  final Rxn<File> extractedFrame = Rxn<File>();
  final Rxn<File> extractedAudio = Rxn<File>();

  Future<void> processVideo(File file) async {
    videoFile.value = file;
    isAnalyzing.value = true;
    allCompleted.value = false;
    
    // Reset steps
    for (var step in steps) {
      step.status.value = 'pending';
    }
    
    // Clear previous analysis messages but keep welcome
    messages.value = [messages[0]];

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      
      // 1. Extract Mid Frame (Representative Frame)
      final String framePath = '${tempDir.path}/agent_frame_$timestamp.jpg';
      // We'll try to get frame at 50% duration if possible, but 1s is safer for quick check
      final frameSession = await FFmpegKit.execute('-i ${file.path} -ss 00:00:01 -vframes 1 $framePath');
      if (ReturnCode.isSuccess(await frameSession.getReturnCode())) {
        extractedFrame.value = File(framePath);
      }

      // 2. Extract Audio
      final String audioPath = '${tempDir.path}/agent_audio_$timestamp.wav';
      final audioSession = await FFmpegKit.execute('-i ${file.path} -vn -acodec pcm_s16le -ar 16000 -ac 1 $audioPath');
      if (ReturnCode.isSuccess(await audioSession.getReturnCode())) {
        extractedAudio.value = File(audioPath);
      }

      // 3. Run Agent Flow
      await _runAgentFlow();
    } catch (e) {
      _addMessage(ChatMessage(
        id: DateTime.now().toString(),
        role: 'assistant',
        content: 'Failed to process video: $e',
        timestamp: DateTime.now(),
      ));
    } finally {
      isAnalyzing.value = false;
    }
  }

  Future<void> _runAgentFlow() async {
    final Map<String, String> prompts = {
      'jaundice': "Analyze the visual frame for signs of neonatal Jaundice (Icterus). CRITICAL: Look for ANY yellowish tint in skin or sclera. Keep reasoning extremely concise (max 1 sentence). Return JSON: { \"diagnosis\": \"...\", \"confidence\": 0.0-1.0, \"thinking\": \"...\" }",
      'cry': "Analyze the audio for baby cry patterns. Look for pain, hunger, or distress signals. Keep reasoning extremely concise (max 1 sentence). Return JSON: { \"diagnosis\": \"...\", \"confidence\": 0.0-1.0, \"thinking\": \"...\" }",
      'asphyxia': "Analyze for Birth Asphyxia risk markers using both visual cues (color, tone) and audio (cry). Keep reasoning extremely concise (max 1 sentence). Return JSON: { \"diagnosis\": \"...\", \"confidence\": 0.0-1.0, \"thinking\": \"...\" }",
      'rds': "Analyze for Respiratory Distress Syndrome signs (retractions, grunting). Keep reasoning extremely concise (max 1 sentence). Return JSON: { \"diagnosis\": \"...\", \"confidence\": 0.0-1.0, \"thinking\": \"...\" }",
      'cyanosis': "Analyze the visual frame for Cyanosis (bluish tint). Keep reasoning extremely concise (max 1 sentence). Return JSON: { \"diagnosis\": \"...\", \"confidence\": 0.0-1.0, \"thinking\": \"...\" }",
    };

    final List<String> accumulatedResults = [];

    for (var step in steps) {
      if (step.id == 'synthesis') continue;

      step.status.value = 'processing';
      final msgId = DateTime.now().toString();
      _addMessage(ChatMessage(
        id: msgId,
        role: 'assistant',
        content: 'Running AI ${step.label} analysis...',
        timestamp: DateTime.now(),
        isSystem: true,
      ));

      File? image = (step.mode == 'visual' || step.mode == 'multimodal') ? extractedFrame.value : null;
      File? audio = (step.mode == 'audio' || step.mode == 'multimodal') ? extractedAudio.value : null;

      try {
        await aiController.runInference(
          prompts[step.id]!,
          image: image,
          audio: audio,
          systemInstructions: "You are a specialized Neonatal Health AI Agent. Analyze the provided multimodal data with high clinical sensitivity. Always return valid JSON.",
        );

        final resultText = aiController.response.value;
        final jsonMatch = RegExp(r'\{.*\}', dotAll: true).stringMatch(resultText);
        
        if (jsonMatch != null) {
          final decoded = json.decode(jsonMatch);
          final result = AnalysisResult(
            module: step.label,
            diagnosis: decoded['diagnosis'] ?? 'Normal',
            confidence: _parseConfidence(decoded['confidence']),
            thinking: decoded['thinking'] ?? 'Analysis complete.',
            recommendations: (decoded['recommendations'] as List?)?.map((e) => e.toString()).toList() ?? [],
            color: _getModuleColor(step.id),
            icon: step.icon,
          );

          accumulatedResults.add("${step.label}: ${result.diagnosis} (${result.thinking})");
          
          // Replace system message with result card
          final index = messages.indexWhere((m) => m.id == msgId);
          if (index != -1) {
            messages[index] = ChatMessage(
              id: msgId,
              role: 'assistant',
              content: '',
              timestamp: DateTime.now(),
              result: result,
            );
          }
        }
        step.status.value = 'completed';
      } catch (e) {
        step.status.value = 'error';
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Synthesis Step
    final synthesisStep = steps.firstWhere((s) => s.id == 'synthesis');
    synthesisStep.status.value = 'processing';
    
    final synthMsgId = DateTime.now().toString();
    _addMessage(ChatMessage(
      id: synthMsgId,
      role: 'assistant',
      content: 'Synthesizing holistic health report...',
      timestamp: DateTime.now(),
      isSystem: true,
    ));

    final synthesisPrompt = "Based on these individual module findings: ${accumulatedResults.join("; ")}. Provide a holistic clinical synthesis and integrated recommendations. Return JSON: { \"diagnosis\": \"...\", \"confidence\": 0.0-1.0, \"thinking\": \"...\", \"recommendations\": [...] }";

    try {
      await aiController.runInference(
        synthesisPrompt,
        image: extractedFrame.value,
        audio: extractedAudio.value,
        systemInstructions: "You are a specialized Neonatal Health AI Agent. Provide a final holistic summary based on multiple diagnostic results.",
      );

      final resultText = aiController.response.value;
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).stringMatch(resultText);
      
      if (jsonMatch != null) {
        final decoded = json.decode(jsonMatch);
        final result = AnalysisResult(
          module: 'Final Summary',
          diagnosis: decoded['diagnosis'] ?? 'Overall Healthy',
          confidence: _parseConfidence(decoded['confidence']),
          thinking: decoded['thinking'] ?? 'All systems evaluated.',
          recommendations: (decoded['recommendations'] as List?)?.map((e) => e.toString()).toList() ?? ['Routine monitoring recommended.'],
          color: Colors.teal,
          icon: Icons.auto_awesome_rounded,
        );

        final index = messages.indexWhere((m) => m.id == synthMsgId);
        if (index != -1) {
          messages[index] = ChatMessage(
            id: synthMsgId,
            role: 'assistant',
            content: result.thinking,
            timestamp: DateTime.now(),
            result: result,
          );
        }
      }
      synthesisStep.status.value = 'completed';
    } catch (e) {
      synthesisStep.status.value = 'error';
    }

    allCompleted.value = true;
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || isAnalyzing.value) return;

    final userMsg = ChatMessage(
      id: DateTime.now().toString(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    _addMessage(userMsg);

    final typingId = DateTime.now().toString();
    _addMessage(ChatMessage(
      id: typingId,
      role: 'assistant',
      content: '...',
      timestamp: DateTime.now(),
      isSystem: true,
    ));

    // Build context
    final List<Map<String, String>> history = [];
    for (var m in messages) {
      if (m.isSystem && m.content != '...') continue;
      String content = m.content;
      if (m.result != null) {
        content = "[${m.result!.module} Analysis] Result: ${m.result!.diagnosis}. Reasoning: ${m.result!.thinking}. Recommendations: ${m.result!.recommendations.join("; ")}";
      }
      history.add({'role': m.role, 'content': content});
    }

    final summary = messages.firstWhereOrNull((m) => m.result?.module == 'Final Summary')?.result;
    final contextPrefix = summary != null 
        ? "[CONTEXT: Final Screening Summary: ${summary.diagnosis}. Integrated Recommendations: ${summary.recommendations.join("; ")}] "
        : "";

    try {
      await aiController.runInference(
        contextPrefix + text,
        image: extractedFrame.value,
        audio: extractedAudio.value,
        systemInstructions: "You are a professional Neonatal Health AI. Answer user questions accurately based on the screening results provided. Be supportive but clinically precise. If asked for medical advice, always refer back to the generated recommendations.",
      );

      final responseText = aiController.response.value;
      final index = messages.indexWhere((m) => m.id == typingId);
      if (index != -1) {
        messages[index] = ChatMessage(
          id: typingId,
          role: 'assistant',
          content: responseText,
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      final index = messages.indexWhere((m) => m.id == typingId);
      if (index != -1) {
        messages[index] = ChatMessage(
          id: typingId,
          role: 'assistant',
          content: "I'm having trouble processing your query right now. Please refer to the clinical summary above.",
          timestamp: DateTime.now(),
        );
      }
    }
  }

  void _addMessage(ChatMessage msg) {
    messages.add(msg);
  }

  double _parseConfidence(dynamic val) {
    if (val == null) return 0.85;
    try {
      double c = double.parse(val.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
      if (c > 1.0) c /= 100.0;
      return c.clamp(0.0, 1.0);
    } catch (_) {
      return 0.85;
    }
  }

  Color _getModuleColor(String id) {
    switch (id) {
      case 'jaundice': return Colors.cyan;
      case 'cry': return Colors.purple;
      case 'asphyxia': return Colors.pink;
      case 'rds': return Colors.teal;
      case 'cyanosis': return Colors.blue;
      case 'synthesis': return Colors.teal;
      default: return Colors.cyan;
    }
  }
}
