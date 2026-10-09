package com.zflash.video_compress

import android.content.Context
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import org.json.JSONObject
import java.io.File

class Utility(private val channelName: String) {

    fun isLandscapeImage(orientation: Int) = orientation == 90 || orientation == 270 //orientation != 90 && orientation != 270

    private fun buildUri(path: String): Uri {
        val parsed = Uri.parse(path)
        return if (parsed.scheme.isNullOrEmpty()) Uri.fromFile(File(path)) else parsed
    }

    @Throws(IllegalArgumentException::class, SecurityException::class, RuntimeException::class)
    private fun setRetrieverDataSource(context: Context, retriever: MediaMetadataRetriever, path: String) {
        val uri = buildUri(path)
        try {
            when (uri.scheme) {
                "content", "android.resource", "file" -> retriever.setDataSource(context, uri)
                else -> retriever.setDataSource(path)
            }
        } catch (se: SecurityException) {
            // Fallback: use a FileDescriptor for content Uris if readable
            if ("content" == uri.scheme) {
                context.contentResolver.openAssetFileDescriptor(uri, "r")?.use { afd ->
                    retriever.setDataSource(afd.fileDescriptor)
                    return
                }
            }
            throw se
        }
    }

    fun deleteFile(file: File) {
        if (file.exists()) {
            file.delete()
        }
    }

    fun timeStrToTimestamp(time: String): Long {
        val parts = time.split(":")
        val hour = parts.getOrNull(0)?.toIntOrNull() ?: 0
        val min = parts.getOrNull(1)?.toIntOrNull() ?: 0
        val secParts = parts.getOrNull(2)?.split(".") ?: listOf("0")
        val sec = secParts.getOrNull(0)?.toIntOrNull() ?: 0
        val mSec = secParts.getOrNull(1)?.toIntOrNull() ?: 0

        return ((hour * 3600 + min * 60 + sec) * 1000 + mSec).toLong()
    }

    fun getMediaInfoJson(context: Context, path: String): JSONObject {
        val uri = buildUri(path)
        val retriever = MediaMetadataRetriever()

        try {
            setRetrieverDataSource(context, retriever, path)

            val durationStr =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
            val title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: ""
            val author = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_AUTHOR) ?: ""
            val widthStr =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val heightStr =
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val duration = durationStr?.toLongOrNull() ?: 0L
            var width = widthStr?.toLongOrNull() ?: 0L
            var height = heightStr?.toLongOrNull() ?: 0L
            require(width > 0 && height > 0 && duration > 0) { "Input has no valid video track" }
            val filesize = if (uri.scheme == "content") {
                context.contentResolver.openAssetFileDescriptor(uri, "r")?.use { it.length } ?: -1L
            } else if (uri.scheme == "file") {
                File(uri.path!!).length()
            } else { -1L }
            val orientation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            } else {
                null
            }
            val ori = orientation?.toIntOrNull()
            if (ori != null && isLandscapeImage(ori)) {
                val tmp = width
                width = height
                height = tmp
            }


            val json = JSONObject()

            json.put("path", path)
            json.put("title", title)
            json.put("author", author)
            json.put("width", width)
            json.put("height", height)
            json.put("duration", duration)
            json.put("filesize", filesize)
            if (ori != null) {
                json.put("orientation", ori)
            }

            return json
        } finally {
            try {
                retriever.release()
            } catch (_: RuntimeException) { /* ignore */ }
        }
    }

    fun getBitmap(context: Context, path: String, position: Long): Bitmap {
        var bitmap: Bitmap? = null
        val retriever = MediaMetadataRetriever()

        try {
            setRetrieverDataSource(context, retriever, path)
            bitmap = retriever.getFrameAtTime(NativeRules.thumbnailMicros(position), MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
        } finally {
            try {
                retriever.release()
            } catch (ex: RuntimeException) {
                // Ignore failures while cleaning up.
            }
        }

        requireNotNull(bitmap) { "No frame found in video" }

        val width = bitmap.width
        val height = bitmap.height
        val max = Math.max(width, height)
        if (max > 512) {
            val scale = 512f / max
            val w = Math.max(1, Math.round(scale * width))
            val h = Math.max(1, Math.round(scale * height))
            val scaled = Bitmap.createScaledBitmap(bitmap, w, h, true)
            if (scaled != bitmap) {
                bitmap.recycle()
            }
            bitmap = scaled
            
        }

        return bitmap
    }

    fun getFileNameWithGifExtension(path: String): String {
        val file = File(path)
        var fileName = ""
        val gifSuffix = "gif"
        val dotGifSuffix = ".$gifSuffix"

        if (file.exists()) {
            val name = file.name
            fileName = name.replaceAfterLast(".", gifSuffix)

            if (!fileName.endsWith(dotGifSuffix)) {
                fileName += dotGifSuffix
            }
        }
        return fileName
    }

    fun deleteAllCache(context: Context): Boolean {
        return listOf("video_compress_zero", "video_compress").map { name ->
            val dir = context.getExternalFilesDir(name)
            dir != null && (!dir.exists() || dir.deleteRecursively())
        }.all { it }
    }
}
