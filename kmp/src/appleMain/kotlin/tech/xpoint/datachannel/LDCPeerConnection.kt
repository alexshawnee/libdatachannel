package tech.xpoint.datachannel

import kotlinx.cinterop.ByteVar
import kotlinx.cinterop.COpaquePointer
import kotlinx.cinterop.CPointer
import kotlinx.cinterop.alloc
import kotlinx.cinterop.allocArray
import kotlinx.cinterop.allocArrayOf
import kotlinx.cinterop.cstr
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.ptr
import kotlinx.cinterop.staticCFunction
import kotlinx.cinterop.toKString
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.channels.Channel
import libdatachannel.RTC_ERR_SUCCESS
import libdatachannel.RTC_GATHERING_COMPLETE
import libdatachannel.RTC_LOG_DEBUG
import libdatachannel.rtcCleanup
import libdatachannel.rtcInitLogger
import libdatachannel.rtcClose
import libdatachannel.rtcClosePeerConnection
import libdatachannel.rtcConfiguration
import libdatachannel.rtcCreatePeerConnection
import libdatachannel.rtcDelete
import libdatachannel.rtcDeletePeerConnection
import libdatachannel.rtcGetLocalDescription
import libdatachannel.rtcPreload
import libdatachannel.rtcSendMessage
import libdatachannel.rtcSetClosedCallback
import libdatachannel.rtcSetDataChannelCallback
import libdatachannel.rtcSetGatheringStateChangeCallback
import libdatachannel.rtcSetLocalDescriptionCallback
import libdatachannel.rtcSetMessageCallback
import libdatachannel.rtcSetOpenCallback
import libdatachannel.rtcSetRemoteDescription

class LDCPeerConnection : AutoCloseable {

    internal class State(
        val gatheringComplete: CompletableDeferred<Unit> = CompletableDeferred(),
        val dataChannelReady: CompletableDeferred<Int> = CompletableDeferred(),
        val incoming: Channel<String> = Channel(Channel.UNLIMITED)
    )

    companion object {
        private val peers = mutableMapOf<Int, State>()
        private var initialized = false
        var debug = false

        var defaultIceServers = listOf(
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302"
        )

        fun init() {
            if (initialized) return
            initialized = true
            if (debug) {
                rtcInitLogger(
                    RTC_LOG_DEBUG,
                    staticCFunction { _: UInt, message: CPointer<ByteVar>? ->
                        message?.toKString()?.let { println("[libdc] $it") }
                        Unit
                    }
                )
            }
            rtcPreload()
        }

        fun cleanup() {
            if (!initialized) return
            initialized = false
            rtcCleanup()
        }

        private fun register(id: Int, state: State) {
            peers[id] = state
        }

        private fun unregister(id: Int) {
            peers.remove(id)
        }

        internal operator fun get(id: Int) = peers[id]

        val onGathering = staticCFunction { id: Int, gathering: UInt, _: COpaquePointer? ->
            if (gathering == RTC_GATHERING_COMPLETE) {
                LDCPeerConnection[id]?.gatheringComplete?.complete(Unit)
            }
        }

        val onLocalDescription =
            staticCFunction { _: Int, _: CPointer<ByteVar>?, _: CPointer<ByteVar>?, _: COpaquePointer? -> }

        val onDataChannel = staticCFunction { pcId: Int, dcId: Int, _: COpaquePointer? ->
            val s = LDCPeerConnection[pcId] ?: return@staticCFunction
            register(dcId, s)
            rtcSetOpenCallback(dcId, onOpen)
            rtcSetMessageCallback(dcId, onMessage)
            rtcSetClosedCallback(dcId, onClosed)
        }

        val onOpen = staticCFunction { id: Int, _: COpaquePointer? ->
            LDCPeerConnection[id]?.dataChannelReady?.complete(id)
            Unit
        }

        val onMessage = staticCFunction { id: Int, message: CPointer<ByteVar>?, size: Int, _: COpaquePointer? ->
            if (message != null && size != 0) {
                LDCPeerConnection[id]?.incoming?.trySend(message.toKString())
            }
        }

        val onClosed = staticCFunction { id: Int, _: COpaquePointer? ->
            LDCPeerConnection[id]?.incoming?.close()
            Unit
        }

        private fun check(result: Int, op: String) {
            if (result < RTC_ERR_SUCCESS) {
                error("$op failed with error code $result")
            }
        }
    }

    private var pc: Int = -1
    private var dc: Int = -1
    private val state = State()

    val incoming: Channel<String> get() = state.incoming

    fun open(remoteSdp: String, iceServers: List<String> = defaultIceServers) {
        memScoped {
            val cStrings = iceServers.map { it.cstr.ptr }
            val config = alloc<rtcConfiguration>()
            config.iceServers = allocArrayOf(*cStrings.toTypedArray())
            config.iceServersCount = iceServers.size
            pc = rtcCreatePeerConnection(config.ptr)
        }
        check(pc, "rtcCreatePeerConnection")

        register(pc, state)

        rtcSetGatheringStateChangeCallback(pc, onGathering)
        rtcSetLocalDescriptionCallback(pc, onLocalDescription)
        rtcSetDataChannelCallback(pc, onDataChannel)

        check(rtcSetRemoteDescription(pc, remoteSdp, "offer"), "rtcSetRemoteDescription")
    }

    suspend fun awaitLocalDescription(): String {
        state.gatheringComplete.await()
        memScoped {
            val buf = allocArray<ByteVar>(4096)
            val len = rtcGetLocalDescription(pc, buf, 4096)
            check(len, "rtcGetLocalDescription")
            return buf.toKString()
        }
    }

    suspend fun awaitDataChannel() {
        dc = state.dataChannelReady.await()
    }

    fun send(data: String) {
        check(rtcSendMessage(dc, data, -1), "rtcSendMessage")
    }

    override fun close() {
        state.incoming.close()
        if (dc >= 0) {
            unregister(dc)
            rtcClose(dc)
            rtcDelete(dc)
        }
        if (pc >= 0) {
            unregister(pc)
            rtcClosePeerConnection(pc)
            rtcDeletePeerConnection(pc)
        }
    }
}
