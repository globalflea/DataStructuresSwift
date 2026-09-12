# Core Libraries Evolution: Trading App Support

To properly flesh out the institutional-grade Trading Application, the foundational libraries (`MeridianStream` and `MeridianCore`) must evolve. 

By pushing heavy financial mechanics down into these core libraries, the `TradingViewSwift` app remains a lightweight, declarative UI layer while the core libraries do the heavy computational lifting.

Here are the proposed architectural changes for both repositories:

---

## 1. Proposals for `MeridianStream` (CEP & Rule Engine)

Currently, `MeridianStream` is a generalized Complex Event Processing (CEP) engine. To support a trading workstation, we need to introduce domain-specific quantitative mechanics.

### A. Financial Domain-Specific Language (DSL) Operators
The stream engine evaluates declarative rules (e.g., `price > 150`). We need to expand its AST (Abstract Syntax Tree) to natively understand trading mechanics.
- **Cross Operators**: Add `CROSSOVER(A, B)` and `CROSSUNDER(A, B)` to detect when an asset's price crosses a moving average or when the MACD crosses its signal line.
- **Percentage Trailing Evaluators**: Add a `TRAILING_STOP(peak, percent)` operator that automatically tracks the highest high of a stream and triggers an alert if the price drops by a specified percentage from that peak.

### B. Natively Built-in Time-Series Windowing (Conflation)
Currently, trading ticks arrive irregularly (e.g., 5 ticks in one second, 0 in the next).
- **Proposal**: Build an `OHLCWindow` (Open-High-Low-Close) aggregator directly into `MeridianStream`. Instead of the trading app manually building 1-minute or 5-minute bars, `MeridianStream` should natively window the raw `StreamEvent` ticks and emit a single `OHLCBarEvent` at the end of the window interval.

### C. In-Memory Time-Series Ring Buffers
- **Proposal**: Implement a highly optimized, fixed-size `RingBuffer` state store in `MeridianStream`. When calculating a 200-period Moving Average, the engine shouldn't allocate new arrays. It should utilize a continuous ring buffer that overwrites the oldest tick, guaranteeing $O(1)$ memory allocation during violent market volatility.

---

## 2. Proposals for `MeridianCore` (Math, Geometry, Resilience)

`MeridianCore` handles pure math, vector geometry, and resilience. We need to introduce structures that accelerate financial charting.

### A. Expand `VectorGeometry` for Candlesticks
- **Proposal**: Add a `CandlestickGeometry` or `FinancialVector` struct. Rendering 10,000 candlesticks on screen requires calculating 10,000 wicks (lines) and 10,000 bodies (rectangles). By pushing this math into `MeridianCore`'s `VectorGeometry`, we can utilize SIMD (Single Instruction, Multiple Data) to calculate the coordinates of thousands of candlesticks in parallel on the CPU before sending them to SwiftUI/Metal.

### B. Financial `DataStructures`
- **Proposal**: Move the `ChronologicalBarAligner` (which aligns two different assets on the same timeline, filling in gaps if one asset didn't trade that minute) down into `MeridianCore`'s DataStructures module. This is a complex computer science problem (merging sparse chronological arrays) and belongs in the core library rather than the UI app.

### C. Introduce `Resilience` Circuit Breakers for Data Feeds
- **Proposal**: The `TradingData` module fetches data from Google Finance/WebSockets. If the WebSocket disconnects, the trading app shouldn't crash or freeze. We should leverage the existing `Resilience` module in `MeridianCore` to implement a `CircuitBreaker` and `ExponentialBackoff` retry policy specifically tuned for reconnecting to live market data feeds.

---

## Next Steps
If you agree with these architectural directions, we can log these as explicit roadmap items in the `BACKLOG.md` of their respective repositories, and I can update the Gemini Flash instructions to include the `MeridianCore` data structure modifications!
