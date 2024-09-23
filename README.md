# swift-ssh

Swift wrapper for libssh2 with static build

## Dependencies

```
brew install openssl zlib libssh2
```

## Usage

### Initialization

Initialization function should be called only once on application startup:

```swift
SSH2.libInit()
```

Deinitialization function should be called only once before application exit:

```swift
SSH2.libExit()
```

### Connect to a server

```swift
let ssh = try SSH2(
    "example.com",
    22,
    banner: "SSH-2.0-libssh2_Demo"
)
```

### Authentication

Password authentication:

```swift
try ssh.auth(
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

try ssh.auth(
    "root",
    SSH2AuthMethod.privateKey(key, "passphrase")
)
```

Ask for passphrase if needed:

```swift
var auth = SSH2AuthMethod.privateKey("...")

while true {
    do {
        try ssh.auth(username, auth)
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
let channel = try ssh.exec("ls -la")
let (stdout, stderr) = channel.readAll()
```

Command execution with input:

```swift
let stdin = Pipe()
let channel = try ssh.exec("/bin/sh -s", stdin: stdin)
let (stdout, stderr) = channel.readAll()
```

With stdout and stderr pipes:

```swift
let stdout = Pipe()
stdout.fileHandleForReading.readabilityHandler = {
    let data: Data = $0.availableData
    if data.count > 0 {
        print(String(data: data, encoding: .utf8)!, terminator: "")
    }
}

let stderr = Pipe()
stderr.fileHandleForReading.readabilityHandler = {
    let data: Data = $0.availableData
    if data.count > 0 {
        print(String(data: data, encoding: .utf8)!, terminator: "")
    }
}

let channel = try ssh.exec("apt update")
try channel.readAll(
    stdout: stdout,
    stderr: stderr
)
```
