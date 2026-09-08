# ``MeridianCore``

High-performance data structures, crash-resilient write-ahead logging (WAL), distributed sequence replication, and resilience supervisors.

## Overview

`MeridianCore` serves as the foundational substrate for zero-dependency distributed systems, embedded databases, state machines, and graphics engines.

Engineered under strict first-principles standards, `MeridianCore` guarantees:
- **Crash-Resilience**: Torn-page protection, CRC-64 verification, atomic multi-record frames, and zero-allocation sparse binary indices.
- **Ordered Collections**: $B$-Trees with cache-conscious node fanout, power-of-two bitmask ring buffers, and amortized $O(1)$ monotonic deques.
- **High-Throughput Replication**: Sequence-tracked pub/sub broadcasting and follower catch-up state machines.
- **Network & Fault Resilience**: Exponential backoff with jitter, sliding deduplication, and transactional outboxes.

## Topics

### Ordered & Circular Collections
- ``BTree``
- ``RingBuffer``
- ``CircularEventBuffer``
- ``MonotonicDeque``
- ``PriorityQueue``

### Write-Ahead Logging & Storage
- ``WALWriter``
- ``WALReader``
- ``SegmentedWALWriter``
- ``SegmentedWALReader``
- ``WALIndex``
- ``WALRecord``
- ``WALFrame``
- ``WALInspector``
- ``WALPlaybackController``
- ``WALFormat``
- ``WALSyncPolicy``
- ``WALRetentionPolicy``
- ``WALError``

### Distributed Sequence Replication
- ``SequencedRecord``
- ``ReplicationBroadcaster``
- ``ReplicationFollowerEngine``
- ``ReplicationSubscriberInfo``
- ``ReplicationFollowerState``
- ``ReplicationEngineStatus``

### Hashing & String Matching
- ``CRC64``
- ``Glob``

## See Also
- [00 Architecture Index & Executive Summary](file:///Users/globalflea/Xplore/MeridianCore/Docs/Design/00_INDEX_AND_EXECUTIVE_SUMMARY.md)
- [01 Data Structures & Resilience Specification](file:///Users/globalflea/Xplore/MeridianCore/Docs/Design/01_DATA_STRUCTURES_AND_RESILIENCE_SPECIFICATION.md)
