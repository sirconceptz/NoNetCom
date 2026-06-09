# NoNetCom Threat Model

## Protected

- Message and file contents are encrypted between the two identity keys.
- Modification of ciphertext, packet identifier or message counter is detected.
- Previously authenticated E2EE v2 packets are not processed twice.
- A changed identity key produces a contact warning after prior verification.
- Application servers are not involved in message delivery.

## Visible to Nearby Observers

- Bluetooth radio activity and approximate timing.
- Device presence and the NoNetCom service UUID.
- Packet sizes, encrypted packet identifiers and transfer duration.
- Public identity keys exchanged during discovery.

## Not Protected

- A compromised or unlocked endpoint.
- Malware with access to application storage or microphone permissions.
- Traffic analysis and physical proximity inference.
- Identity verification when users do not compare the safety code.
- Denial of service, Bluetooth jamming or deliberate queue flooding.

## Current Security Position

The protocol uses standard primitives from the Dart `cryptography` package, but
NoNetCom has not received an independent cryptographic audit. It should be
described as encrypted software under active development, not as independently
certified secure communications.

Private identity keys currently use application-local protected storage. Moving
key wrapping to Android Keystore and iOS Keychain is a recommended future
hardening step.
