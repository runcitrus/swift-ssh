import CLibssh2

public enum SSH2Error: Error {
    case initFailed(Int)
    case connectFailed(String)
    case sessionInitFailed
    case authenticationFailed(String)
    case channelOpenFailed(String)
    case execFailed(String)
}

extension SSH2 {
    func getLastErrorMessage() -> String {
        var errmsgPtr: UnsafeMutablePointer<Int8>? = nil
        var errmsgLen: Int32 = 0

        libssh2_session_last_error(session, &errmsgPtr, &errmsgLen, 0)

        if let value = errmsgPtr {
            return String(cString: value)
        } else {
            return "unknown error"
        }
    }
}
