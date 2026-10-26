package com.fuzzzycore.ink.anywhere

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/** What Dart answered a call on `com.fuzzzycore.ink/anywhere`. */
sealed interface ChannelAnswer {
    data class Ok(val values: Map<String, Any?>) : ChannelAnswer {
        fun string(key: String): String? = values[key] as? String
        fun flag(key: String): Boolean = values[key] == true
    }

    /** A refusal: its code (CHANNEL.md section 4) and, for the password waits, the seconds left. */
    data class Refused(val code: String, val waitSeconds: Int = 0) : ChannelAnswer

    /** No handler: the build has no feature, or Dart has not started yet. */
    data object Missing : ChannelAnswer
}

/** What Dart tells the native side (CHANNEL.md section 3). */
sealed interface AnywhereEvent {
    data class LockChanged(val isUnlocked: Boolean) : AnywhereEvent
    data class SettingsChanged(val isOn: Boolean) : AnywhereEvent
    data object ShownClosed : AnywhereEvent
}

/**
 * The native end of `com.fuzzzycore.ink/anywhere`, contract version 1
 * (documents/fuzz_anywhere/CHANNEL.md). Native code only asks; Dart locks,
 * opens and keeps. Nothing here logs, stores or copies what it carries.
 */
class AnywhereChannel(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, NAME)

    /** Calls [method] on the platform thread and waits for Dart's answer. */
    suspend fun call(method: String, arguments: Map<String, Any?> = emptyMap()): ChannelAnswer =
        suspendCancellableCoroutine { continuation ->
            channel.invokeMethod(method, arguments + ("v" to VERSION), object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val values = (result as? Map<*, *>).orEmpty()
                        .mapKeys { (key, _) -> key.toString() }
                    continuation.resume(ChannelAnswer.Ok(values))
                }

                override fun error(code: String, message: String?, details: Any?) {
                    val wait = ((details as? Map<*, *>)?.get("waitSeconds") as? Number)?.toInt() ?: 0
                    continuation.resume(ChannelAnswer.Refused(code, wait))
                }

                override fun notImplemented() {
                    continuation.resume(ChannelAnswer.Missing)
                }
            })
        }

    /** Fire and forget: for the sheet going away ([relock]), when nobody waits. */
    fun send(method: String) {
        channel.invokeMethod(method, mapOf("v" to VERSION))
    }

    companion object {
        const val NAME = "com.fuzzzycore.ink/anywhere"
        private const val VERSION = 1

        private val eventFlow = MutableSharedFlow<AnywhereEvent>(extraBufferCapacity = 8)

        /** Dart's events, for whichever sheet is open. */
        val events: SharedFlow<AnywhereEvent> = eventFlow.asSharedFlow()

        /**
         * Takes Dart's events on [messenger]: the switch turns the entry
         * points on and off ([AnywhereSwitch]); the rest goes to [events].
         */
        fun listen(messenger: BinaryMessenger, context: Context) {
            val app = context.applicationContext
            MethodChannel(messenger, NAME).setMethodCallHandler { call, result ->
                when (call.method) {
                    "settingsChanged" -> {
                        val isOn = call.argument<Boolean>("enabled") == true
                        AnywhereSwitch.apply(app, isOn)
                        eventFlow.tryEmit(AnywhereEvent.SettingsChanged(isOn))
                        result.success(null)
                    }
                    "lockChanged" -> {
                        eventFlow.tryEmit(AnywhereEvent.LockChanged(call.argument<Boolean>("unlocked") == true))
                        result.success(null)
                    }
                    "shownClosed" -> {
                        eventFlow.tryEmit(AnywhereEvent.ShownClosed)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
