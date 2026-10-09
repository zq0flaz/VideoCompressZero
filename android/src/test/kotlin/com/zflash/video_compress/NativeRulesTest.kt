package com.zflash.video_compress

import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.*
import org.junit.Test

class NativeRulesTest {
    @Test fun thumbnailTimeUsesMilliseconds() {
        assertEquals(5_000_000L, NativeRules.thumbnailMicros(5000))
        assertEquals(-1L, NativeRules.thumbnailMicros(-1))
    }
    @Test fun durationIsSelectedLengthRatherThanEndTrim() {
        assertEquals(2_000_000L to 5_000_000L, NativeRules.trimOffsets(10_000_000, 2, 3))
        assertEquals(2_000_000L to 0L, NativeRules.trimOffsets(10_000_000, 2, null))
        assertEquals(0L to 7_000_000L, NativeRules.trimOffsets(10_000_000, null, 3))
        assertEquals(8_000_000L to 0L, NativeRules.trimOffsets(10_000_000, 8, 20))
    }
    @Test fun longVideoDoesNotOverflowIntArithmetic() {
        assertEquals(3_600_000_000L to 900_000_000L, NativeRules.trimOffsets(7_200_000_000, 3600, 2700))
    }
    @Test(expected = IllegalArgumentException::class) fun rejectEmptyRange() {
        NativeRules.trimOffsets(10_000_000, 10, 1)
    }
    @Test fun onlyFirstResponseIsDispatched() {
        val replies = mutableListOf<Any?>()
        val queued = mutableListOf<() -> Unit>()
        val delegate = object : MethodChannel.Result {
            override fun success(value: Any?) { replies.add(value) }
            override fun error(code: String, message: String?, details: Any?) { replies.add(code) }
            override fun notImplemented() { replies.add("missing") }
        }
        val reply = SingleReply(delegate) { queued.add(it) }
        reply.error("failed", null, null)
        reply.success(true)
        reply.notImplemented()
        assertEquals(1, queued.size)
        queued.forEach { it() }
        assertEquals(listOf("failed"), replies)
    }
}
