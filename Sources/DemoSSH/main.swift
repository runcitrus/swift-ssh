import Foundation
import CLibssh2

func performSSHCommandWithPrivateKey(host: String, username: String, privateKeyPath: String, passphrase: String?, command: String) {
    // Инициализация libssh2
    let initResult = libssh2_init(0)
    guard initResult == 0 else {
        print("failed to init libssh2: \(initResult)")
        return
    }

    // Открытие сокета и подключение к серверу
    let sock: Int32 = socket(AF_INET, SOCK_STREAM, 0)
    guard sock >= 0 else {
        let errorMessage = String(cString: strerror(errno))
        print("failed to open socket: \(errorMessage)")
        return
    }

    // Пример подключения к серверу
    var serverAddr = sockaddr_in()
    serverAddr.sin_family = sa_family_t(AF_INET)
    serverAddr.sin_port = UInt16(8022).bigEndian

    // Преобразование IP-адреса в нужный формат
    inet_pton(AF_INET, host, &serverAddr.sin_addr)

    // Подключение к серверу
    let connectionResult = withUnsafePointer(to: &serverAddr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    guard connectionResult == 0 else {
        let errorMessage = String(cString: strerror(errno))
        print("connection failed: \(errorMessage)")
        return
    }

    // Создание сессии
    let session = libssh2_session_init_ex(nil, nil, nil, nil)
    guard session != nil else {
        print("failed to create ssh session")
        return
    }

    // Установка сессии для использования сокета
    libssh2_session_handshake(session, sock)

    // Аутентификация с использованием приватного ключа
    let privateKeyPathCStr = privateKeyPath.cString(using: .utf8)
    let passphraseCStr = passphrase?.cString(using: .utf8)

    let authResult = libssh2_userauth_publickey_fromfile_ex(
        session, username, UInt32(username.utf8.count),
        nil, privateKeyPathCStr, passphraseCStr)

    guard authResult == 0 else {
        print("authentication failed: \(authResult)")
        libssh2_session_disconnect_ex(session, SSH_DISCONNECT_BY_APPLICATION, "Bye", "")
        libssh2_session_free(session)
        return
    }

    // Открытие канала для выполнения команды
    let channel = libssh2_channel_open_ex(session, "session", UInt32(strlen("session")), 2*1024*1024, 32768, nil, 0)
    guard channel != nil else {
        print("failed to open ssh channel")
        libssh2_session_disconnect_ex(session, SSH_DISCONNECT_BY_APPLICATION, "Bye", "")
        libssh2_session_free(session)
        return
    }

    // Выполнение команды на сервере
    let commandCStr = command.cString(using: .utf8)
    let execResult = libssh2_channel_process_startup(channel, "exec", UInt32(strlen("exec")), commandCStr, UInt32(strlen(command)))
    guard execResult == 0 else {
        print("failed to execute command: \(execResult)")
        libssh2_channel_close(channel)
        libssh2_channel_free(channel)
        libssh2_session_disconnect_ex(session, SSH_DISCONNECT_BY_APPLICATION, "Bye", "")
        libssh2_session_free(session)
        return
    }

    // Чтение результата выполнения команды
    var buffer = [CChar](repeating: 0, count: 0x4000)
    while true {
        let bytesRead = libssh2_channel_read_ex(channel, 0, &buffer, buffer.count)
        if bytesRead > 0 {
            let data = Data(buffer.prefix(bytesRead).map { UInt8(bitPattern: $0) })
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }
        } else if bytesRead == LIBSSH2_ERROR_EAGAIN {
            continue
        } else {
            break
        }
    }

    // Закрытие канала и завершение сессии
    libssh2_channel_close(channel)
    libssh2_channel_free(channel)
    libssh2_session_disconnect_ex(session, SSH_DISCONNECT_BY_APPLICATION, "Bye", "")
    libssh2_session_free(session)
    libssh2_exit()
}

func requestPassphrase() -> String? {
    if let passphrase = getpass("enter your passphrase:") {
        return String(cString: passphrase)
    }
    return nil
}

let privateKeyPath = "/Users/and/.ssh/cesbo_ed25519"
let passphrase = requestPassphrase()
performSSHCommandWithPrivateKey(host: "78.128.94.138", username: "root", privateKeyPath: privateKeyPath, passphrase: passphrase, command: "ls -la")
