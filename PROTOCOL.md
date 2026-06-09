# NoNetCom Protocol

## Versions

- Native transport: `transport-v2`
- Encrypted envelope: `e2ee-v2`

Peers advertise supported capabilities in the unencrypted `hello` message.
Unknown future encrypted protocol versions are rejected.

## BLE Transport v2

Flutter payloads are split into reliable JSON frames. The native bridge then
adds a second binary fragmentation layer so an individual GATT operation stays
below the negotiated payload size.

Each native fragment contains:

- magic bytes `N2`;
- 64-bit local message identifier;
- 16-bit fragment index;
- 16-bit fragment count;
- up to 150 bytes of payload.

Android and iOS maintain independent priority queues for each peer:

1. control and acknowledgements;
2. live voice;
3. regular messages;
4. file transfer traffic.

Only one acknowledged GATT write is active per connection. Notifications use
platform backpressure callbacks before more data is submitted.

## E2EE v2

Identity keys use X25519. For every peer and direction, a 256-bit AES-GCM key is
derived from the X25519 shared secret with HKDF-SHA256.

The HKDF context contains:

- both public identity keys in stable sorted order;
- the sender public key;
- the receiver public key;
- the protocol label `NoNetCom E2EE v2`.

Every outgoing peer stream has a persistent monotonically increasing counter.
The AES-GCM additional authenticated data is:

```text
NoNetCom|E2EE|v2|<packetId>|<counter>
```

Receivers retain a rolling persistent window of 512 authenticated counters per
peer. A repeated counter is acknowledged again but its plaintext is not
processed twice.

Contact verification codes are the first 48 bits of SHA-256 over the raw X25519
public key. They are a human comparison aid, not a replacement for comparing
the full key through a trusted channel.
