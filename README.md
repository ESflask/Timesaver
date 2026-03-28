# Timesaver (Infinite Wake)

An alarm app that defeats oversleeping by firing repeated alarms until you physically prove you're awake.

## Architecture Change Log

### Removed: iOS Shortcuts-based alarm creation
The original design used iOS Shortcuts (`IW_CreateAlarm` / `IW_DeleteAlarms`) to create 30 alarms in the native Clock app, one per minute. This approach was abandoned because the setup was too complex for users — it required manually importing two Shortcuts and granting permissions. The app now handles alarm/timer scheduling entirely in-app.

## Usage
1. Download the app
2. Set your deadline time (the time you absolutely cannot be late for)
3. Sleep
4. Alarms fire repeatedly — press "I'm awake" and complete the shake mission to stop them
5. Wake up on time

## Stack
- Platform: iOS (iPhone)
- Framework: SwiftUI
- Language: Swift 5
- Min iOS: 17.0
