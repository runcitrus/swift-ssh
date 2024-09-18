public enum SSH2Error: Error {
    case initFailed(Int)
    case connectFailed(String)
    case sessionInitFailed
    case authenticationFailed(String)
    case channelOpenFailed(String)
    case execFailed(String)
}
