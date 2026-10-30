# Deetty and Dintor

Deetty is the terminal and Dintor is its companion editor for DINX. This repository keeps the upstream slug `rufl/NOCTTY`; some internal identifiers and build files still use the historical `NOCTTY`/`NoctEd` names to preserve source compatibility.

## Source snapshot

This alpha source snapshot is published so DINX packages can be reproduced and audited. DINX pins an immutable commit and checksum when building the applications. This snapshot is not an independent stable release, a general support commitment, or a daily-use qualification.

First-party code is MIT-licensed. Vendored dependencies and generated data retain their own licenses; see [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The build requires Zig 0.17.x; see the [architecture](docs/architecture.md) and [compatibility](docs/compatibility.md) notes.

DINX packaging and integration contracts live in [rufl/DINX](https://github.com/rufl/DINX).
