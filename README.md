# swift-ssh

Swift wrapper for libssh2 with static build

## Dependencies

```
brew install openssl zlib libssh2
```

## Usage

### Connect to a server

```swift
let ssh = try await SSH2.connect(
    "example.com",
    port: 22,
    banner: "SSH-2.0-libssh2_Demo"
)
```

### Authentication

Password authentication:

```swift
try await ssh.auth(
    "root",
    SSH2AuthMethod.password("password")
)
```

Private key authentication:

```swift
let key = try String(
    contentsOfFile: "/Users/example/.ssh/id_ed25519",
    encoding: .utf8
)

try await ssh.auth(
    "root",
    SSH2AuthMethod.privateKey(key, "passphrase")
)
```

Ask for passphrase if needed:

```swift
var auth = SSH2AuthMethod.privateKey("...")

while true {
    do {
        try await ssh.auth(username, auth)
        break
    } catch {
        switch error {
        case SSH2Error.authFailed(-16, _):
            let passphrase = requestPassphrase()
            auth = .privateKey(key, passphrase)
        default:
            throw error
        }
    }
}
```

### Execute a command

Basic command execution:

```swift
let channel = try await ssh.exec("ls -la")
let (stdout, stderr) = try await channel.readAll()
```

Writing data to the command stdin:

```swift
let script = "date"
let data = script.data(using: .utf8)!
let channel = try await ssh.exec("/bin/sh -s")
try await channel.writeAll(data)
```

Writing from file to the command stdin:

```swift
let stdin = Pipe()
let channel = try await ssh.exec("/bin/sh -s")
try await channel.writeAll(stdin.fileHandleForReading)
```

Reading data from command with handlers:

```swift
try await channel.readAll(
    stdoutHandler: {
        if let text = String(data: $0, encoding: .utf8) {
            print(text, terminator: "")
        }
    },
    stderrHandler: {
        if let text = String(data: $0, encoding: .utf8) {
            print(text, terminator: "")
        }
    }
)
```

Reading data from command to string:

```swift
let (stdout, stderr) = try await channel.readAll()
```
