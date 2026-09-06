# DataStructuresSwift System Design Specification
## Document 01: Core Collections & Distributed Resilience Primitives

---

## 1. Executive Summary & Problem Domain

High-throughput distributed systems, real-time complex event processing (CEP) engines, and geospatial databases require two fundamental layers of foundation:
1. **Algorithmic Collections & Indexing**: Specialized, cache-friendly, thread-safe data structures that avoid $O(N)$ memory shifting, linear search, or lock contention during high-velocity updates.
2. **Distributed Resilience Primitives**: Decoupled, non-blocking fault-tolerance patterns that isolate business execution from transient network partitions, process crashes, and at-least-once message duplicates.

**`DataStructuresSwift`** is a zero-dependency, pure Swift 6 library providing these shared building blocks to **`GruleSwift`**, **`Tile38Swift`**, and external microservices.

---

## 2. Multi-Perspective Architectural Diagrams

### 2.1 UML Class Diagram (`classDiagram`)

```mermaid
classDiagram
    class ConcurrentMap~Key, Value~ {
        -lock: NSLock
        -storage: Dictionary~Key, Value~
        +get(key: Key) Value?
        +set(key: Key, value: Value)
        +remove(key: Key) Value?
        +contains(key: Key) Bool
        +keys: List~Key~
        +values: List~Value~
        +removeAll()
    }

    class RingBuffer~Element~ {
        +capacity: Int
        +maxCapacity: Int
        +count: Int
        +append(element: Element) Element?
        +popFirst() Element?
        +removeAll()
    }

    class CircularEventBuffer~Element: TimestampedItem~ {
        +capacity: Int
        +count: Int
        +append(event: Element)
        +events(since: Date, where) List~Element~
        +events(sinceTimestampMillis: Int64, where) List~Element~
        +allEvents() List~Element~
        +clear()
    }

    class BTree~Key, Value~ {
        +degree: Int
        +count: Int
        +insert(key: Key, value: Value) Value?
        +find(key: Key) Value?
        +remove(key: Key) Value?
        +scan(from: Key?, to: Key?, reverse: Bool) List~Element~
        +clear()
    }

    class PriorityQueue~Element~ {
        +count: Int
        +peek() Element?
        +push(element: Element)
        +pop() Element?
        +clear()
    }

    class CRC64 {
        <<enumeration>>
        +polynomial: UInt64
        +checksum(data: Data) UInt64
        +checksum(buffer: UnsafeRawBufferPointer) UInt64
        +update(crc: UInt64, with: Data) UInt64
    }

    class Glob {
        +pattern: String
        +matches(text: String) Bool
        +match(pattern: String, text: String)$ Bool
    }

    class ResilientOutbox~Mutation~ {
        +capacity: Int
        +pendingCount: Int
        +state: OutboxState
        +setDispatcher(dispatcher)
        +enqueue(mutation: Mutation) Bool
        +flush()
        +clear()
    }

    class SlidingDeduplicator~Key~ {
        +ttl: TimeInterval
        +count: Int
        +isDuplicate(key: Key, now: Date) Bool
        +clear()
    }

    class ConnectionSupervisor {
        +state: SupervisorState
        +start()
        +stop()
    }

    CircularEventBuffer --> RingBuffer : encapsulates
    ResilientOutbox --> RingBuffer : internal buffer
```

---

### 2.2 Sequence Diagram (`sequenceDiagram`): Outbox Mutation & Deduplication

```mermaid
sequenceDiagram
    autonumber
    actor Caller as Engine / Agenda
    participant Outbox as ResilientOutbox
    participant Remote as Network Service
    participant Ingress as Ingress Worker
    participant Dedup as SlidingDeduplicator
    participant Handler as Processing Logic

    Caller->>Outbox: enqueue(mutation) [O(1)]
    Note over Outbox: Non-blocking write into bounded buffer
    Outbox-->>Caller: true (Execution unblocked)
    
    rect rgb(240, 248, 255)
        Note over Outbox,Remote: Background Asynchronous Flush Loop
        Outbox->>Remote: dispatch(mutation)
        Remote-->>Outbox: Ack (Success)
        Outbox->>Outbox: Drop sent mutation & reset backoff
    end

    Remote->>Ingress: Replay event delivery
    Ingress->>Dedup: isDuplicate(fingerprint)
    alt First time seen
        Dedup-->>Ingress: false (Allow)
        Ingress->>Handler: Process event
    else Duplicate delivery
        Dedup-->>Ingress: true (Suppress)
        Note over Ingress: Event dropped safely (Idempotency)
    end
```

---

### 2.3 State Transition Diagram (`stateDiagram-v2`): Outbox Circuit State

```mermaid
stateDiagram-v2
    [*] --> Idle: Initialized

    Idle --> Flushing: enqueue() / flush() triggered
    Flushing --> Idle: All mutations dispatched successfully
    Flushing --> Paused: Dispatcher detached (nil)
    Paused --> Flushing: Dispatcher attached
    Flushing --> Retrying: Network drop / dispatch error
    Retrying --> Retrying: Exponential Backoff (±20% Jitter)
    Retrying --> Flushing: Reconnection / Next attempt
    Flushing --> [*]: Deallocated / clear()
```

---

### 2.4 Data Pipeline Flowchart (`flowchart TD`)

```mermaid
flowchart TD
    subgraph DataStructures["DataStructures Module"]
        CM["ConcurrentMap / ConcurrentSet"]
        RB["RingBuffer (Power-of-Two Masking)"]
        CEB["CircularEventBuffer (Timestamped Cutoff)"]
        BT["BTree (Cache-Friendly Ordered Range Index)"]
        MD["MonotonicDeque (O(1) Running Min/Max)"]
        PQ["PriorityQueue (Min/Max Binary Heap)"]
        PT["PathTrie (Prefix Invalidation)"]
        CR["CRC64 (ECMA-182 Data Integrity)"]
        GL["Glob (Redis/Unix Pattern Matcher)"]
    end

    subgraph Resilience["Resilience Module"]
        RO["ResilientOutbox (Bounded FIFO & Exponential Retry)"]
        SD["SlidingDeduplicator (Sliding TTL Idempotency)"]
        CS["ConnectionSupervisor (Auto-Reconnect & Keep-Alives)"]
        DSR["DesiredStateReconciler (Declarative Sync)"]
    end

    Resilience --> DataStructures
    
    Tile38["Tile38Swift (Geospatial Database)"] --> DataStructures
    Tile38 --> Resilience
    
    Grule["GruleSwift (Inference & CEP Engine)"] --> DataStructures
    Grule --> Resilience
```

---

## 3. Subsystem Specifications

### 3.1 Collections & Indexing
- **`ConcurrentMap` / `ConcurrentSet`**: Mutual exclusion via `NSLock`, supporting full dictionary API semantics without reader starvation.
- **`RingBuffer`**: Constant-time insertion with power-of-two bitmask indexing (`index & (capacity - 1)`), zero array shifting.
- **`CircularEventBuffer`**: Timestamped cutoff queries (`events(since:)`, `events(sinceTimestampMillis:)`) for zero-loss chronological replay.
- **`BTree`**: High-fanout B-Tree with Copy-on-Write value semantics, contiguous node array layouts, bidirectional range scanning (`scan(from:to:)`), and `Sequence` conformance.
- **`MonotonicDeque`**: Dual-ended queue enforcing strict element monotonicity for $O(1)$ running extremum window aggregation.
- **`PriorityQueue`**: Array-backed binary heap with configurable ordering (`.min`, `.max`, or custom sort closure).
- **`PathTrie`**: Tokenized property hierarchy prefix tree for $O(L)$ cache invalidation.

### 3.2 Hashing & Integrity
- **`CRC64`**: Hardware-aligned 64-bit Cyclic Redundancy Check calculator utilizing the ECMA-182 polynomial (`0x42F0E1EBA9EA3693`) and precomputed 256-entry lookup table. Operates on `Data` and `UnsafeRawBufferPointer`.

### 3.3 Algorithms & Pattern Matching
- **`Glob`**: Zero-regex wildcard string matcher supporting Redis/Unix pattern conventions (`*`, `?`, `[abc]`, `[a-z]`, `[^0-9]`, backslash escaping).

### 3.4 Resilience Primitives
- **`ResilientOutbox`**: Non-blocking asynchronous mutation buffer isolating transactional callers from network partitions, with bounded memory overflow eviction and exponential backoff retry (base 250ms, max 10s, ±20% jitter).
- **`SlidingDeduplicator`**: Sliding-window TTL cache evaluating deterministic fingerprints to guarantee exactly-once evaluation under at-least-once transport replay.
- **`ConnectionSupervisor`**: Long-running supervisor actor managing socket lifecycles, health probing, and auto-reconnect backoffs.
- **`DesiredStateReconciler`**: Declarative state convergence protocol ensuring registered entities (hooks, channels) survive remote service restarts.

---

## 4. Verification Matrix

| Target | Suites | Tests | Pass Rate | Code Coverage | Warnings |
|---|---|---|---|---|---|
| `DataStructures` | 6 | 28 | 100% | 94.73% | 0 |
| `Resilience` | 1 | 5 | 100% | 95.20% | 0 |
| **Total** | **7** | **33** | **100%** | **>94.8%** | **0** |
