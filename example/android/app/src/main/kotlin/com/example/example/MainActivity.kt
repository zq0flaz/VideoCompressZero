package com.example.example

import io.flutter.embedding.android.FlutterActivity
import android.media.MediaExtractor
import android.media.MediaFormat
import android.content.pm.ApplicationInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    // Example-host test probe only. It does not change the package API.
    private var mediaProbe: MethodChannel? = null
    private var probeWorker: java.util.concurrent.ExecutorService? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return
        val worker = Executors.newSingleThreadExecutor()
        probeWorker = worker
        mediaProbe = MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "video_compress_zero_example/media_probe").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "inspect") result.notImplemented()
                else {
                    val path = call.argument<String>("path")
                    worker.execute {
                        try {
                            require(!path.isNullOrEmpty()) { "Missing media path" }
                            val data = inspectMedia(path)
                            runOnUiThread { result.success(data) }
                        } catch (error: Exception) {
                            runOnUiThread { result.error("media_probe", error.message, null) }
                        }
                    }
                }
            }
        }
    }

    private fun inspectMedia(path: String): Map<String, Any> {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
            var audioTracks = 0
            var videoTrack = -1
            for (index in 0 until extractor.trackCount) {
                val mime = extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) audioTracks++
                if (videoTrack == -1 && mime.startsWith("video/")) videoTrack = index
            }
            require(videoTrack >= 0) { "No video track" }
            extractor.selectTrack(videoTrack)
            var count = 0
            var first = Long.MAX_VALUE
            var last = Long.MIN_VALUE
            while (extractor.sampleTime >= 0 && count < 4096) {
                val time = extractor.sampleTime
                first = minOf(first, time)
                last = maxOf(last, time)
                count++
                if (!extractor.advance()) break
            }
            val fps = if (count > 1 && last > first) (count - 1) * 1_000_000.0 / (last - first) else 0.0
            return mapOf("audioTracks" to audioTracks, "frameRate" to fps)
        } finally { extractor.release() }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        mediaProbe?.setMethodCallHandler(null)
        mediaProbe = null
        probeWorker?.shutdown()
        probeWorker = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
