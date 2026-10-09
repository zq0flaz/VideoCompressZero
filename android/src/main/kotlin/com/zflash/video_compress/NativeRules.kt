package com.zflash.video_compress

import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

internal object NativeRules {
    fun thumbnailMicros(milliseconds: Long): Long {
        require(milliseconds >= -1) { "Invalid thumbnail position" }
        return if (milliseconds == -1L) -1 else Math.multiplyExact(milliseconds, 1000L)
    }

    fun trimOffsets(lengthMicros: Long, startSeconds: Int?, durationSeconds: Int?): Pair<Long, Long> {
        require(startSeconds == null || startSeconds >= 0)
        require(durationSeconds == null || durationSeconds > 0)
        val start = (startSeconds ?: 0).toLong() * 1_000_000L
        require(start < lengthMicros) { "Start time exceeds video duration" }
        val selected = minOf(durationSeconds?.toLong()?.times(1_000_000L) ?: (lengthMicros - start), lengthMicros - start)
        return start to (lengthMicros - start - selected)
    }
}

internal class SingleReply(private val delegate: MethodChannel.Result,
                           private val dispatch: (() -> Unit) -> Unit) : MethodChannel.Result {
    private val replied = AtomicBoolean(false)
    override fun success(value: Any?) {
        if (replied.compareAndSet(false, true)) dispatch { delegate.success(value) }
    }
    override fun error(code: String, message: String?, details: Any?) {
        if (replied.compareAndSet(false, true)) dispatch { delegate.error(code, message, details) }
    }
    override fun notImplemented() {
        if (replied.compareAndSet(false, true)) dispatch { delegate.notImplemented() }
    }
}
