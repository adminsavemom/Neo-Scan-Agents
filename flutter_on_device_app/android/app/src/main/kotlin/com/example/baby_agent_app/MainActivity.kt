package com.example.baby_agent_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import com.google.ai.edge.litertlm.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL = "com.example.baby_agent_app/litert"
    private val EVENT_CHANNEL = "com.example.baby_agent_app/litert_stream"
    
    private var engine: Engine? = null
    private var eventSink: EventChannel.EventSink? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val path = call.argument<String>("path")
                    val backend = call.argument<String>("backend")
                    if (path != null) {
                        loadModel(path, backend ?: "GPU", result)
                    } else {
                        result.error("INVALID_ARGS", "Path is required", null)
                    }
                }
                "runInference" -> {
                    val prompt = call.argument<String>("prompt")
                    val imagePath = call.argument<String>("imagePath")
                    val audioPath = call.argument<String>("audioPath")
                    val systemInstructions = call.argument<String>("systemInstructions")
                    
                    if (prompt != null) {
                        runInference(prompt, imagePath, audioPath, systemInstructions, result)
                    } else {
                        result.error("INVALID_ARGS", "Prompt is required", null)
                    }
                }
                "closeModel" -> {
                    if (engine?.isInitialized() == true) {
                        engine?.close()
                    }
                    engine = null
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun loadModel(path: String, backendStr: String, result: MethodChannel.Result) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                if (engine?.isInitialized() == true) {
                    engine?.close()
                }
                engine = null
                
                val backend = when(backendStr.uppercase()) {
                    "CPU" -> Backend.CPU()
                    "NPU" -> Backend.NPU()
                    else -> Backend.GPU()
                }
                
                val engineConfig = EngineConfig(
                    modelPath = path,
                    backend = backend,
                    visionBackend = backend,
                    audioBackend = backend
                )
                
                val newEngine = Engine(engineConfig)
                newEngine.initialize()
                engine = newEngine
                
                withContext(Dispatchers.Main) {
                    result.success(true)
                }
            } catch (e: Exception) {
                engine = null
                withContext(Dispatchers.Main) {
                    result.error("LOAD_ERROR", e.message ?: "Unknown error during initialization", null)
                }
            }
        }
    }
    
    private fun runInference(prompt: String, imagePath: String?, audioPath: String?, systemInstructions: String?, result: MethodChannel.Result) {
        if (engine?.isInitialized() != true) {
            result.error("NOT_LOADED", "Model is not loaded or initialized", null)
            return
        }
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                withContext(Dispatchers.Main) {
                    result.success(true)
                }
                
                engine?.createConversation()?.use { conversation ->
                    val contents = mutableListOf<Content>()
                    
                    if (imagePath != null) {
                        contents.add(Content.ImageFile(imagePath))
                    }
                    if (audioPath != null) {
                        val fileBytes = File(audioPath).readBytes()
                        contents.add(Content.AudioBytes(fileBytes))
                    }
                    contents.add(Content.Text(prompt))
                    
                    val contentsObj = Contents.of(*contents.toTypedArray())
                    
                    conversation.sendMessageAsync(contentsObj).collect { token ->
                        withContext(Dispatchers.Main) {
                            eventSink?.success(token.toString())
                        }
                    }
                    
                    withContext(Dispatchers.Main) {
                        eventSink?.success(mapOf("status" to "done"))
                    }
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    eventSink?.success(mapOf("status" to "error", "message" to e.message))
                }
            }
        }
    }
}
