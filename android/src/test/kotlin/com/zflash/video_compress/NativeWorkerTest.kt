package com.zflash.video_compress

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CompletableFuture
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class NativeWorkerTest {
    private fun run(worker: NativeWorker, action: () -> Unit) {
        val done = CompletableFuture<Unit>()
        assertTrue(worker.execute {
            try { action(); done.complete(Unit) }
            catch (error: Throwable) { done.completeExceptionally(error) }
        })
        done.get(5, TimeUnit.SECONDS)
    }

    @Test fun idleDetachTerminatesThreadAndRejectsLateCallbacks() {
        val worker = NativeWorker()
        run(worker) { worker.detach() }
        assertTrue(worker.awaitTermination(5, TimeUnit.SECONDS))
        assertFalse(worker.execute { fail("Late callback executed") })
    }

    @Test fun detachedWriterKeepsWorkerUntilTerminalCleanup() {
        val worker = NativeWorker()
        try {
            run(worker) {
                worker.retainOperation()
                worker.detach()
                assertFalse(worker.isShutdown)
            }
            // The terminal callback is still accepted after detach, including
            // cancellation requested before the first progress notification.
            run(worker) { worker.releaseOperation() }
            assertTrue(worker.awaitTermination(5, TimeUnit.SECONDS))
        } finally { if (!worker.isShutdown) run(worker) { worker.releaseOperation() } }
    }

    @Test fun shutdownDrainsAlreadyQueuedCallbacks() {
        val worker = NativeWorker()
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val drained = CountDownLatch(1)
        assertTrue(worker.execute {
            entered.countDown()
            release.await(5, TimeUnit.SECONDS)
            worker.detach()
        })
        try {
            assertTrue(entered.await(5, TimeUnit.SECONDS))
            assertTrue(worker.execute { drained.countDown() })
        } finally { release.countDown() }
        assertTrue(drained.await(5, TimeUnit.SECONDS))
        assertTrue(worker.awaitTermination(5, TimeUnit.SECONDS))
    }

    @Test fun newEngineDoesNotReuseDetachedWorker() {
        val old = NativeWorker()
        val replacement = NativeWorker()
        try {
            run(old) { old.retainOperation(); old.detach() }
            run(replacement) { replacement.retainOperation() }
            run(old) { old.releaseOperation() }
            assertTrue(old.awaitTermination(5, TimeUnit.SECONDS))
            assertFalse(replacement.isShutdown)
            run(replacement) { replacement.releaseOperation(); replacement.detach() }
            assertTrue(replacement.awaitTermination(5, TimeUnit.SECONDS))
        } finally {
            if (!old.isShutdown) run(old) { old.releaseOperation() }
            if (!replacement.isShutdown) run(replacement) {
                replacement.releaseOperation(); replacement.detach()
            }
        }
    }
}
