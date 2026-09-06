# DataStructuresSwift System Design Specification
## Document 01: Core Collections & Distributed Resilience Primitives

---

## 1. Executive Summary & Problem Domain

High-throughput distributed systems, real-time complex event processing (CEP) engines, and geospatial databases require two fundamental layers of foundation:
1. **Algorithmic Collections**: Specialized, cache-friendly, thread-safe data structures that avoid $O(N)$ memory shifting, linear search, or lock contention during high-velocity updates.
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

    class ResilientOutbox~Item~ {
        +capacity: Int
        +state: OutboxState
        +pendingCount: Int
        +enqueue(item: Item) Bool
        +flush() async
        +setDispatcher(dispatcher)
        +clear()
    }

    class SlidingDeduplicator~Key~ {
        +ttl: TimeInterval
        +count: Int
        +checkAndRecord(key: Key, now: Date) Bool
        +clear()
    }

    class ConnectionSupervisor~Client~ {
        +config: SupervisorConfig
        +state: SupervisorState
        +activeClient: Client?
        +start()
        +stop() async
    }

    class DesiredStateReconciler~Resource, Client~ {
        <<interface>>
        +reconcile(desired, client) async throws
    }

    ConnectionSupervisor ..> DesiredStateReconciler : triggers on connect
    ResilientOutbox ..> ConnectionSupervisor : flushes on connect
```

---

### 2.2 Sequence Diagram: Supervised Outbox Dispatch & Replay (`sequenceDiagram`)

```mermaid
sequenceDiagram
    autonumber
    participant Caller as Application / Engine
    participant Outbox as ResilientOutbox~Item~
    participant Supervisor as ConnectionSupervisor~Client~
    participant Deduplicator as SlidingDeduplicator~Key~
    participant Peer as Remote Stateful Peer

    Note over Supervisor,Peer: Network Partition Active
    Caller->>Outbox: enqueue(mutation)
    Outbox-->>Caller: true (Non-blocking O(1), buffered)

    Note over Supervisor,Peer: Network Restored & Reconnected
    Supervisor->>Peer: connect() / healthProbe()
    Peer-->>Supervisor: ok = true
    Supervisor->>Supervisor: state = .connected

    Supervisor->>Outbox: flush()
    loop Drain Buffered Mutations
        Outbox->>Peer: dispatch(mutation)
        Peer-->>Outbox: ok = true
    end

    Note over Peer,Deduplicator: Inbound Event Catch-Up Replay
    loop Replayed Events
        Peer-->>Caller: event(key, timestamp)
        Caller->>Deduplicator: checkAndRecord(key)
        alt First Seen (New Event)
            Deduplicator-->>Caller: true
            Caller->>Caller: processEvent(event)
        else Duplicate Notification
            Deduplicator-->>Caller: false
            Caller->>Caller: dropDuplicate(event)
        end
    end
```

---

### 2.3 State Transition Diagram (`stateDiagram-v2`)

```mermaid
stateDiagram-v2
    [*] --> Disconnected

    Disconnected --> Connecting : start()
    Connecting --> Connected : Handshake & Health Probe OK
    Connecting --> Reconnecting : Connection Failed / Refused

    state Connected {
        [*] --> Active
        Active --> Active : Heartbeat OK
    }

    Connected --> Reconnecting : Heartbeat Timeout / Peer Crash
    Reconnecting --> Connecting : Backoff Jitter Delay Expired

    Connected --> Closed : stop()
    Connecting --> Closed : stop()
    Reconnecting --> Closed : stop()
    Closed --> [*]
```

---

### 2.4 Data Pipeline Flowchart (`flowchart TD`)

```mermaid
flowchart TD
    subgraph DataStructures["DataStructures Module"]
        CM["ConcurrentMap / ConcurrentSet"]
        RB["RingBuffer (Power-of-Two Masking)"]
        CEB["CircularEventBuffer (Timestamped Cutoff)"]
        MD["MonotonicDeque (O(1) Running Min/Max)"]
        PQ["PriorityQueue (Min/Max Heap)"]
        PT["PathTrie (Prefix Invalidation)"]
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

### 3.1 Collections
- **`ConcurrentMap` / `ConcurrentSet`**: Mutual exclusion via `NSLock`, supporting full dictionary API semantics without reader starvation.
- **`RingBuffer`**: Constant-time insertion with power-of-two bitmask indexing (`index & (capacity - 1)`), zero array shifting.
- **`CircularEventBuffer`**: Timestamped cutoff queries (`events(since:)`, `events(sinceTimestampMillis:)`) for zero-loss chronological replay.
- **`MonotonicDeque`**: Dual-ended queue enforcing strict element monotonicity for $O(1)$ running extremum window aggregation.
- **`PriorityQueue`**: Array-backed binary heap with configurable ordering (`.min`, `.max`).
- **`PathTrie`**: Tokenized property hierarchy prefix tree for $O(L)$ cache invalidation.

### 3.2 Resilience Primitives
- **`ResilientOutbox`**: Non-blocking asynchronous mutation buffer isolating transactional callers from network partitions, with bounded memory overflow eviction and exponential backoff retry (base 250ms, max 10s, ±20% jitter).
- **`SlidingDeduplicator`**: Sliding-window TTL cache evaluating deterministic fingerprints to guarantee exactly-once evaluation under at-least-once transport replay.
- **`ConnectionSupervisor`**: Long-running supervisor actor managing socket lifecycles, health probing, and auto-reconnect backoffs.
- **`DesiredStateReconciler`**: Declarative state convergence protocol ensuring registered entities (hooks, channels) survive remote service restarts.

---

## 4. Verification Matrix

| Target | Suites | Tests | Pass Rate | Warnings |
|---|---|---|---|---|
| `DataStructures` | 2 | 9 | 100% | 0 |
| `Resilience` | 1 | 5 | 100% | 0 |
| **Total** | **3** | **14** | **100%** | **0** |
