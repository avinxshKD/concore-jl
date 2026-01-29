# Concore.jl

A Julia reference implementation of the [concore](https://github.com/ControlCore-Project/concore) library — a lightweight framework for closed-loop peripheral neuromodulation control systems.

> **Status**: Early prototype for GSoC 2026 application  
> **Maintainers**: @mvk2, @rahuljagwani1012, @pradeeban

## Overview

This prototype demonstrates core concore functionality in idiomatic Julia:

- **GraphML Workflow Parsing** — Load node definitions from GraphML files
- **PID Node Execution** — Type-stable control computations with state management
- **File-Based Communication** — Mirrors the concore IPC pattern (`read`/`write` via files)
- **FileWatching Integration** — Stub for reactive execution triggers

## Installation

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

Requires Julia 1.6+ and will install:
- `EzXML.jl` — XML/GraphML parsing
- `FileWatching` — File change detection (stdlib)

## Quick Start

```julia
using Concore

# Load a workflow from GraphML
nodes = load_graph("examples/sample_graph.graphml")

# Get the controller node
controller = nodes[1]
println("Loaded: $(controller.id) with kp=$(controller.kp)")

# Run a PID step
error = 10.0
output = execute_step(controller, error)
println("Error=$error → Output=$output")
```

## Core API

### Data Structures

```julia
mutable struct ConcoreNode
    id::String
    kp::Float64          # proportional gain
    ki::Float64          # integral gain
    kd::Float64          # derivative gain
    integral::Float64    # accumulated integral (state)
    prev_error::Float64  # previous error (state)
end
```

### Functions

| Function | Description |
|----------|-------------|
| `load_graph(filepath)` | Parse GraphML → `Vector{ConcoreNode}` |
| `execute_step(node, error, dt=1.0)` | Run one PID iteration, returns control output |
| `reset!(node)` | Clear internal state (integral, prev_error) |
| `run_node_loop(node, errors)` | Batch execution over error sequence |
| `initval(str)` | Parse `"[simtime, v1, v2, ...]"` → values |
| `read_input(port, name, initstr)` | Read from `inpath/port/name` |
| `write_output(port, name, val; delta=0)` | Write to `outpath/port/name` |
| `unchanged()` | Check if accumulated reads changed (sync pattern) |

## GraphML Format

```xml
<?xml version="1.0" encoding="UTF-8"?>
<graphml xmlns="http://graphml.graphdrawing.org/xmlns">
  <graph id="G" edgedefault="directed">
    <node id="controller">
      <data key="kp">2.0</data>
      <data key="ki">0.5</data>
      <data key="kd">0.1</data>
    </node>
    <edge id="e1" source="controller" target="plant"/>
  </graph>
</graphml>
```

## Examples

### Basic Example
```bash
julia --project=. examples/basic_example.jl
```

Demonstrates GraphML loading and PID execution.

### Control Loop Example
```bash
julia --project=. examples/concore_loop_example.jl
```

Shows the full concore-style loop pattern (mirrors Python/C++ implementations).

## Architecture & Design Decisions

This implementation follows patterns from the existing concore codebase while leveraging Julia's strengths:

| Concore Pattern | Julia Implementation |
|-----------------|---------------------|
| Python module globals | `STATE` Dict with symbols |
| C++ `Concore` class | `ConcoreNode` mutable struct |
| `unchanged()` sync loop | Same pattern, uses string accumulator |
| File format `[simtime, ...]` | Preserved for compatibility |
| Verilog `readdata`/`writedata` | `read_input`/`write_output` |

### Julia-Specific Optimizations

- **Mutable structs** — Julia-native, allows in-place state updates without allocation
- **Multiple dispatch** — `execute_step` can be extended for different node types (future: filters, estimators)
- **Type-stable fields** — All `Float64` for predictable JIT compilation and performance
- **No inheritance** — Avoids Python-style OOP; uses composition + dispatch instead
- **FileWatching stdlib** — Native file monitoring without polling overhead (unlike Python concore)

### Protocol Compatibility

- All file formats match existing concore implementations
- Array serialization format: `[simtime, value1, value2, ...]`
- Ready to interop with Python/C++/Verilog nodes in mixed environments

## Project Structure

```
concore-jl/
├── Project.toml                 # Package dependencies
├── README.md
├── src/
│   └── Concore.jl              # Main module
└── examples/
    ├── sample_graph.graphml    # Example workflow
    ├── basic_example.jl        # Simple demo
    └── concore_loop_example.jl # Full control loop
```

## Roadmap (GSoC Scope)

- [x] GraphML parsing with EzXML.jl
- [x] PID node execution
- [x] File-based read/write (concore protocol)
- [x] Basic FileWatching stub
- [ ] Edge execution logic
- [ ] Multi-node workflow orchestration
- [ ] Shared memory communication (like C++ `read_SM`/`write_SM`)
- [ ] ZeroMQ integration
- [ ] Full concore-lite compatibility

## References

- [concore GitHub](https://github.com/ControlCore-Project/concore)
- [concore.hpp](https://github.com/ControlCore-Project/concore/blob/main/concore.hpp) — C++ reference
- [concore.v](https://github.com/ControlCore-Project/concore/blob/main/concore.v) — Verilog reference
- [concore.py](https://github.com/ControlCore-Project/concore/blob/main/concore.py) — Python reference

## License

MIT (following concore project licensing)
