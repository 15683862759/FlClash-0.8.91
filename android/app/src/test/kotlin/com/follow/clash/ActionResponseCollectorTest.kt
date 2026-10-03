package com.follow.clash

import com.follow.clash.common.formatString
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ActionResponseCollectorTest {
    @Test
    fun `returns chunks only after the final response`() = runBlocking {
        val collector = ActionResponseCollector(timeoutMillis = 1_000)

        collector.onResult("he".toByteArray(), false)
        assertEquals(false, collector.isCompleted)

        collector.onResult("llo".toByteArray(), true)
        assertEquals(Result.success("hello"), collector.await())
        assertEquals(true, collector.isCompleted)
    }

    @Test
    fun `fails when the final response is late`() = runBlocking {
        val collector = ActionResponseCollector(timeoutMillis = 10)
        collector.onResult("pending".toByteArray(), false)

        val result = collector.await()

        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull() is TimeoutCancellationException)
    }

    @Test
    fun `acks every response chunk`() {
        val collector = ActionResponseCollector(timeoutMillis = 1_000)
        var ackCount = 0
        val ack: () -> Unit = {
            ackCount++
        }

        collector.onResult("a".toByteArray(), false, ack)
        collector.onResult("b".toByteArray(), true, ack)

        assertEquals(2, ackCount)
    }
}
