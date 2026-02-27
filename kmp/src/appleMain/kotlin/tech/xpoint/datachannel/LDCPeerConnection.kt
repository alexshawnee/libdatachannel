package tech.xpoint.datachannel

import kotlinx.cinterop.ByteVar
import kotlinx.cinterop.COpaquePointer
import kotlinx.cinterop.CPointer
import kotlinx.cinterop.StableRef
import kotlinx.cinterop.alloc
import kotlinx.cinterop.allocArray
import kotlinx.cinterop.allocArrayOf
import kotlinx.cinterop.asStableRef
import kotlinx.cinterop.cstr
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.ptr
import kotlinx.cinterop.staticCFunction
import kotlinx.cinterop.readBytes
import kotlinx.cinterop.toKString
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.channels.Channel
import libdatachannel.RTC_ERR_SUCCESS
import libdatachannel.RTC_GATHERING_COMPLETE
import libdatachannel.RTC_LOG_DEBUG
import libdatachannel.rtcCleanup
import libdatachannel.rtcClose
import libdatachannel.rtcClosePeerConnection
import libdatachannel.rtcConfiguration
import libdatachannel.rtcCreatePeerConnection
import libdatachannel.rtcDelete
import libdatachannel.rtcDeletePeerConnection
import libdatachannel.rtcGetLocalDescription
import libdatachannel.rtcInitLogger
import libdatachannel.rtcPreload
import libdatachannel.rtcSendMessage
import libdatachannel.rtcSetClosedCallback
import libdatachannel.rtcSetDataChannelCallback
import libdatachannel.rtcSetGatheringStateChangeCallback
import libdatachannel.rtcSetMessageCallback
import libdatachannel.rtcSetOpenCallback
import libdatachannel.rtcCreateDataChannel
import libdatachannel.rtcSetRemoteDescription
import libdatachannel.rtcSetUserPointer

class LDCPeerConnection(
    private val iceServers: List<String> = DEFAULT_ICE_SERVERS
) : PeerConnection {

    init {
        rtcPreload()
    }

    internal class State(
        val gatheringComplete: CompletableDeferred<Unit> = CompletableDeferred(),
        val dataChannelReady: CompletableDeferred<Int> = CompletableDeferred(),
        val incoming: Channel<DCMessage> = Channel(Channel.UNLIMITED)
    )

    companion object {
        val DEFAULT_ICE_SERVERS = listOf(
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302"
        )

        fun enableLogging() {
            rtcInitLogger(
                RTC_LOG_DEBUG,
                staticCFunction { _: UInt, message: CPointer<ByteVar>? ->
                    message?.toKString()?.let { println("[libdc] $it") }
                    Unit
                }
            )
        }

        fun cleanup() {
            rtcCleanup()
        }

        val onGathering = staticCFunction { _: Int, gathering: UInt, ptr: COpaquePointer? ->
            if (gathering == RTC_GATHERING_COMPLETE) {
                ptr?.asStableRef<State>()?.get()?.gatheringComplete?.complete(Unit)
            }
        }

        val onDataChannel = staticCFunction { _: Int, dcId: Int, ptr: COpaquePointer? ->
            if (ptr == null) return@staticCFunction
            rtcSetUserPointer(dcId, ptr)
            rtcSetOpenCallback(dcId, onOpen)
            rtcSetMessageCallback(dcId, onMessage)
            rtcSetClosedCallback(dcId, onClosed)
        }

        val onOpen = staticCFunction { id: Int, ptr: COpaquePointer? ->
            ptr?.asStableRef<State>()?.get()?.dataChannelReady?.complete(id)
            Unit
        }

        val onMessage = staticCFunction { _: Int, message: CPointer<ByteVar>?, size: Int, ptr: COpaquePointer? ->
            if (message == null) return@staticCFunction
            val state = ptr?.asStableRef<State>()?.get() ?: return@staticCFunction
            val msg = if (size < 0) {
                DCMessage.Text(message.toKString())
            } else {
                DCMessage.Binary(message.readBytes(size))
            }
            state.incoming.trySend(msg)
        }

        val onClosed = staticCFunction { _: Int, ptr: COpaquePointer? ->
            ptr?.asStableRef<State>()?.get()?.incoming?.close()
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
    private val stableRef = StableRef.create(state)

    override val incoming: Channel<DCMessage> get() = state.incoming

    private fun createPeerConnection() {
        require(pc < 0) { "PeerConnection already created, use a new LDCPeerConnection instance" }

        memScoped {
            val cStrings = iceServers.map { it.cstr.ptr }
            val config = alloc<rtcConfiguration>()
            config.iceServers = allocArrayOf(*cStrings.toTypedArray())
            config.iceServersCount = iceServers.size
            pc = rtcCreatePeerConnection(config.ptr)
        }
        check(pc, "rtcCreatePeerConnection")

        rtcSetUserPointer(pc, stableRef.asCPointer())
        rtcSetGatheringStateChangeCallback(pc, onGathering)
    }

    override suspend fun offer(label: String): String {
        createPeerConnection()

        dc = rtcCreateDataChannel(pc, label)
        check(dc, "rtcCreateDataChannel")

        rtcSetUserPointer(dc, stableRef.asCPointer())
        rtcSetOpenCallback(dc, onOpen)
        rtcSetMessageCallback(dc, onMessage)
        rtcSetClosedCallback(dc, onClosed)

        return awaitLocalDescription()
    }

    override suspend fun acceptOffer(offerSdp: String): String {
        createPeerConnection()
        rtcSetDataChannelCallback(pc, onDataChannel)
        check(rtcSetRemoteDescription(pc, offerSdp, "offer"), "rtcSetRemoteDescription")
        return awaitLocalDescription()
    }

    override fun acceptAnswer(answerSdp: String) {
        check(rtcSetRemoteDescription(pc, answerSdp, "answer"), "rtcSetRemoteDescription")
    }

    override suspend fun awaitDataChannel() {
        dc = state.dataChannelReady.await()
    }

    private suspend fun awaitLocalDescription(): String {
        state.gatheringComplete.await()
        val size = rtcGetLocalDescription(pc, null, 0)
        check(size, "rtcGetLocalDescription(size)")
        memScoped {
            val buf = allocArray<ByteVar>(size)
            check(rtcGetLocalDescription(pc, buf, size), "rtcGetLocalDescription")
            return buf.toKString()
        }
    }

    override fun send(data: String) {
        check(rtcSendMessage(dc, data, -1), "rtcSendMessage")
    }

    override fun close() {
        state.incoming.close()
        if (dc >= 0) {
            rtcClose(dc)
            rtcDelete(dc)
        }
        if (pc >= 0) {
            rtcClosePeerConnection(pc)
            rtcDeletePeerConnection(pc)
        }
        stableRef.dispose()
    }
}
