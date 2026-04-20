# Privacy & Safety

AIKit is on-device first. Lock it down further with one policy object.

## Strict local-only

```swift
await PrivacyGuard.shared.setPolicy(.strictLocal)
try await PrivacyGuard.shared.ensureNetworkAllowed() // throws if disabled
```

## Redaction

```swift
let telemetry = Telemetry(privacyRedactor: Redaction.redactor())
```

## Prompt-injection detector

```swift
let safety = SafetyPolicy(
    blocklist: ["password", "api_key"],
    promptInjectionDetector: SafetyPolicy.defaultInjectionDetector
)
try safety.check(input: userInput)
```

## Encrypted backups (Keychain + AES-GCM)

```swift
let data = try await memory.exportAll()
try EncryptedStorage.writeEncrypted(data, to: backupURL, keyTag: "mobileaikit.memory")

// Later:
let restored = try EncryptedStorage.readEncrypted(backupURL, keyTag: "mobileaikit.memory")
try await memory.importAll(restored)
```

## Approval gate for tools

```swift
let registry = ToolRegistry { spec, argumentData in
    await askUserToApprove(spec: spec)
}
```
