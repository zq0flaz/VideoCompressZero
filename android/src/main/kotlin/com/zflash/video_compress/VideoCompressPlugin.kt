package com.zflash.video_compress

import android.content.Context
import android.net.Uri
import com.otaliastudios.transcoder.Transcoder
import com.otaliastudios.transcoder.TranscoderListener
import com.otaliastudios.transcoder.source.TrimDataSource
import com.otaliastudios.transcoder.source.UriDataSource
import com.otaliastudios.transcoder.strategy.DefaultAudioStrategy
import com.otaliastudios.transcoder.strategy.DefaultVideoStrategy
import com.otaliastudios.transcoder.strategy.RemoveTrackStrategy
import com.otaliastudios.transcoder.strategy.TrackStrategy
import com.otaliastudios.transcoder.validator.WriteAlwaysValidator
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import com.otaliastudios.transcoder.internal.utils.Logger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.io.File
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors
import java.util.*
import java.util.concurrent.Future

/**
 * VideoCompressPlugin
 */
class VideoCompressPlugin : MethodCallHandler, FlutterPlugin {


    @Volatile private var _context: Context? = null
    @Volatile private var _channel: MethodChannel? = null
    private val TAG = "VideoCompressPlugin"
    var channelName = "video_compress_zero"

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private class Session(val result: MethodChannel.Result, val dest: String) {
        var future: Future<Void>? = null
        var cancellationRequested = false
        var hasProgress = false
    }
    private var active: Session? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val reply = SingleReply(result) { callback -> main.post { callback() } }
        val context = _context
        val channel = _channel
        worker.execute {
            try { handle(call, reply, context, channel) }
            catch (exception: Exception) {
                reply.error("video_compress_zero", "Native operation failed", exception.message)
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result, context: Context?, channel: MethodChannel?) {

        if (context == null || channel == null) {
            result.error("video_compress_zero", "Engine detached", null)
            return
        }

        when (call.method) {
            "getAndroidSdkVersion" -> result.success(Build.VERSION.SDK_INT)
            "getByteThumbnail" -> {
                val path = call.argument<String>("path")
                val quality = call.argument<Int>("quality")!!
                val position = call.argument<Number>("position")!!.toLong()
                require(quality in 1..100 && position >= -1) { "Invalid thumbnail arguments" }
                ThumbnailUtility(channelName).getByteThumbnail(context, path!!, quality, position, result)
            }
            "getFileThumbnail" -> {
                val path = call.argument<String>("path")
                val quality = call.argument<Int>("quality")!!
                val position = call.argument<Number>("position")!!.toLong()
                require(quality in 1..100 && position >= -1) { "Invalid thumbnail arguments" }
                ThumbnailUtility(channelName).getFileThumbnail(context, path!!, quality,
                        position, result)
            }
            "getMediaInfo" -> {
                val path = call.argument<String>("path")
                result.success(Utility(channelName).getMediaInfoJson(context, path!!).toString())
            }
            "deleteAllCache" -> {
                check(active == null) { "Cannot clear cache while compressing" }
                result.success(Utility(channelName).deleteAllCache(context));
            }
            "setLogLevel" -> {
                val logLevel = call.argument<Int>("logLevel")!!
                Logger.setLogLevel(logLevel)
                result.success(true);
            }
            "cancelCompression" -> {
                active?.let { session ->
                    session.cancellationRequested = true
                    // Cancelling a Future before its callable starts suppresses
                    // Transcoder's terminal listener. Wait for proof of execution.
                    if (session.hasProgress) session.future?.cancel(true)
                }
                result.success(null)
            }
            "compressVideo" -> {
                val path = call.argument<String>("path")!!
                val quality = call.argument<Int>("quality")!!
                val deleteOrigin = call.argument<Boolean>("deleteOrigin")!!
                val startTime = call.argument<Int>("startTime")
                val duration = call.argument<Int>("duration")
                val includeAudio = call.argument<Boolean>("includeAudio") ?: true
                val frameRate = if (call.argument<Int>("frameRate")==null) 30 else call.argument<Int>("frameRate")

                check(active == null) { "Already compressing" }
                require(quality in 0..7 && frameRate != null && frameRate > 0) { "Invalid quality or frame rate" }
                require(startTime == null || startTime >= 0) { "Invalid start time" }
                require(duration == null || duration > 0) { "Invalid duration" }
                val tempDir = context.getExternalFilesDir("video_compress_zero") ?: error("External storage unavailable")
                check(tempDir.exists() || tempDir.mkdirs()) { "Cannot create output directory" }
                val destPath = File(tempDir, UUID.randomUUID().toString() + ".mp4").absolutePath

                var videoTrackStrategy: TrackStrategy = DefaultVideoStrategy.atMost(340).build();
                val audioTrackStrategy: TrackStrategy

                when (quality) {

                    0 -> {
                      videoTrackStrategy = DefaultVideoStrategy.atMost(720).frameRate(frameRate).build()
                    }

                    1 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(360).frameRate(frameRate).build()
                    }
                    2 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(640).frameRate(frameRate).build()
                    }
                    3 -> {

                        videoTrackStrategy = DefaultVideoStrategy.Builder()
                                .keyFrameInterval(3f)
                                .bitRate(1280 * 720 * 4.toLong())
                                .frameRate(frameRate) // will be capped to the input frameRate
                                .build()
                    }
                    4 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(480, 640).frameRate(frameRate).build()
                    }
                    5 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(540, 960).frameRate(frameRate).build()
                    }
                    6 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(720, 1280).frameRate(frameRate).build()
                    }
                    7 -> {
                        videoTrackStrategy = DefaultVideoStrategy.atMost(1080, 1920).frameRate(frameRate).build()
                    }                    
                }

                audioTrackStrategy = if (includeAudio) {
                    val sampleRate = DefaultAudioStrategy.SAMPLE_RATE_AS_INPUT
                    val channels = DefaultAudioStrategy.CHANNELS_AS_INPUT

                    DefaultAudioStrategy.builder()
                        .channels(channels)
                        .sampleRate(sampleRate)
                        .build()
                } else {
                    RemoveTrackStrategy()
                }

                val dataSource = if (startTime != null || duration != null){
                    val source = UriDataSource(context, sourceUri(path))
                    val length = Utility(channelName).getMediaInfoJson(context, path).getLong("duration") * 1000L
                    val offsets = NativeRules.trimOffsets(length, startTime, duration)
                    TrimDataSource(source, offsets.first, offsets.second)
                }else{
                    UriDataSource(context, sourceUri(path))
                }


                val session = Session(result, destPath)
                active = session
                try {
                    session.future = Transcoder.into(destPath)
                        // Always materialize an output, including pass-through inputs
                        // and trims whose codecs already match the target strategy.
                        .setValidator(WriteAlwaysValidator())
                        .addDataSource(dataSource)
                        .setAudioTrackStrategy(audioTrackStrategy)
                        .setVideoTrackStrategy(videoTrackStrategy)
                        .setListener(object : TranscoderListener {
                            override fun onTranscodeProgress(progress: Double) {
                                worker.execute {
                                    if (active === session) {
                                        session.hasProgress = true
                                        if (session.cancellationRequested) session.future?.cancel(true)
                                        else main.post {
                                            if (_channel === channel) channel.invokeMethod("updateProgress", progress * 100)
                                        }
                                    }
                                }
                            }
                            override fun onTranscodeCompleted(successCode: Int) {
                                worker.execute {
                                    if (active !== session) { File(destPath).delete(); return@execute }
                                    active = null
                                    if (session.cancellationRequested) {
                                        File(destPath).delete()
                                        result.success(null)
                                        return@execute
                                    }
                                    try {
                                        val json = Utility(channelName).getMediaInfoJson(context, destPath)
                                        json.put("isCancel", false)
                                        if (deleteOrigin && sourceUri(path).scheme == "file") File(sourceUri(path).path!!).delete()
                                        main.post { if (_channel === channel) channel.invokeMethod("updateProgress", 100.0) }
                                        result.success(json.toString())
                                    } catch (exception: Exception) {
                                        File(destPath).delete()
                                        result.error("video_compress_zero", "Output metadata failed", exception.message)
                                    }
                                }
                            }
                            override fun onTranscodeCanceled() {
                                worker.execute {
                                    File(destPath).delete()
                                    if (active === session) { active = null; result.success(null) }
                                }
                            }
                            override fun onTranscodeFailed(exception: Throwable) {
                                worker.execute {
                                    File(destPath).delete()
                                    if (active === session) {
                                        active = null
                                        if (session.cancellationRequested) result.success(null)
                                        else result.error("video_compress_transcode", "Failed to transcode video", exception.message)
                                    }
                                }
                            }
                        }).transcode()
                } catch (exception: Exception) {
                    active = null
                    File(destPath).delete()
                    throw exception
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        init(binding.applicationContext, binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        worker.execute {
            active?.let { session ->
                session.cancellationRequested = true
                if (session.hasProgress) session.future?.cancel(true)
                session.result.error("video_compress_zero", "Engine detached", null)
            }
            // Keep ownership until the listener confirms the writer stopped.
        }
        _channel?.setMethodCallHandler(null)
        _context = null
        _channel = null
    }

    private fun init(context: Context, messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, channelName)
        channel.setMethodCallHandler(this)
        _context = context
        _channel = channel
    }

    private fun sourceUri(path: String): Uri {
        val uri = Uri.parse(path)
        return if (uri.scheme.isNullOrEmpty()) Uri.fromFile(File(path)) else uri
    }

    companion object {
        private const val TAG = "video_compress_zero"
    }

}
