import CLibssh2

extension SSH2 {
    func socketConnect(_ host: String, _ port: Int32) throws {
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

    func socketClose() {
        if sock >= 0 {
            Darwin.close(sock)
            sock = -1
        }
    }
}
