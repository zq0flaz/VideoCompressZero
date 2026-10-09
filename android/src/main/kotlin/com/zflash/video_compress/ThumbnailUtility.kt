package com.zflash.video_compress

import android.content.Context
import android.graphics.Bitmap
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.UUID

class ThumbnailUtility(channelName: String) {
    private val utility = Utility(channelName)

    fun getByteThumbnail(context: Context, path: String, quality: Int, position: Long, result: MethodChannel.Result) {
        result.success(thumbnail(context, path, quality, position))
    }

    private fun thumbnail(context: Context, path: String, quality: Int, position: Long): ByteArray {
        val bitmap = utility.getBitmap(context, path, position)
        try {
            return ByteArrayOutputStream().use { stream ->
                check(bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)) { "JPEG encoding failed" }
                stream.toByteArray()
            }
        } finally {
            bitmap.recycle()
        }
    }

    fun getFileThumbnail(context: Context, path: String, quality: Int, position: Long, result: MethodChannel.Result) {
        val bytes = thumbnail(context, path, quality, position)
        val dir = context.getExternalFilesDir("video_compress_zero") ?: throw IOException("External storage unavailable")
        check(dir.exists() || dir.mkdirs()) { "Cannot create thumbnail directory" }
        val file = File(dir, UUID.randomUUID().toString() + ".jpg")
        try {
            file.writeBytes(bytes)
        } catch (exception: IOException) {
            file.delete()
            throw exception
        }
        result.success(file.absolutePath)
    }
}
