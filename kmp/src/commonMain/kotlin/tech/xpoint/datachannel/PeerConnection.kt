package tech.xpoint.datachannel

import kotlinx.coroutines.channels.Channel

/** A single incoming message from the data channel. */
sealed class DCMessage {
    /** UTF-8 text message. */
    class Text(val text: String) : DCMessage()
    /** Raw binary message. */
    class Binary(val data: ByteArray) : DCMessage()
}

/**
 * A single-use WebRTC peer connection with a data channel.
 *
 * Each instance represents one connection. After [close] is called
 * (or the remote side closes the channel), create a new instance.
 *
 * ## Offerer flow
 * ```
 * val conn = LDCPeerConnection()
 * val offerSdp = conn.offer()
 * // send offerSdp to remote, receive answerSdp
 * conn.acceptAnswer(answerSdp)
 * conn.awaitDataChannel()
 * conn.send("hello")
 * ```
 *
 * ## Answerer flow
 * ```
 * val conn = LDCPeerConnection()
 * val answerSdp = conn.acceptOffer(offerSdp)
 * // send answerSdp to remote
 * conn.awaitDataChannel()
 * for (msg in conn.incoming) { ... }
 * ```
 */
interface PeerConnection : AutoCloseable {

    /** Incoming messages from the remote peer. Closed when the data channel closes. */
    val incoming: Channel<DCMessage>

    /**
     * Create an offer and a data channel.
     *
     * Suspends until ICE gathering is complete.
     *
     * @param label data channel label visible to both peers
     * @return the local SDP offer to send to the remote peer
     * @throws IllegalStateException on libdatachannel errors
     * @throws IllegalArgumentException if called more than once
     */
    suspend fun offer(label: String = "data"): String

    /**
     * Accept a remote offer and generate an answer.
     *
     * Suspends until ICE gathering is complete.
     *
     * @param offerSdp the remote SDP offer
     * @return the local SDP answer to send back to the remote peer
     * @throws IllegalStateException on libdatachannel errors
     * @throws IllegalArgumentException if called more than once
     */
    suspend fun acceptOffer(offerSdp: String): String

    /**
     * Set the remote answer SDP (offerer side only).
     *
     * @param answerSdp the remote SDP answer
     * @throws IllegalStateException on libdatachannel errors
     */
    fun acceptAnswer(answerSdp: String)

    /**
     * Suspend until the data channel is open and ready for messaging.
     *
     * After this returns, [send] and [incoming] are usable.
     */
    suspend fun awaitDataChannel()

    /**
     * Send a text message to the remote peer.
     *
     * @throws IllegalStateException if the data channel is not open or on send failure
     */
    fun send(data: String)
}
