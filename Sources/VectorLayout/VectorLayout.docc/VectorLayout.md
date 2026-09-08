# ``VectorLayout``

Graph kinematics, force-directed simulation, linear-time Buchheim-Walker tidy trees, and topological DAG layering.

## Overview

`VectorLayout` provides automated spatial organization and layout algorithms for structured relational graphs, hierarchical trees, and directed dependency networks.

Whether rendering software architecture diagrams (**`JointSwift`**) or data visualization networks (**`EchartsSwift`**), `VectorLayout` balances computational efficiency with aesthetic layout invariants.

### Layout Engines

- **Force-Directed Graph Simulator (`ForceDirectedSimulator`)**: Physics simulation modeling nodes as charged particles and edges as springs. Uses semi-implicit Euler-Cromer integration to guarantee energy stability.
- **Tidy Tree Solver (`TidyTreeSolver`)**: Strict $O(N)$ implementation of the Buchheim-Walker algorithm satisfying Reingold-Tilford aesthetic criteria, supporting Cartesian and Radial projections.
- **DAG Layering Solver (`DAGLayeringSolver`)**: Topological rank assignment with Tarjan DFS back-edge cycle detection and longest-path layer assignment.

## Topics

### Force-Directed Graph Simulation
- ``ForceDirectedSimulator``
- ``ForceDirectedNode``
- ``ForceDirectedEdge``
- ``ForceDirectedConfiguration``

### Hierarchical & Tidy Tree Layout
- ``TidyTreeSolver``
- ``TidyTreeNode``
- ``TidyTreeConfiguration``
- ``TreeOrientation``

### Directed Acyclic Graph (DAG) Layering
- ``DAGLayeringSolver``
- ``DAGEdge``

## See Also
- [04 Vector Graph & Tree Layout](file:///Users/globalflea/Xplore/MeridianCore/Docs/Design/04_VECTOR_GRAPH_AND_TREE_LAYOUT.md)
