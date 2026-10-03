package com.follow.clash

import com.follow.clash.common.ServiceDelegate
import com.follow.clash.common.formatString
import com.follow.clash.common.intent
import com.follow.clash.service.IAckInterface
import com.follow.clash.service.ICallbackInterface
import com.follow.clash.service.IEventInterface
import com.follow.clash.service.IRemoteInterface
import com.follow.clash.service.IResultInterface
import com.follow.clash.service.RemoteService
import com.follow.clash.service.models.NotificationParams
import com.follow.clash.service.models.VpnOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import java.util.concurrent.ConcurrentHashMap

class ActionResponseCollector(
    private val timeoutMillis: Long = ACTION_RESPONSE_TIMEOUT_MILLIS
) {
    private val chunks = mutableListOf<ByteArray>()
    private val completion = CompletableDeferred<Result<String>>()

    val isCompleted: Boolean
        get() = completion.isCompleted

    fun onResult(
        result: ByteArray?,
        isSuccess: Boolean,
        onAck: (() -> Unit)? = null
    ) {
        val finished = synchronized(chunks) {
            chunks.add(result ?: byteArrayOf())
            isSuccess
        }

        onAck?.invoke()

        if (finished) {
            val formatted = synchronized(chunks) {
                chunks.toList().formatString()
            }
            completion.complete(Result.success(formatted))
        }
    }

    suspend fun await(): Result<String> {
        return try {
            withTimeout(timeoutMillis) {
                completion.await()
            }
        } catch (error: TimeoutCancellationException) {
            Result.failure(error)
        }
    }
}

class EventResponseCollector(
    private val onResult: ((result: String?) -> Unit)?
) {
    private val chunksById = ConcurrentHashMap<String, MutableList<ByteArray>>()

    fun onEvent(
        id: String,
        data: ByteArray?,
        isSuccess: Boolean,
        onAck: (() -> Unit)? = null
    ) {
        val chunks = chunksById.compute(id) { _, existingChunks ->
            (existingChunks ?: mutableListOf()).apply {
                add(data ?: byteArrayOf())
            }
        } ?: return

        onAck?.invoke()

        if (isSuccess) {
            onResult?.invoke(synchronized(chunks) { chunks.toList().formatString() })
            chunksById.remove(id, chunks)
        }
    }
}

private const val ACTION_RESPONSE_TIMEOUT_MILLIS = 120_000L

object Service {
    private val delegate by lazy {
        ServiceDelegate<IRemoteInterface>(
            RemoteService::class.intent, ::handleServiceDisconnected
        ) {
            IRemoteInterface.Stub.asInterface(it)
        }
    }

    var onServiceDisconnected: ((String) -> Unit)? = null

    private fun handleServiceDisconnected(message: String) {
        onServiceDisconnected?.let {
            it(message)
        }
    }

    fun bind() {
        delegate.bind()
    }

    fun unbind() {
        delegate.unbind()
    }

    suspend fun invokeAction(data: String): Result<String> {
        val collector = ActionResponseCollector()
        val request = delegate.useService {
            it.invokeAction(
                data, object : ICallbackInterface.Stub() {
                    override fun onResult(
                        result: ByteArray?, isSuccess: Boolean, ack: IAckInterface?
                    ) {
                        collector.onResult(result, isSuccess) { ack?.onAck() }
                    }
                })
        }

        return request.fold(
            onSuccess = { collector.await() },
            onFailure = { Result.failure(it) }
        )
    }

    suspend fun setEventListener(
        cb: ((result: String?) -> Unit)?
    ): Result<Unit> {
        val collector = EventResponseCollector(cb)
        return delegate.useService {
            it.setEventListener(
                when (cb != null) {
                true -> object : IEventInterface.Stub() {
                    override fun onEvent(
                        id: String, data: ByteArray?, isSuccess: Boolean, ack: IAckInterface?
                    ) {
                        collector.onEvent(id, data, isSuccess) { ack?.onAck() }
                    }
                }

                false -> null
            })
        }
    }

    suspend fun updateNotificationParams(
        params: NotificationParams
    ): Result<Unit> {
        return delegate.useService {
            it.updateNotificationParams(params)
        }
    }

    suspend fun setCrashlytics(
        enable: Boolean
    ): Result<Unit> {
        return delegate.useService {
            it.setCrashlytics(enable)
        }
    }

    private suspend fun awaitIResultInterface(
        block: (IResultInterface) -> Unit
    ): Long = suspendCancellableCoroutine { continuation ->
        val callback = object : IResultInterface.Stub() {
            override fun onResult(time: Long) {
                if (continuation.isActive) {
                    continuation.resume(time)
                }
            }
        }

        try {
            block(callback)
        } catch (e: Exception) {
            if (continuation.isActive) {
                continuation.resumeWithException(e)
            }
        }
    }


    suspend fun startService(options: VpnOptions, runTime: Long): Long {
        return delegate.useService {
            awaitIResultInterface { callback ->
                it.startService(options, runTime, callback)
            }
        }.getOrNull() ?: 0L
    }

    suspend fun stopService(): Long {
        return delegate.useService {
            awaitIResultInterface { callback ->
                it.stopService(callback)
            }
        }.getOrNull() ?: 0L
    }

    suspend fun getRunTime(): Long {
        return delegate.useService {
            it.runTime
        }.getOrNull() ?: 0L
    }
}
