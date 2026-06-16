# NoNetCom Physical Device QA Matrix

This document defines the manual release-readiness pass for real phones. It is
not a benchmark sheet; performance measurements live in [BENCHMARKS.md](BENCHMARKS.md).

Emulators and simulators can validate UI and Dart logic, but they do not
validate BLE discovery, reconnection, background behavior, radio contention,
camera QR scanning, audio capture or battery cost.

## Release Gate

A build can be considered physically smoke-tested when every mandatory scenario
below has either:

- `PASS` with device/OS notes; or
- `KNOWN ISSUE` with a linked issue and a clear release decision.

Do not publish BLE throughput, reconnection or battery claims from this matrix.
Use the benchmark methodology for those numbers.

## Device Pairs

Run the matrix on at least these combinations:

| Pair ID | Sender | Receiver | Required | Notes |
| --- | --- | --- | --- | --- |
| AA-1 | Android physical phone | Android physical phone | yes | Different vendors preferred |
| AI-1 | Android physical phone | iPhone | yes | Run both sender directions |
| II-1 | iPhone | iPhone | yes | Different iOS versions preferred |
| OLD-1 | Oldest supported Android | Newer phone | recommended | Catches BLE permission and MTU differences |
| LOW-1 | Low battery / battery saver off | Any peer | recommended | Battery saver must be off for baseline |

## Environment Record

Fill this once per test run.

| Field | Value |
| --- | --- |
| Date | YYYY-MM-DD |
| NoNetCom version | 1.0.0+1 |
| Build type | debug / release |
| Tester |  |
| Location |  |
| Wi-Fi state | on / off |
| Airplane mode | off / on with Bluetooth re-enabled |
| Interference notes |  |
| Raw logs saved? | yes / no |

## Device Record

| Device ID | Model | OS version | NoNetCom build | Battery start | Battery end | Notes |
| --- | --- | --- | --- | ---: | ---: | --- |
| A |  |  | 1.0.0+1 |  |  |  |
| B |  |  | 1.0.0+1 |  |  |  |
| C |  |  | 1.0.0+1 |  |  |  |

## Status Legend

- `PASS` - behavior matches expected result.
- `FAIL` - behavior blocks or contradicts expected result.
- `FLAKY` - passed and failed in the same conditions.
- `N/A` - not applicable to this pair.
- `KNOWN ISSUE` - accepted for this run with a linked issue.

## Mandatory Scenarios

### 1. First Launch And Skip

| ID | Steps | Expected | AA | AI | II | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| ONB-1 | Fresh install, open app | Onboarding appears with swipeable cards |  |  |  |  |
| ONB-2 | Tap `Pomin` | App opens conversation list without requesting permissions |  |  |  |  |
| ONB-3 | Reopen app | Onboarding does not reappear |  |  |  |  |
| ONB-4 | Open settings after skip | Permissions/Bluetooth can be configured later |  |  |  |  |

### 2. Permissions And Bluetooth

| ID | Steps | Expected | AA | AI | II | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| PERM-1 | Request required permissions from onboarding/settings | System prompts match platform needs |  |  |  |  |
| PERM-2 | Deny one permission, open diagnostics | Missing permission is visible with repair path |  |  |  |  |
| BLE-1 | Turn on airplane mode, re-enable Bluetooth | App can still start local discovery |  |  |  |  |
| BLE-2 | Start Bluetooth on both devices | Both devices become visible in nearby scan |  |  |  |  |
| BLE-3 | Disable Bluetooth on one device | Peer shows offline or send queue remains pending |  |  |  |  |

### 3. Contact Discovery And Trust

| ID | Steps | Expected | AA | AI | II | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| TRUST-1 | Scan nearby device | Contact appears with local editable name |  |  |  |  |
| TRUST-2 | Open 1:1 chat before verification | UI clearly marks contact as unverified |  |  |  |  |
| TRUST-3 | Device A shows own QR, device B scans it | B marks A as verified only if key matches |  |  |  |  |
| TRUST-4 | Reverse QR flow | A marks B as verified only if key matches |  |  |  |  |
| TRUST-5 | Scan unrelated/invalid QR | App refuses verification and shows warning |  |  |  |  |
| TRUST-6 | Reinstall or import different identity on one side | Previously verified peer shows key-change warning |  |  |  |  |

### 4. Messaging

| ID | Steps | Expected | AA | AI | II | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| MSG-1 | Send short text both directions | Message appears once and reaches delivered state |  |  |  |  |
| MSG-2 | Send emoji-only message | Emoji is displayed correctly |  |  |  |  |
| MSG-3 | Send while peer is briefly out of range | Message stays queued, then delivers after reconnect |  |  |  |  |
| MSG-4 | Kill foreground on Android sender during pending send | Foreground service or resume flow keeps/retries queue |  |  | N/A |  |
| MSG-5 | Lock iPhone screen during pending send/receive | App resumes without duplicate messages | N/A |  |  |  |

### 5. File Transfer

| ID | Steps | Expected | AA | AI | II | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| FILE-1 | Send 100 KB file both directions | Transfer completes and shows progress |  |  |  |  |
| FILE-2 | Send 1 MB file both directions | Transfer completes without duplicate file entry |  |  |  |  |
| FILE-3 | Send 30 MB file | App accepts exactly up to the documented limit |  |  |  |  |
| FILE-4 | Try file above 30 MB | App rejects file before transfer |  |  |  |  |
| FILE-5 | Interrupt transfer by disabling Bluetooth for 15 seconds | Transfer resumes or fails visibly after retry exhaustion |  |  |  |  |

### 6. Voice

| ID | Steps | Expected | AA | AI | II | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| VOICE-1 | Record and send a short voice message 1:1 | Receiver can play it |  |  |  |  |
| VOICE-2 | Start walkie-talkie while connected | Peer sees live voice session and can respond |  |  |  |  |
| VOICE-3 | Move devices apart during walkie-talkie | Session reports degraded/failure state without app crash |  |  |  |  |
| VOICE-4 | Try voice in group chat | UI prevents unsupported group voice |  |  |  |  |

### 7. Group Conversations

| ID | Steps | Expected | AA | AI | II | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| GRP-1 | Create group with 2-6 trusted contacts | Group appears in conversation list |  |  |  |  |
| GRP-2 | Try to exceed 6 members | UI blocks extra selection |  |  |  |  |
| GRP-3 | Send group text | Each reachable member receives one copy |  |  |  |  |
| GRP-4 | One member offline during group send | Online members receive; offline delivery remains pending/fails visibly |  |  |  |  |

### 8. Background And Reconnection

| ID | Steps | Expected | AA | AI | II | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| BG-1 | Put sender in background, send from peer | Notification appears when platform allows it |  |  |  |  |
| BG-2 | Lock both screens for 5 minutes, then unlock | Connection or rediscovery recovers without data loss |  |  |  |  |
| BG-3 | Android: remove app from recents | Foreground service behavior matches release notes |  | N/A | N/A |  |
| BG-4 | iOS: force quit app manually | Background BLE stops; reopening recovers state | N/A |  |  |  |
| BG-5 | Toggle Bluetooth off/on after queued message | Queued message delivers or fails with clear status |  |  |  |  |

### 9. Diagnostics And Privacy

| ID | Steps | Expected | AA | AI | II | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| PRIV-1 | Open logs after sending sensitive test text | Logs do not contain message body |  |  |  |  |
| PRIV-2 | Export diagnostics report | Report contains counts/statuses, not conversation content |  |  |  |  |
| PRIV-3 | Copy logs manually | Clipboard contains only visible log content |  |  |  |  |
| PRIV-4 | Send logs to developer | User mail composer opens; send is user-controlled |  |  |  |  |
| PRIV-5 | Clear logs and diagnostics | Advanced settings show cleared state |  |  |  |  |

## Optional Measurement Hooks

When mandatory scenarios pass, run the benchmark plan:

- file throughput: 100 KB, 1 MB, 10 MB, 30 MB;
- reconnection latency foreground/background;
- 30-minute idle background battery;
- 10-minute sustained transfer battery.

Record raw values in [BENCHMARKS.md](BENCHMARKS.md) or a dated artifact file.

## Run Summary Template

| Pair | Mandatory pass count | Failures | Flaky | Known issues | Release decision |
| --- | ---: | ---: | ---: | --- | --- |
| AA-1 |  |  |  |  |  |
| AI-1 Android -> iOS |  |  |  |  |  |
| AI-1 iOS -> Android |  |  |  |  |  |
| II-1 |  |  |  |  |  |

## Issue Template For Failures

```text
Title:
Pair:
Devices / OS:
NoNetCom build:
Scenario ID:
Steps:
Expected:
Actual:
Logs attached:
Diagnostic report attached:
Reproducibility:
Release impact:
```
