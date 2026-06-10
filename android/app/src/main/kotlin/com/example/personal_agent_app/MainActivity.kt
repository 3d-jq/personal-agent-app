package com.example.personal_agent_app

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example/save_to_gallery"
    private val OPEN_CHANNEL = "com.example/open_file"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveImage") {
                try {
                    val bytes = call.argument<ByteArray>("bytes")
                    val name = call.argument<String>("name") ?: "image.png"
                    if (bytes == null) {
                        result.error("NO_DATA", "No image data provided", null)
                        return@setMethodCallHandler
                    }
                    saveImageToGallery(bytes, name)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("SAVE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OPEN_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openFile") {
                try {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("NO_PATH", "No file path", null)
                        return@setMethodCallHandler
                    }
                    val file = File(path)
                    val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "video/*")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("OPEN_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveImageToGallery(bytes: ByteArray, name: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/AgnesAI")
            }
            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
            uri?.let {
                contentResolver.openOutputStream(it)?.use { os -> os.write(bytes) }
            }
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "AgnesAI")
            if (!dir.exists()) dir.mkdirs()
            val file = File(dir, name)
            FileOutputStream(file).use { it.write(bytes) }
        }
    }
}
