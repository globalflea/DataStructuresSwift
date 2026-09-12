# Implementation Plan: Complete Ecosystem Alignment to `Meridian`

Align all platform projects to the unified `Meridian` suite across local directories, SwiftPM packages, and GitHub repositories:
- `JointSwift` $\rightarrow$ **`MeridianGraph`**
- `EchartsSwift` $\rightarrow$ **`MeridianChart`**
- `TradingViewSwift` $\rightarrow$ **`MeridianTrade`**

## Complete Ecosystem Taxonomy

| Current Name | Target Name | Role in Ecosystem | Local Directory | GitHub Repository | Visibility |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`MeridianCore`** | `MeridianCore` | Core geometry, layout, UI primitives, lock-free collections | `/Users/globalflea/Xplore/MeridianCore` | `globalflea/MeridianCore` | Public |
| **`MeridianStream`** | `MeridianStream` | Real-time event streaming & replication engine | `/Users/globalflea/Xplore/MeridianStream` | `globalflea/MeridianStream` | Private |
| **`JointSwift`** | **`MeridianGraph`** | Node-link scene graphs, edge routing, visual connectors, UML | `/Users/globalflea/Xplore/MeridianGraph` | `globalflea/MeridianGraph` | Private |
| **`EchartsSwift`** | **`MeridianChart`** | Declarative charting engine (Cartesian, radial, financial) | `/Users/globalflea/Xplore/MeridianChart` | `globalflea/MeridianChart` | Private |
| **`TradingViewSwift`** | **`MeridianTrade`** | Institutional financial workstation & multi-pane charting | `/Users/globalflea/Xplore/MeridianTrade` | `globalflea/MeridianTrade` | Private |

---

## User Review Required

> [!IMPORTANT]
> 1. **Symlink Safety**: Local folders `/Users/globalflea/Xplore/JointSwift`, `/Users/globalflea/Xplore/EchartsSwift`, and `/Users/globalflea/Xplore/TradingViewSwift` will be preserved via backward-compatible symlinks pointing to their new `Meridian*` destinations.
> 2. **GitHub Synchronization**:
>    - `globalflea/JointSwift` will be renamed to `globalflea/MeridianGraph` via `gh repo rename`.
>    - `globalflea/TradingViewSwift` will be renamed to `globalflea/MeridianTrade` via `gh repo rename`.
>    - `globalflea/MeridianChart` will be created as a private repository and pushed with full history.
> 3. **SwiftPM Package Names**:
>    - `JointSwift/Package.swift` $\rightarrow$ `name: "MeridianGraph"`
>    - `EchartsSwift/Package.swift` $\rightarrow$ `name: "MeridianChart"`
>    - `TradingViewSwift/Package.swift` $\rightarrow$ `name: "MeridianTrade"`

---

## Execution Steps

### Phase 1: Pre-Rename Commits
1. **`MeridianCore`**:
   - Commit and push pending UI primitives (`DimensionSizing`, `Splitter`, `ToolContainer`, `PanelHeader`, `Panel`, tests).
2. **`JointSwift`**:
   - Commit pending `UMLStudioView` and `Package.swift` updates.
3. **`EchartsSwift`**:
   - Commit pending `ShowcaseContentView`, `ScrollWheelZoomModifier`, and test updates.
4. **`TradingViewSwift`**:
   - Commit pending Stage 25 & 26 implementations (`LeftToolbarView`, `EchartsAnalyticalChartView`, `AnalyticalChartTemplates`, `PaneSplitterDivider`, tests, backlog).

---

### Phase 2: Package Renames & GitHub Repository Alignment

1. **`JointSwift` $\rightarrow$ `MeridianGraph`**:
   - Rename GitHub repository:
     ```bash
     gh repo rename MeridianGraph --repo globalflea/JointSwift --yes
     ```
   - Update `Package.swift` to `name: "MeridianGraph"`.
   - Update git remote URL to `https://github.com/globalflea/MeridianGraph.git`.
   - Commit: `chore(branding): rename package to MeridianGraph`.
   - Push to `origin/main`.
   - Move directory:
     ```bash
     mv /Users/globalflea/Xplore/JointSwift /Users/globalflea/Xplore/MeridianGraph
     ln -s /Users/globalflea/Xplore/MeridianGraph /Users/globalflea/Xplore/JointSwift
     ```

2. **`EchartsSwift` $\rightarrow$ `MeridianChart`**:
   - Update `Package.swift` to `name: "MeridianChart"`.
   - Commit: `chore(branding): rename package to MeridianChart`.
   - Create private repository on GitHub:
     ```bash
     gh repo create globalflea/MeridianChart --private --source=. --remote=origin --push
     ```
   - Move directory:
     ```bash
     mv /Users/globalflea/Xplore/EchartsSwift /Users/globalflea/Xplore/MeridianChart
     ln -s /Users/globalflea/Xplore/MeridianChart /Users/globalflea/Xplore/EchartsSwift
     ```

3. **`TradingViewSwift` $\rightarrow$ `MeridianTrade`**:
   - Rename GitHub repository:
     ```bash
     gh repo rename MeridianTrade --repo globalflea/TradingViewSwift --yes
     ```
   - Update `Package.swift`:
     - `name: "MeridianTrade"`
     - Update dependency: `.package(path: "../MeridianChart")`
     - Update products referencing `package: "MeridianChart"`
   - Update git remote URL to `https://github.com/globalflea/MeridianTrade.git`.
   - Commit: `chore(branding): rename package to MeridianTrade and link MeridianChart`.
   - Push to `origin/main`.
   - Move directory:
     ```bash
     mv /Users/globalflea/Xplore/TradingViewSwift /Users/globalflea/Xplore/MeridianTrade
     ln -s /Users/globalflea/Xplore/MeridianTrade /Users/globalflea/Xplore/TradingViewSwift
     ```

---

### Phase 3: Cross-Ecosystem Verification

1. **Test Execution**:
   - `swift test` in `MeridianCore` (68/68 passed).
   - `swift test` in `MeridianGraph` (35/35 passed).
   - `swift test` in `MeridianChart` (53/53 passed).
   - `swift test` in `MeridianTrade` (174+/174+ passed).
2. **GitHub Repository Inspection**:
   - Verify `gh repo list globalflea` reflects:
     - `globalflea/MeridianCore`
     - `globalflea/MeridianStream`
     - `globalflea/MeridianGraph`
     - `globalflea/MeridianChart`
     - `globalflea/MeridianTrade`
3. **Workspace Integrity**:
   - Confirm all working trees are clean and synchronized.
