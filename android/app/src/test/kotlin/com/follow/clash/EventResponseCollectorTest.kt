package com.follow.clash

import com.follow.clash.common.formatString
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class EventResponseCollectorTest {
    @Test
    fun `stores event chunk before acking it`() {
        val results = mutableListOf<String>()
        val collector = EventResponseCollector { result -> results.add(result.orEmpty()) }
        val id = "event"
        val ack: () -> Unit = {
            collector.onEvent(id, "llo".toByteArray(), true)
        }

        collector.onEvent(id, "he".toByteArray(), false, ack)

        assertEquals(listOf("hello"), results)
    }

    @Test
    fun `keeps chunks from concurrent event ids separate`() {
        val results = mutableSetOf<String>()
        val collector = EventResponseCollector { result -> synchronized(results) { results.add(result.orEmpty()) } }
        val iterations = 100
        val started = CountDownLatch(1)
        val finished = CountDownLatch(2)
        val executor = Executors.newFixedThreadPool(2)

        fun receive(id: String, prefix: String) {
            started.await()
            repeat(iterations) { index ->
                val text = "$prefix$index"
                collector.onEvent(id, text.toByteArray(), true)
            }
            finished.countDown()
        }

        executor.execute { receive("first", "first-") }
        executor.execute { receive("second", "second-") }
        started.countDown()
        assertEquals(true, finished.await(5, TimeUnit.SECONDS))
        executor.shutdown()
        assertEquals(true, executor.awaitTermination(5, TimeUnit.SECONDS))

        assertEquals(
            (0 until iterations).map { index -> "first-$index" }.toSet() +
                (0 until iterations).map { index -> "second-$index" }.toSet(),
            results,
        )
    }
}
