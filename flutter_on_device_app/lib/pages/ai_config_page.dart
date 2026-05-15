import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import '../controllers/ai_controller.dart';

class AiConfigPage extends StatelessWidget {
  final AiController controller = Get.find<AiController>();
  final TextEditingController _promptController = TextEditingController();

  // Reactive file selections (not in controller since they're view-only state).
  final Rxn<File> _selectedImage = Rxn<File>();
  final Rxn<File> _selectedAudio = Rxn<File>();

  AiConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('AI Configuration'),
        backgroundColor: Colors.cyan[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Model Status ───────────────────────────────────────────────
            _sectionTitle('Model Status'),
            const SizedBox(height: 8),
            Obx(() => _statusCard(controller)),
            const SizedBox(height: 24),

            // ── Model Selection ────────────────────────────────────────────
            _sectionTitle('Model Selection'),
            const SizedBox(height: 8),
            _filePicker(
              label: 'Select Model File',
              hint: '.task  ·  .litertlm  ·  .bin',
              icon: Icons.memory_rounded,
              color: Colors.cyan[700]!,
              onTap: _pickModel,
            ),
            const SizedBox(height: 12),
            Obx(() => SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.modelPath.value.isEmpty || controller.isLoading.value
                    ? null
                    : () => controller.loadModel(controller.modelPath.value),
                icon: controller.isLoading.value
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded),
                label: Text(controller.isModelLoaded.value ? 'Reload Model' : 'Load Model'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )),
            const SizedBox(height: 24),

            // ── Backend Selection ──────────────────────────────────────────
            _sectionTitle('Preferred Backend'),
            const SizedBox(height: 8),
            Obx(() => _backendSelector()),
            const SizedBox(height: 24),

            // ── Multimodal Inputs ──────────────────────────────────────────
            _sectionTitle('Multimodal Inputs (Optional)'),
            const SizedBox(height: 8),
            Obx(() => _mediaChip(
              label: _selectedImage.value?.path.split('/').last ?? 'Attach Image',
              icon: Icons.image_rounded,
              color: Colors.deepPurple,
              selected: _selectedImage.value != null,
              onTap: _pickImage,
              onClear: () => _selectedImage.value = null,
            )),
            const SizedBox(height: 8),
            Obx(() => _mediaChip(
              label: _selectedAudio.value?.path.split('/').last ?? 'Attach Audio',
              icon: Icons.audiotrack_rounded,
              color: Colors.teal,
              selected: _selectedAudio.value != null,
              onTap: _pickAudio,
              onClear: () => _selectedAudio.value = null,
            )),
            const SizedBox(height: 24),

            // ── Prompt ────────────────────────────────────────────────────
            _sectionTitle('Prompt'),
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter your prompt…',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.cyan[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.cyan[200]!),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Run Inference button ───────────────────────────────────────
            Obx(() => SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: controller.isLoading.value ? null : _runInference,
                icon: controller.isLoading.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(controller.isLoading.value
                    ? 'Running…'
                    : 'Run Inference'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )),
            const SizedBox(height: 24),

            // ── Response ──────────────────────────────────────────────────
            _sectionTitle('Response'),
            const SizedBox(height: 8),
            Obx(() {
              final text = controller.isLoading.value
                  ? controller.streamingResponse.value
                  : controller.response.value;
              return Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan[100]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyan.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SelectableText(
                  text.isEmpty ? 'Response will appear here…' : text,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: text.isEmpty ? Colors.grey[400] : Colors.black87,
                    height: 1.5,
                  ),
                ),
              );
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── UI helpers ────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
          letterSpacing: 0.5,
        ),
      );

  Widget _statusCard(AiController c) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: c.isModelLoaded.value ? Colors.green[200]! : Colors.red[200]!,
          ),
        ),
        child: ListTile(
          leading: Icon(
            c.isModelLoaded.value ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: c.isModelLoaded.value ? Colors.green : Colors.red,
            size: 30,
          ),
          title: Text(
            c.isModelLoaded.value ? 'Model Ready' : 'No Model Loaded',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            c.modelPath.value.isEmpty
                ? 'Pick a model file below'
                : c.modelPath.value.split('/').last,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );

  Widget _filePicker({
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            Text(hint, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(56),
        ),
      );

  Widget _mediaChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) =>
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : Colors.white,
            border: Border.all(
                color: selected ? color : Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? color : Colors.grey[600],
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (selected)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close_rounded, color: color, size: 18),
                ),
            ],
          ),
        ),
      );

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickModel() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      await controller.setModelPath(result.files.single.path!);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      _selectedImage.value = File(result.files.single.path!);
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );
    if (result != null && result.files.single.path != null) {
      _selectedAudio.value = File(result.files.single.path!);
    }
  }

  void _runInference() {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      Get.snackbar('Prompt required', 'Please enter a prompt before running inference.');
      return;
    }
    controller.runInference(
      prompt,
      image: _selectedImage.value,
      audio: _selectedAudio.value,
    );
  }

  Widget _backendSelector() {
    final backends = ['CPU', 'GPU', 'NPU'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan[100]!),
      ),
      child: Row(
        children: backends.map((backend) {
          final isSelected = controller.selectedBackend.value == backend;
          return Expanded(
            child: GestureDetector(
              onTap: () => controller.setBackend(backend),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.cyan[700] : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  backend,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
