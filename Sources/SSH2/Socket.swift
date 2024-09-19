import CLibssh2

class Socket {
    public var fd: Int32

    deinit {
        Darwin.close(fd)
    }

    init(_ host: String, _ port: Int32, timeout: Int = 10) throws {
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

        var fd: Int32 = -1

        for info in sequence(first: addr, next: { $0?.pointee.ai_next }) {
            guard let info else {
                continue
            }

            fd = Darwin.socket(
                info.pointee.ai_family,
                info.pointee.ai_socktype,
                info.pointee.ai_protocol
            )
            guard fd >= 0 else {
                let msg = String(cString: strerror(errno))
                throw SSH2Error.connectFailed(msg)
            }

            setsockopt(
                fd,
                SOL_SOCKET,
                SO_SNDTIMEO,
                &timeoutStruct,
                socklen_t(MemoryLayout<timeval>.size)
            )

            setsockopt(
                fd,
                SOL_SOCKET,
                SO_RCVTIMEO,
                &timeoutStruct,
                socklen_t(MemoryLayout<timeval>.size)
            )

            if Darwin.connect(fd, info.pointee.ai_addr, info.pointee.ai_addrlen) == 0 {
                self.fd = fd
                return
            }
        }

        // catch error before closing the socket
        let msg = String(cString: strerror(errno))

        Darwin.close(fd)

        throw SSH2Error.connectFailed(msg)
    }
}
