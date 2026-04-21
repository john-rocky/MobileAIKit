# iOS Framework Integrations

Everything the model can read from or write to on-device.

## EventKit

```swift
let kit = EventKitBridge()
_ = try await kit.requestAccess()
await registry.register(kit.createEventTool())
await registry.register(kit.listEventsTool())
```

## Contacts / Photos

```swift
await registry.register(ContactsBridge().searchTool())
await registry.register(PhotosBridge().recentPhotosTool())
```

## HealthKit

```swift
let hk = HealthKitBridge()
_ = try await hk.requestReadAccess(for: [HKObjectType.quantityType(forIdentifier: .stepCount)!])
await registry.register(hk.recentStepCountTool())
```

## CoreLocation / CoreMotion

```swift
await registry.register(LocationBridge().currentLocationTool())
await registry.register(MotionBridge().stepCountTool())
```

## MapKit

```swift
await registry.register(MapKitBridge.searchPlacesTool())
await registry.register(MapKitBridge.directionsTool())
```

## StoreKit

```swift
await registry.register(StoreKitBridge.listPurchasesTool())
```

## Notifications

```swift
await registry.register(NotificationBridge.scheduleTool())
```

## Files / PDF

```swift
await registry.register(FileTools.readTextFileTool())
await registry.register(PDFExtractor.readerTool())
```

## Web

```swift
await registry.register(WebSearch.tool(provider: DuckDuckGoSearchProvider()))
await registry.register(WebPageReader.readerTool())
```

## SwiftData / Core Data indexing

```swift
let indexer = SwiftDataIndexer(container: container, index: vectorIndex)
try await indexer.indexObjects(of: Note.self, toText: { $0.body }, source: "notes")
```

## Widgets / Live Activities

```swift
WidgetRefresh.reloadAll()
let activity = try LiveActivity.start(attributes: ChatActivityAttributes(), state: .init(status: "Thinking"))
```

## Handoff

```swift
let handoff = HandoffBridge()
handoff.publish(activityType: "com.app.chat", title: "Chat session", info: ["id": sessionId])
```

## URL schemes / Universal Links

```swift
await URLSchemeRouter.shared.register(.init(scheme: "myapp", host: "chat") { url in
    // open chat screen
})
```

## Drag & Drop

```swift
AIAttachmentDropZone(attachments: $attachments) {
    Label("Drop anything", systemImage: "tray.and.arrow.down")
}
```

## Share Extension

```swift
let shared = await ShareExtensionHelper.parseInputItems(extensionContext.inputItems as! [NSExtensionItem])
let attachments = ShareExtensionHelper.toAttachments(shared)
```
