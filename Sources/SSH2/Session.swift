import Foundation
import CLibssh2

enum SSH2Result<T> {
    case success(T)
    case failure(Int32, String)
}

public class Session {
    private let sock: Socket
    let rawPointer: OpaquePointer
    let queue = DispatchQueue(label: "SSH2.Session")

    deinit {
        libssh2_session_disconnect_ex(rawPointer, SSH_DISCONNECT_BY_APPLICATION, "Bye", "")
        libssh2_session_free(rawPointer)
        libssh2_exit()
    }

    internal init(
        host: String,
        port: Int32 = 22,
        banner: String? = nil
    ) throws {
        sock = try Socket(host, port)

        libssh2_init(0)

        let session = libssh2_session_init_ex(nil, nil, nil, nil)
        guard let session else {
            throw SSH2Error.connectFailed("Failed to init session")
        }

        if let banner = banner {
            libssh2_session_banner_set(session, banner)
        }

        libssh2_session_set_blocking(session, 0)

        self.rawPointer = session
    }

    internal func handshake() async throws {
        let result = await call {
            libssh2_session_handshake(self.rawPointer, self.sock.fd)
        }

        if case .failure(_, let msg) = result {
            throw SSH2Error.connectFailed(msg)
        }
    }

    internal func call<T: BinaryInteger>(_ callback: @escaping () -> T) async -> SSH2Result<T> {
        while true {
            let rc = callback()
            if rc >= 0 {
                return .success(rc)
            } else if rc == LIBSSH2_ERROR_EAGAIN {
                await wait()
            } else {
                let msg = getLastErrorMessage()
                return .failure(Int32(rc), msg)
            }
        }
    }

    internal func call<T>(_ callback: @escaping () -> T?) async -> SSH2Result<T> {
        while true {
            if let ptr = callback() {
                return .success(ptr)
            }

            let rc = libssh2_session_last_errno(rawPointer)
            if rc == LIBSSH2_ERROR_EAGAIN {
                await wait()
            } else {
                let msg = getLastErrorMessage()
                return .failure(rc, msg)
            }
        }
    }

    internal func wait() async {
        await withCheckedContinuation {
            (continuation: CheckedContinuation<Void, Never>) in

            let dir = libssh2_session_block_directions(rawPointer)

            if dir == 0 {
                continuation.resume()
                return
            }

            if (dir & LIBSSH2_SESSION_BLOCK_INBOUND) != 0 {
                let source = DispatchSource.makeReadSource(
                    fileDescriptor: sock.fd,
                    queue: queue
                )

                source.setEventHandler {
                    source.cancel()
                    continuation.resume()
                }

                source.resume()
            }

            if (dir & LIBSSH2_SESSION_BLOCK_OUTBOUND) != 0 {
                let source = DispatchSource.makeWriteSource(
                    fileDescriptor: sock.fd,
                    queue: queue
                )

                source.setEventHandler {
                    source.cancel()
                    continuation.resume()
                }

                source.resume()
            }
        }
    }
}
