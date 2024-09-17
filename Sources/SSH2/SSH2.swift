import Foundation
import CLibssh2

public class SSH2 {
    var sock: Int32 = -1
    var session: OpaquePointer?

    deinit {
        close()
    }

    public init(
        host: String,
        port: Int32 = 22
    ) throws {
        self.sock = socket(AF_INET, SOCK_STREAM, 0)
        guard self.sock >= 0 else {
            let msg = String(cString: strerror(errno))
            throw SSH2Error.connectFailed(msg)
        }

        var serverAddr = sockaddr_in()
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = UInt16(port).bigEndian
        inet_pton(AF_INET, host, &serverAddr.sin_addr)

        let rc = withUnsafePointer(to: &serverAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard rc == 0 else {
            let msg = String(cString: strerror(errno))
            throw SSH2Error.connectFailed(msg)
        }
    }

    public func close() {
        if let session = self.session {
            libssh2_session_disconnect_ex(session, SSH_DISCONNECT_BY_APPLICATION, "Bye", "")
            libssh2_session_free(session)
            self.session = nil
        }

        if self.sock >= 0 {
            Darwin.close(sock)
            self.sock = -1
        }
    }

    public func sessionInit(
        username: String,
        password: String? = nil,
        privateKeyData: String? = nil,
        privateKeyPath: String? = nil,
        privateKeyPass: String? = nil
    ) throws {
        self.session = libssh2_session_init_ex(nil, nil, nil, nil)
        guard let session = self.session else {
            throw SSH2Error.sessionInitFailed
        }

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

    public func channelOpen() throws -> OpaquePointer {
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

    public func channelClose(_ channel: OpaquePointer) {
        libssh2_channel_close(channel)
        libssh2_channel_free(channel)
    }
}
