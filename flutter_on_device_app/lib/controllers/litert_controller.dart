import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';

class LitertController extends GetxController {
  // ─── Constants ─────────────────────────────────────────────────────────────
  static const _modelUrl = 'https://download.savemom.app/4b.litertlm';
  static const _modelFilename = '4b.litertlm';
  static const _kBackendKey = 'litert_preferred_backend';

  final _storage = GetStorage();
  final _dio = Dio();

  // ─── Observable state ──────────────────────────────────────────────────────
  final modelPath = ''.obs;
  final isModelLoaded = false.obs;
  final isLoading = false.obs;
  final isDownloading = false.obs;
  final downloadProgress = 0.0.obs;  // 0.0 – 1.0
  final downloadStatus = ''.obs;     // human-readable status message
  final response = ''.obs;
  final streamingResponse = ''.obs;
  final selectedBackend = 'GPU'.obs;

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
    final storedBackend = _storage.read<String>(_kBackendKey) ?? 'CPU';
    selectedBackend.value = storedBackend;

    // Kick off model download/load automatically.
    _ensureModelReady();
  }

  @override
  void onClose() {
    _streamSubscription?.cancel();
    _methodChannel.invokeMethod('closeModel');
    super.onClose();
  }

  // ─── Model bootstrap ──────────────────────────────────────────────────────

  Future<void> _ensureModelReady() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelFile = File('${dir.path}/$_modelFilename');

    if (await modelFile.exists()) {
      // Already downloaded – just load it.
      downloadStatus.value = 'Model found locally.';
      modelPath.value = modelFile.path;
      await loadModel(modelFile.path);
    } else {
      await _downloadModel(modelFile);
    }
  }

  Future<void> _downloadModel(File dest) async {
    isDownloading.value = true;
    downloadProgress.value = 0.0;
    downloadStatus.value = 'Starting download…';

    try {
      await _dio.download(
        _modelUrl,
        dest.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            downloadProgress.value = received / total;
            final mb = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMb = (total / 1024 / 1024).toStringAsFixed(1);
            downloadStatus.value = 'Downloading: $mb / $totalMb MB';
          }
        },
      );

      downloadStatus.value = 'Download complete. Loading model…';
      downloadProgress.value = 1.0;
      modelPath.value = dest.path;
      await loadModel(dest.path);
    } catch (e) {
      downloadStatus.value = 'Download failed: $e';
      debugPrint('Model download error: $e');
      // Delete partial file if present.
      if (await dest.exists()) await dest.delete();
      Get.snackbar(
        'Download Failed',
        e.toString(),
        duration: const Duration(seconds: 6),
      );
    } finally {
      isDownloading.value = false;
    }
  }

  // ─── Public: model management ──────────────────────────────────────────────

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
        downloadStatus.value = 'Model ready ✓';
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
      modelPath.value = file.path;
      await loadModel(file.path);
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
          'Model not loaded. Please wait for the model to finish downloading and loading.';
      return;
    }

    isLoading.value = true;
    streamingResponse.value = '';
    response.value = '';

    final completer = Completer<void>();

    try {
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
            if (!completer.isCompleted) {
              completer.completeError(event['message'] ?? 'Unknown error');
            }
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
