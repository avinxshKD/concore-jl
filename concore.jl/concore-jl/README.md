# Concore.jl

A Julia reference implementation of the [concore](https://github.com/ControlCore-Project/concore) library — a lightweight framework for closed-loop peripheral neuromodulation control systems.

> **Status**: Early prototype for GSoC 2026 application  
> **Maintainers**: @mvk2, @rahuljagwani1012, @pradeeban

## Overview

I'm building a Julia port of concore from scratch. Right now, the prototype covers the core functionality:

- **GraphML Workflow Parsing** — Loads node definitions and parameters from GraphML files
- **PID Node Execution** — Type-stable PID controller logic with state management
- **File-Based Communication** — Mirrors how concore passes data between nodes via files
- **FileWatching Integration** — Watches for file changes instead of polling (more efficient than Python)

## Installation

You'll need Julia 1.6 or later. Then:

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

That's it! The dependencies are minimal:
- `EzXML.jl` for parsing GraphML files
- `FileWatching` (comes with Julia stdlib)

## Quick Start

Got Julia installed? Here's how to try it out:

```julia
using Concore

# Load a workflow from GraphML
nodes = load_graph("examples/sample_graph.graphml")

# Grab the first node
controller = nodes[1]
println("Loaded: $(controller.id) with kp=$(controller.kp)")

# Run one PID step
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

## Progress & Effort

**Application Period**: ~20 hours spent (as of Jan 29, 2026)
- GraphML parsing implementation
- PID controller logic
- File-based communication stubs
- FileWatching integration
- This prototype

**GSoC Timeline** (350 hours total):
- Phase 1 (Weeks 1-4): Core protocol implementation ✓ (in progress)
- Phase 2 (Weeks 5-8): Edge execution & multi-node orchestration
- Phase 3 (Weeks 9-12): Testing, optimization, and full concore-lite compatibility

See the roadmap below for what's coming next.

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

## Design & Architecture

I'm following the existing concore patterns but using Julia idioms where it makes sense. Here's how I'm mapping across languages:

| Pattern | Julia Choice |
|---------|---------------|
| Python module globals | `STATE` Dict with symbols |
| C++ `Concore` class | `ConcoreNode` mutable struct |
| `unchanged()` sync loop | Same logic, string accumulator |
| File format `[simtime, ...]` | Kept for compatibility |
| Verilog `readdata`/`writedata` | `read_input`/`write_output` |

### Why These Choices?

Julia lets me do some things better than the original Python:
- **Mutable structs** are perfect for state (no need for classes)
- **Multiple dispatch** means I can extend `execute_step` later for different node types
- **Type-stable fields** help the JIT compiler generate fast code
- **FileWatching stdlib** gives native file monitoring without slow polling

I'm avoiding OOP inheritance and just using composition + dispatch, which is more idiomatic Julia.

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
