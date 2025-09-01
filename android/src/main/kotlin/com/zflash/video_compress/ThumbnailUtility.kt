package com.zflash.video_compress

import android.content.Context
import android.graphics.Bitmap
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException

class ThumbnailUtility(channelName: String) {
    private val utility = Utility(channelName)

    fun getByteThumbnail(context: Context, path: String, quality: Int, position: Long, result: MethodChannel.Result) {
        val bmp = utility.getBitmap(context, path, position, result)
        if (bmp.width == 1 && bmp.height == 1) {
            result.error("video_compress_thumbnail", "Failed to extract thumbnail", null)
            return
        }
        val stream = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.JPEG, quality, stream)
        val byteArray = stream.toByteArray()
        bmp.recycle()
        result.success(byteArray)
    }

    fun getFileThumbnail(context: Context, path: String, quality: Int, position: Long,
                             result: MethodChannel.Result) {
        val bmp = utility.getBitmap(context, path, position, result)
        if (bmp.width == 1 && bmp.height == 1) {
            result.error("video_compress_thumbnail", "Failed to extract thumbnail", null)
            return
        }
        val dir = context.getExternalFilesDir("video_compress")

        if (dir != null && !dir.exists()) dir.mkdirs()

        val name = File(path).nameWithoutExtension + ".jpg"
        val file = File(dir, name)
        utility.deleteFile(file)

        val stream = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.JPEG, quality, stream)
        val byteArray = stream.toByteArray()

        try {
            file.createNewFile()
            file.writeBytes(byteArray)
        } catch (e: IOException) {
            e.printStackTrace()
        }

        bmp.recycle()

        result.success(file.absolutePath)
    }
}
