# NoNetCom Performance Benchmarks

This document defines repeatable physical-device measurements for NoNetCom.
BLE performance depends heavily on radio hardware, operating system, negotiated
MTU, distance and interference, so results without environment metadata are not
treated as product evidence.

## Result Status

No physical-device benchmark run has been recorded for `1.0.0+1` yet.
Emulator-derived throughput, reconnection and battery figures must not be
published as BLE results.

## Test Matrix

Run each scenario for:

1. Android to Android.
2. Android to iOS in both sender directions.
3. iOS to iOS.

Record:

- NoNetCom version and build number;
- sender and receiver model;
- operating system versions;
- battery health and starting charge;
- negotiated MTU from diagnostics;
- distance and line-of-sight conditions;
- whether screens are on or off;
- number of completed and failed samples.

Use release builds. Disable battery saver, keep other Bluetooth devices
disconnected and perform the run in the same location.

## File Throughput

1. Prepare deterministic files of 100 KB, 1 MB, 10 MB and 30 MB.
2. Place devices one metre apart with clear line of sight.
3. Send each size ten times in each direction.
4. Measure from the first file packet submission to the final delivery ACK.
5. Discard no samples; report failures separately.
6. Calculate effective throughput:

```text
effective KB/s = file bytes / 1024 / elapsed seconds
```

Report median, p10, p90 and failure count. The primary README value is the
median for the 1 MB file; larger files expose sustained-transfer behavior.

## Reconnection

1. Connect peers and deliver a short baseline message.
2. Move the receiver out of range or disable Bluetooth for 15 seconds.
3. Queue a new message on the sender.
4. Restore radio availability.
5. Measure from restoration to the queued message delivery ACK.
6. Repeat twenty times for foreground and background states.

Report median, p90 and failures. Keep peer discovery time in the measurement,
because that is what the user experiences.

## Battery

Measure both devices independently and state which role each device performs.

### Idle Background

1. Charge both devices above 80%.
2. Start NoNetCom, connect peers and turn both screens off.
3. Keep the connection idle for 30 minutes.
4. Record battery percentage-point change.
5. Capture Android Battery Historian/system battery attribution or the Xcode
   Energy Log when available.

### Sustained Transfer

1. Start from the same charge range and thermal state.
2. Transfer files continuously for 10 minutes.
3. Record bytes delivered, battery percentage-point change and thermal state.
4. Repeat three times with sender/receiver roles reversed.

Battery percentage is coarse. Prefer platform energy reports and include raw
artifacts when publishing results.

## Raw Result Template

| Date | Version | Direction | Devices / OS | Scenario | Samples | Median | p10 | p90 | Failures | Notes |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| YYYY-MM-DD | 1.0.0+1 | Android → Android | model / OS → model / OS | 1 MB file KB/s | 10 |  |  |  |  |  |
| YYYY-MM-DD | 1.0.0+1 | Android → iOS | model / OS → model / OS | reconnect foreground ms | 20 |  |  |  |  |  |
| YYYY-MM-DD | 1.0.0+1 | iOS → Android | model / OS → model / OS | reconnect background ms | 20 |  |  |  |  |  |
| YYYY-MM-DD | 1.0.0+1 | Android idle | model / OS | 30-minute battery pp | 3 |  |  |  |  |  |

## Publication Rule

A README number can replace `Pending physical-device run` only when:

- all required environment fields are present;
- raw samples are retained;
- the sample count meets the scenario minimum;
- failed attempts are reported;
- the result was produced by version `1.0.0+1` or explicitly labels another
  version.
