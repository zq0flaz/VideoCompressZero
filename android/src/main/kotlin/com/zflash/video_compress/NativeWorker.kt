package com.zflash.video_compress

import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** One serial worker per engine attachment. Lifecycle methods run on this worker. */
internal class NativeWorker {
    private val executor = Executors.newSingleThreadExecutor()
    private val submissionLock = Any()
    private var detached = false
    private var operations = 0

    val isShutdown: Boolean get() = executor.isShutdown

    // Submission and shutdown share a lock: a late native callback cannot race
    // shutdown into RejectedExecutionException. Queued cleanup still drains.
    fun execute(action: () -> Unit): Boolean = synchronized(submissionLock) {
        if (executor.isShutdown) false
        else {
            executor.execute { action() }
            true
        }
    }

    fun retainOperation() {
        check(!detached) { "Engine detached" }
        operations++
    }

    fun releaseOperation() {
        check(operations > 0) { "No active native operation" }
        operations--
        shutdownIfIdle()
    }

    fun detach() {
        detached = true
        shutdownIfIdle()
    }

    private fun shutdownIfIdle() {
        if (detached && operations == 0) synchronized(submissionLock) {
            executor.shutdown()
        }
    }

    fun awaitTermination(timeout: Long, unit: TimeUnit): Boolean =
        executor.awaitTermination(timeout, unit)
}
