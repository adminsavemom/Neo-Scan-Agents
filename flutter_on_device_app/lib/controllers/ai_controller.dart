import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';

class AiController extends GetxController {
  // ─── Persistence ───────────────────────────────────────────────────────────
  static const _kModelPathKey = 'model_path';
  static const _kBackendKey = 'preferred_backend';
  final _storage = GetStorage();

  // ─── Observable state ──────────────────────────────────────────────────────
  final modelPath = ''.obs;
  final isModelLoaded = false.obs;
  final isLoading = false.obs;
  final response = ''.obs;
  final streamingResponse = ''.obs;
  final selectedBackend = 'CPU'.obs; // Default to GPU

  // ─── Private model handle ──────────────────────────────────────────────────
  /// Held open for the lifetime of the controller so we can create sessions on
  /// demand.  Closed in [onClose].
  InferenceModel? _inferenceModel;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    final storedPath = _storage.read<String>(_kModelPathKey) ?? '';
    if (storedPath.isNotEmpty) {
      modelPath.value = storedPath;
      // Removed loadModel(stored) to prevent loading on app open
      // loadModel(storedPath);
    }

    final storedBackend = _storage.read<String>(_kBackendKey) ?? 'GPU';
    selectedBackend.value = storedBackend;
  }

  @override
  void onClose() {
    _inferenceModel?.close();
    super.onClose();
  }

  // ─── Public: model management ──────────────────────────────────────────────

  /// Persists [path] to storage.
  Future<void> setModelPath(String path) async {
    modelPath.value = path;
    await _storage.write(_kModelPathKey, path);
    // Removed automatic loadModel(path) call
  }

  /// Sets and persists the preferred backend.
  Future<void> setBackend(String backend) async {
    selectedBackend.value = backend;
    await _storage.write(_kBackendKey, backend);
  }

  /// Loads the model at [path].
  ///
  /// Closes any previously loaded model first, then calls
  /// [FlutterGemma.installModel] + [FlutterGemma.getActiveModel] so the
  /// model is registered as the active inference model.
  Future<void> loadModel(String path) async {
    if (path.isEmpty) return;

    isLoading.value = true;
    isModelLoaded.value = false;

    try {
      // ── Close the previous model handle ──
      await _inferenceModel?.close();
      _inferenceModel = null;

      // ── Register the file as the active inference model ──
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: _resolveFileType(path),
      ).fromFile(path).install();

      // ── Create the model handle (image + audio capable) ──
      _inferenceModel = await FlutterGemma.getActiveModel(
        maxTokens: 2048,
        supportImage: true,
        supportAudio: true,
        preferredBackend: _getPreferredBackend(),
        enableSpeculativeDecoding: true,
      );

      isModelLoaded.value = true;
    } catch (e) {
      isModelLoaded.value = false;
      Get.snackbar(
        'Error',
        'Failed to load model: $e',
        duration: const Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Loads model data supplied as raw bytes by writing it to a temp file first.
  Future<void> loadModelFromMemory(
    Uint8List modelData, {
    String filename = 'model.task',
  }) async {
    isLoading.value = true;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(modelData);
      await setModelPath(file.path);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load model from memory: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Public: inference ─────────────────────────────────────────────────────

  /// Runs a single inference turn.
  ///
  /// * Creates a new [InferenceModelSession] with vision + audio modalities.
  /// * Optionally attaches [imageFile] and/or [audioFile] to the message.
  /// * Streams the response back via [streamingResponse].
  /// * Closes the session when done.
  ///
  /// [image]  – Optional image file (JPEG/PNG) for multimodal input.
  /// [audio]  – Optional audio file (WAV/MP3) for audio input.
  Future<void> runInference(
    String prompt, {
    File? image,
    File? audio,
    String? systemInstructions,
  }) async {
    debugPrint("Running Inference with Image : ${image?.path}");
    debugPrint("Running Inference with Audio : ${audio?.path}");
    debugPrint("Running Inference with Prompt : $prompt");

    if (!isModelLoaded.value || _inferenceModel == null) {
      response.value =
          'Model not loaded. Please select and load a model first.';
      return;
    }

    isLoading.value = true;
    streamingResponse.value = '';
    response.value = '';

    InferenceModelSession? session;
    try {
      // ── 1. Determine which modalities we need ──────────────────────────────
      final needsVision = image != null;
      final needsAudio = audio != null;

      // ── 2. Create a session ───────────────────────────────────────────────
      session = await _inferenceModel!.createSession(
        temperature: 0.4,
        topK: 40,
        randomSeed: 1,
        enableVisionModality: needsVision,
        enableAudioModality: needsAudio,
        systemInstruction: systemInstructions,
      );

      // ── 3. Build the message ───────────────────────────────────────────────
      Uint8List? imageBytes;
      if (needsVision) {
        imageBytes = await image.readAsBytes();
      }

      Uint8List? audioBytes;
      if (needsAudio) {
        audioBytes = await audio.readAsBytes();
      }

      String finalPrompt = prompt;
      if (needsVision && !finalPrompt.contains('<image>')) {
        finalPrompt = '<image>$finalPrompt';
      }
      if (needsAudio && !finalPrompt.contains('<audio>')) {
        finalPrompt = '<audio>$finalPrompt';
      }

      await addQueryChunk(
        session: session,
        text: finalPrompt,
        imageBytes: imageBytes,
        audioBytes: audioBytes,
      );

      // ── 4. Add message to the session ──────────────────────────────────────
      // await session.addQueryChunk(message);

      // ── 5. Stream the response ────────────────────────────────────────────
      final buffer = StringBuffer();

      await for (final token in session.getResponseAsync()) {
        buffer.write(token);
        streamingResponse.value = buffer.toString();
      }

      response.value = streamingResponse.value;
    } catch (e) {
      print(e);
      response.value = 'Inference error: $e';
      Get.snackbar(
        'Inference Error',
        e.toString(),
        duration: const Duration(seconds: 5),
      );
    } finally {
      // ── 6. Always close the session to release native resources ────────────
      await session?.close();
      isLoading.value = false;
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Picks [ModelFileType.task] for .task/.litertlm files, binary otherwise.
  ModelFileType _resolveFileType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.task')) {
      return ModelFileType.task;
    }

    if (lower.endsWith('.litertlm')) {
      return ModelFileType.litertlm;
    }

    return ModelFileType.binary;
  }

  /// Builds the appropriate [Message] depending on which media is provided.
  Future<void> addQueryChunk({
    required InferenceModelSession session,
    required String text,
    Uint8List? imageBytes,
    Uint8List? audioBytes,
  }) async {
    if (imageBytes != null) {
      await session.addQueryChunk(
        Message.withImage(text: text, imageBytes: imageBytes, isUser: true),
      );
    }
    if (audioBytes != null) {
      await session.addQueryChunk(
        Message.withAudio(text: text, audioBytes: audioBytes, isUser: true),
      );
    }
    if (text.isNotEmpty) {
      await session.addQueryChunk(Message.text(text: text, isUser: true));
    }
  }

  PreferredBackend _getPreferredBackend() {
    switch (selectedBackend.value) {
      case 'CPU':
        return PreferredBackend.cpu;
      case 'NPU':
        // If NPU is not supported, it might fall back or be handled by the lib
        // Using GPU as fallback if NPU isn't explicitly in the enum
        return PreferredBackend.npu;
      case 'GPU':
      default:
        return PreferredBackend.gpu;
    }
  }
}
