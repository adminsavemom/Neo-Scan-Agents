import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'pages/home_page.dart';
import 'controllers/ai_controller.dart';
import 'controllers/litert_controller.dart';
void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Gemma with error handling
    try {
      await FlutterGemma.initialize();
      debugPrint("Gemma initialized successfully");
    } catch (e) {
      debugPrint("Gemma initialization failed: $e");
    }

    await GetStorage.init();
    Get.put(AiController());
    Get.put(LitertController());
    runApp(const MyApp());
  } catch (e) {
    debugPrint("Critical startup error: $e");
    // Still try to run the app even if initialization fails
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Neoscan Agents',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
        useMaterial3: true,
        fontFamily:
            'Inter', // Assuming Inter is available or fallback to default
      ),
      home: HomePage(),
    );
  }
}
