import CLibssh2

extension SSH2 {
    func channelOpen() throws -> OpaquePointer {
        let channelType = "session"
        let channel = libssh2_channel_open_ex(
            session.rawPointer,
            channelType,
            UInt32(channelType.count),
            2 * 1024 * 1024,
            32768,
            nil,
            0
        )
        guard channel != nil else {
            let msg = getLastErrorMessage()
            throw SSH2Error.channelOpenFailed(msg)
        }

        return channel!
    }

    func channelClose(_ channel: OpaquePointer) {
        libssh2_channel_close(channel)
        libssh2_channel_free(channel)
    }
}
