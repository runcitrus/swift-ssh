import Foundation
import CLibssh2

public class SSH2 {
    var sock: Int32 = -1
    var session: OpaquePointer?
    var timeout: Int = 10

    public static func libInit() {
        libssh2_init(0)
    }

    public static func libExit() {
        libssh2_exit()
    }

    deinit {
        sessionClose()
        socketClose()
    }

    func socketClose() {
        if sock >= 0 {
            Darwin.close(sock)
            sock = -1
        }
    }

    public init(
        _ host: String,
        port: Int32 = 22
    ) throws {
        var hints = Darwin.addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_flags = AI_ADDRCONFIG | AI_CANONNAME
        hints.ai_protocol = IPPROTO_TCP

        var addrInfo: UnsafeMutablePointer<addrinfo>?
        let portString = String(port)
        let rc = Darwin.getaddrinfo(host, portString, &hints, &addrInfo)
        guard rc == 0, let addr = addrInfo else {
            let msg = String(cString: gai_strerror(rc))
            throw SSH2Error.connectFailed(msg)
        }

        defer {
            Darwin.freeaddrinfo(addrInfo)
        }

        var timeoutStruct = Darwin.timeval(tv_sec: timeout, tv_usec: 0)

        for info in sequence(first: addr, next: { $0?.pointee.ai_next }) {
            guard let info else {
                continue
            }

            sock = Darwin.socket(
                info.pointee.ai_family,
                info.pointee.ai_socktype,
                info.pointee.ai_protocol
            )
            guard sock >= 0 else {
                let msg = String(cString: strerror(errno))
                throw SSH2Error.connectFailed(msg)
            }

            setsockopt(
                sock,
                SOL_SOCKET,
                SO_SNDTIMEO,
                &timeoutStruct,
                socklen_t(MemoryLayout<timeval>.size)
            )

            setsockopt(
                sock,
                SOL_SOCKET,
                SO_RCVTIMEO,
                &timeoutStruct,
                socklen_t(MemoryLayout<timeval>.size)
            )

            if Darwin.connect(sock, info.pointee.ai_addr, info.pointee.ai_addrlen) == 0 {
                return
            }
        }
        let msg = String(cString: strerror(errno))

        Darwin.close(sock)
        sock = -1

        throw SSH2Error.connectFailed(msg)
    }

    func sessionClose() {
        if let session = self.session {
            libssh2_session_disconnect_ex(session, SSH_DISCONNECT_BY_APPLICATION, "Bye", "")
            libssh2_session_free(session)
            self.session = nil
        }
    }

    public func sessionInit(
        username: String = "root",
        password: String? = nil,
        privateKeyData: String? = nil,
        privateKeyPath: String? = nil,
        privateKeyPass: String? = nil
    ) throws {
        session = libssh2_session_init_ex(nil, nil, nil, nil)
        guard let session else {
            throw SSH2Error.sessionInitFailed
        }

        libssh2_session_set_timeout(session, timeout * 1000)
        libssh2_session_banner_set(session, "SSH-2.0-libssh2_Citrus.app")

        let rc = libssh2_session_handshake(session, sock)
        guard rc == 0 else {
            throw SSH2Error.sessionInitFailed
        }

        if let value = password {
            let rc = libssh2_userauth_password_ex(
                session,
                username,
                UInt32(username.count),
                value,
                UInt32(value.count),
                nil
            )
            guard rc == 0 else {
                let msg = getLastErrorMessage()
                throw SSH2Error.authenticationFailed(msg)
            }
        } else if let value = privateKeyPath {
            let rc = libssh2_userauth_publickey_fromfile_ex(
                session,
                username,
                UInt32(username.count),
                nil,
                value,
                privateKeyPass
            )
            guard rc == 0 else {
                let msg = getLastErrorMessage()
                throw SSH2Error.authenticationFailed(msg)
            }
        } else if let value = privateKeyData {
            let rc = libssh2_userauth_publickey_frommemory(
                session,
                username,
                Int(username.count),
                nil,
                0,
                value,
                value.count,
                privateKeyPass
            )
            guard rc == 0 else {
                let msg = getLastErrorMessage()
                throw SSH2Error.authenticationFailed(msg)
            }
        } else {
            throw SSH2Error.authenticationFailed("unknown authentication method")
        }
    }

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

    func channelClose(_ channel: OpaquePointer) {
        libssh2_channel_close(channel)
        libssh2_channel_free(channel)
    }

    func channelOpen() throws -> OpaquePointer {
        let channelType = "session"
        let channel = libssh2_channel_open_ex(
            session,
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

    public func exec(_ command: String) throws -> (stdout: Data?, stderr: Data?) {
        let channel = try channelOpen()
        defer {
            channelClose(channel)
        }

        let request = "exec"
        let rc = libssh2_channel_process_startup(
            channel,
            request,
            UInt32(request.count),
            command,
            UInt32(command.count)
        )
        guard rc == 0 else {
            let msg = getLastErrorMessage()
            throw SSH2Error.execFailed(msg)
        }

        var stdout = Data()

        let bufferSize = 0x4000
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }

        while true {
            let stdoutSize = libssh2_channel_read_ex(channel, 0, buffer, bufferSize)

            if stdoutSize > 0 {
                stdout.append(buffer, count: stdoutSize)
            } else if stdoutSize == 0 {
                break // EOF
            } else if stdoutSize == LIBSSH2_ERROR_EAGAIN {
                continue
            } else {
                let msg = getLastErrorMessage()
                throw SSH2Error.execFailed(msg)
            }
        }

        return (stdout: stdout, stderr: nil)
    }
}
