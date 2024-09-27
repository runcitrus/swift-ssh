import Foundation
import Clibssh2

enum SSH2Result<T> {
    case success(T)
    case failure(Int32, String)
}

// Source: https://forums.swift.org/t/automatically-cancelling-continuations/72960/9
public final class CancellableCheckedContinuation<T> : @unchecked Sendable {
    private var continuation: CheckedContinuation<T, any Error>?
    private let lock = NSLock()
    private var cancelled: Bool = false
    private var onCancel: (@Sendable () -> Void)?

    init() {
    }

    @available(iOS 13, *)
    public func setContinuation(_ continuation: CheckedContinuation<T, any Error>) -> Bool {
        var alreadyCancelled = false
        lock.withLock {
            if cancelled {
                alreadyCancelled = true
            } else {
                self.continuation = continuation
            }
        }
        if alreadyCancelled {
            continuation.resume(throwing: CancellationError())
        }
        return !alreadyCancelled
    }

    public func onCancel(_ action: @Sendable @escaping ()->Void) {
        var alreadyCancelled = false
        lock.withLock {
            if cancelled {
                alreadyCancelled = true
            } else {
                self.onCancel = action
            }
        }
        if alreadyCancelled {
            action()
        }
    }

    private func onContinuation(cancelled: Bool = false, _ action: (CheckedContinuation<T, any Error>) -> Void) {
        var safeContinuation: CheckedContinuation<T, any Error>?
        var safeOnCancel: (@Sendable () -> Void)?
        lock.withLock {
            self.cancelled = self.cancelled || cancelled
            safeContinuation = continuation
            safeOnCancel = onCancel
            continuation = nil
            onCancel = nil
        }
        if let safeContinuation {
            action(safeContinuation)
        }
        if cancelled {
            safeOnCancel?()
        }
    }

    public func resume(returning value: T) {
        onContinuation {
            $0.resume(returning: value)
        }
    }

    public func resume(throwing error: Error) {
        onContinuation {
            $0.resume(throwing: error)
        }
    }

    public var isCancelled: Bool {
        var cancelled: Bool = false
        lock.withLock {
            cancelled = self.cancelled
        }
        return cancelled
    }

    func cancel() {
        onContinuation(cancelled: true) {
            $0.resume(throwing: CancellationError())
        }
    }
}

extension CancellableCheckedContinuation where T == Void {
    public func resume() {
        self.resume(returning: ())
    }
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
                do {
                    try await wait()
                } catch {
                    return .failure(-1001, "task cancelled")
                }
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
                do {
                    try await wait()
                } catch {
                    return .failure(-1001, "task cancelled")
                }
            } else {
                let msg = getLastErrorMessage()
                return .failure(rc, msg)
            }
        }
    }

    internal func wait() async throws {
        let cancellableContinuation = CancellableCheckedContinuation<Void>()

        try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, any Error>) in

                    guard cancellableContinuation.setContinuation(continuation) else {
                        return
                    }

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
            },

            onCancel: {
                cancellableContinuation.cancel()
            }
        )
    }
}
