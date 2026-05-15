import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';

class LitertController extends GetxController {
  // ─── Persistence ───────────────────────────────────────────────────────────
  static const _kModelPathKey = 'litert_model_path';
  static const _kBackendKey = 'litert_preferred_backend';
  final _storage = GetStorage();

  // ─── Observable state ──────────────────────────────────────────────────────
  final modelPath = ''.obs;
  final isModelLoaded = false.obs;
  final isLoading = false.obs;
  final response = ''.obs;
  final streamingResponse = ''.obs;
  final selectedBackend = 'CPU'.obs;

  // ─── Method Channels ──────────────────────────────────────────────────────
  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.baby_agent_app/litert',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.baby_agent_app/litert_stream',
  );

  StreamSubscription? _streamSubscription;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    final storedPath = _storage.read<String>(_kModelPathKey) ?? '';
    if (storedPath.isNotEmpty) {
      modelPath.value = storedPath;
      loadModel(storedPath);
    }

    final storedBackend = _storage.read<String>(_kBackendKey) ?? 'GPU';
    selectedBackend.value = storedBackend;
  }

  @override
  void onClose() {
    _streamSubscription?.cancel();
    _methodChannel.invokeMethod('closeModel');
    super.onClose();
  }

  // ─── Public: model management ──────────────────────────────────────────────

  Future<void> setModelPath(String path) async {
    modelPath.value = path;
    await _storage.write(_kModelPathKey, path);
  }

  Future<void> setBackend(String backend) async {
    selectedBackend.value = backend;
    await _storage.write(_kBackendKey, backend);
  }

  Future<void> loadModel(String path) async {
    if (path.isEmpty) return;

    isLoading.value = true;
    isModelLoaded.value = false;

    try {
      final success = await _methodChannel.invokeMethod<bool>('loadModel', {
        'path': path,
        'backend': selectedBackend.value,
      });

      if (success == true) {
        isModelLoaded.value = true;
      } else {
        isModelLoaded.value = false;
        Get.snackbar('Error', 'Failed to load model from native side');
      }
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

  Future<void> loadModelFromMemory(
    Uint8List modelData, {
    String filename = 'model.litertlm',
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

  Future<void> runInference(
    String prompt, {
    File? image,
    File? audio,
    String? systemInstructions,
  }) async {
    debugPrint("Running LiteRT Inference with Image : ${image?.path}");
    debugPrint("Running LiteRT Inference with Audio : ${audio?.path}");
    debugPrint("Running LiteRT Inference with Prompt : $prompt");

    if (!isModelLoaded.value) {
      response.value =
          'Model not loaded. Please select and load a model first.';
      return;
    }

    isLoading.value = true;
    streamingResponse.value = '';
    response.value = '';

    final completer = Completer<void>();

    try {
      // Set up listener for streaming
      _streamSubscription?.cancel();
      _streamSubscription = _eventChannel.receiveBroadcastStream().listen((
        event,
      ) {
        if (event is String) {
          streamingResponse.value += event;
          response.value = streamingResponse.value;
        } else if (event is Map) {
          if (event['status'] == 'done') {
            isLoading.value = false;
            if (!completer.isCompleted) completer.complete();
          } else if (event['status'] == 'error') {
            Get.snackbar(
              'Inference Error',
              event['message'] ?? 'Unknown error',
            );
            isLoading.value = false;
            if (!completer.isCompleted) completer.completeError(event['message'] ?? 'Unknown error');
          }
        }
      }, onError: (error) {
        if (!completer.isCompleted) completer.completeError(error);
      });

      await _methodChannel.invokeMethod('runInference', {
        'prompt': prompt,
        'imagePath': image?.path,
        'audioPath': audio?.path,
        'systemInstructions': systemInstructions,
      });

      await completer.future;
    } catch (e) {
      debugPrint(e.toString());
      response.value = 'Inference error: $e';
      isLoading.value = false;
      if (!completer.isCompleted) completer.completeError(e);
      Get.snackbar(
        'Inference Error',
        e.toString(),
        duration: const Duration(seconds: 5),
      );
    }
  }
}
