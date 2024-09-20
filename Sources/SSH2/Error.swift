import CLibssh2

public enum SSH2Error: Error {
    case connectFailed(String)
    case sessionInitFailed
    case authFailed(Int32, String)
    case channelOpenFailed(String)
    case channelProcessFailed(String)
    case channelReadFailed(String)
    case channelWriteFailed(String)
}

func getLastErrorMessage(_ session: OpaquePointer) -> String {
    var errmsgPtr: UnsafeMutablePointer<Int8>? = nil
    var errmsgLen: Int32 = 0

    libssh2_session_last_error(session, &errmsgPtr, &errmsgLen, 0)

    if let value = errmsgPtr {
        return String(cString: value)
    } else {
        return "unknown error"
    }
}
