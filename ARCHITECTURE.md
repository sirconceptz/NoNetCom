# NoNetCom Architecture

## Application Layer

`AppDependencies` is the composition root. It owns concrete stores, crypto,
transport, platform bridges and feature services. `ChatShell` receives this
container explicitly, which allows tests or future product variants to replace
individual dependencies.

`AppLifecycleCoordinator` is the only Flutter lifecycle observer. It forwards
state changes to the application controller, which resumes queued traffic and
records transitions without coupling platform callbacks to widgets.

## Domain and Data

- `domain/models.dart`: contacts, groups, messages and protocol value objects.
- `data/store.dart`: local persistence and migrations.
- `transport/reliable_transport.dart`: durable envelopes, ACKs and retries.
- `services/crypto.dart`: E2EE v2 and replay state.

## Feature Controllers

Controllers under `app/controllers` coordinate one feature area: contacts,
messages, files, voice, transport, security, lifecycle and diagnostics. They use
dependencies from the composition root rather than constructing plugins.

## Platform Runtime

### Android

`NoNetComApplication` owns a cached Flutter engine. `MainActivity` attaches to
that engine and does not destroy it when the UI host disappears.
`NoNetComBleService` runs as a `connectedDevice` foreground service while BLE is
active, keeping the process, Dart queue and native GATT callbacks alive.
The first activity instance claims the process-wide BLE bridge; later activity
recreations replace only UI-bound handlers and do not reset active GATT state.

### iOS

Core Bluetooth central and peripheral managers use restoration identifiers.
Restored peripherals and services are reattached to delegates, and restoration
events are buffered until Flutter subscribes to the event channel.

## Diagnostics

`DiagnosticsReportService` creates privacy-limited snapshots without message or
file contents. `CapabilityService` owns platform permission policy and labels,
leaving dialogs responsible only for presentation and user actions.
