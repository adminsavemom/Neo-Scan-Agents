import 'package:baby_agent_app/controllers/litert_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'jaundice_analyzer_page.dart';
import 'cry_analyzer_page.dart';
import 'asphyxia_analyzer_page.dart';
import 'rds_analyzer_page.dart';
import 'ai_config_page.dart';
import 'video_input_page.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final aiController = Get.find<LitertController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(),
                        const SizedBox(height: 16),
                        Obx(() => _downloadBanner()),
                        const SizedBox(height: 16),
                        _heroSection(),
                        const SizedBox(height: 32),
                        _offlineConnectivityBanner(),
                        const SizedBox(height: 32),
                        const Text(
                          'Available Analyzers',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                    delegate: SliverChildListDelegate([
                      _analyzerCard(
                        title: 'Jaundice AI',
                        subtitle: 'Skin & eye bilirubin analysis',
                        icon: Icons.search_rounded,
                        color: Colors.cyan,
                        onTap: () => Get.to(() => const JaundiceAnalyzerPage()),
                      ),
                      _analyzerCard(
                        title: 'Cry Analysis',
                        subtitle: 'Decode needs via audio',
                        icon: Icons.volume_up_rounded,
                        color: Colors.purple,
                        onTap: () => Get.to(() => const CryAnalyzerPage()),
                      ),
                      _analyzerCard(
                        title: 'Asphyxia',
                        subtitle: 'Oxygen deprivation detection',
                        icon: Icons.favorite_rounded,
                        color: Colors.pink,
                        onTap: () => Get.to(() => const AsphyxiaAnalyzerPage()),
                      ),
                      _analyzerCard(
                        title: 'Respiratory',
                        subtitle: 'Breathing patterns & RDS',
                        icon: Icons.air_rounded,
                        color: Colors.teal,
                        onTap: () => Get.to(() => const RdsAnalyzerPage()),
                      ),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: _disclaimerBanner(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.cyan[600]!, Colors.cyan[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Neoscan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Agents',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan[700],
                    height: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => Get.to(() => AiConfigPage()),
              icon: const Icon(Icons.settings_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueGrey[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _downloadBanner() {
    final isDownloading = aiController.isDownloading.value;
    final isLoaded = aiController.isModelLoaded.value;
    final isLoading = aiController.isLoading.value;
    final progress = aiController.downloadProgress.value;
    final status = aiController.downloadStatus.value;

    // Hide banner once model is fully loaded.
    if (isLoaded) return const SizedBox.shrink();

    final Color bannerColor = isDownloading ? Colors.blue[700]! : Colors.orange[700]!;
    final IconData icon = isDownloading
        ? Icons.downloading_rounded
        : isLoading
            ? Icons.memory_rounded
            : Icons.cloud_download_outlined;
    final String title = isDownloading
        ? 'Downloading AI Model…'
        : isLoading
            ? 'Loading Model into Memory…'
            : 'Model Initializing…';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bannerColor, bannerColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (status.isNotEmpty)
                      Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (isDownloading || isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                color: Colors.white,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(1)}%  •  Savemom AI Model (4B)',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.cyan[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: Colors.cyan[700],
                ),
                const SizedBox(width: 6),
                Text(
                  'INTELLIGENT NEONATAL CARE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan[700],
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Smart Health Agent',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Assessing baby health with clinical-grade AI. Get instant analysis for critical neonatal conditions.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Get.to(() => const VideoInputPage()),
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Start Quick Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _offlineConnectivityBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[800]!, Colors.indigo[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Offline Analysis Ready',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Works perfectly in labour rooms with limited connectivity.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyzerCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: isLocked ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (isLocked)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: Colors.blueGrey[300],
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isLocked
                    ? Colors.blueGrey[400]
                    : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blueGrey[500],
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _disclaimerBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber[100]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.amber[800], size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'This is an AI screening tool, not a diagnostic replacement. Consult a pediatrician for official diagnosis.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
