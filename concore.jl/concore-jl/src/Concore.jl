"""
Concore.jl - Julia Reference Implementation (Prototype)

A minimal proof-of-concept for concore: a lightweight framework for 
closed-loop peripheral neuromodulation control systems.

This prototype demonstrates:
- GraphML workflow parsing
- Basic PID node execution
- File-based communication stub (concore pattern)
"""
module Concore

using EzXML
using FileWatching

export ConcoreNode, load_graph, execute_step, run_node_loop, reset!
export watch_and_execute, read_input, write_output, initval, unchanged
export sanitize_numpy_string, parse_concore_payload

# -----------------------------------------------------------------------------
# NumPy Serialization Parser
# -----------------------------------------------------------------------------

"""
    sanitize_numpy_string(s::String) -> String

Sanitize a Python/NumPy serialized string for Julia parsing.
Handles numpy-specific type annotations that appear in concore protocol messages.

Converts patterns like:
- `np.float64(1.5)` → `1.5`
- `np.int32(42)` → `42`
- `np.array([1,2,3])` → `[1,2,3]`
- `numpy.float64(1.5)` → `1.5`

This allows Julia to natively parse data from Python controllers without
requiring PyCall or other heavy dependencies.
"""
function sanitize_numpy_string(s::String)::String
    result = s
    
    # Handle np.dtype(...) and numpy.dtype(...) patterns
    # Matches: np.float64(1.5), numpy.int32(42), np.float_(3.14), etc.
    result = replace(result, r"(?:np|numpy)\.\w+\(([^()]+)\)" => s"\1")
    
    # Handle np.array([...]) patterns
    result = replace(result, r"(?:np|numpy)\.array\((\[[^\]]*\])\)" => s"\1")
    
    # Handle any remaining nested cases (run twice for nested patterns)
    result = replace(result, r"(?:np|numpy)\.\w+\(([^()]+)\)" => s"\1")
    
    # Clean up any Python-style None -> nothing (for compatibility)
    result = replace(result, "None" => "nothing")
    
    # Clean up Python True/False -> Julia true/false
    result = replace(result, r"\bTrue\b" => "true")
    result = replace(result, r"\bFalse\b" => "false")
    
    return result
end

"""
    parse_concore_payload(s::String) -> Vector{Float64}

Parse a concore protocol payload string into a Julia Float64 vector.
Automatically sanitizes NumPy annotations before parsing.

Examples:
```julia
parse_concore_payload("[0.0, np.float64(1.5), 2.0]")  # => [0.0, 1.5, 2.0]
parse_concore_payload("[1, 2, 3]")                     # => [1.0, 2.0, 3.0]
```
"""
function parse_concore_payload(s::String)::Vector{Float64}
    sanitized = sanitize_numpy_string(strip(s))
    val = eval(Meta.parse(sanitized))
    return Float64.(val)
end

# -----------------------------------------------------------------------------
# Core Data Structures
# -----------------------------------------------------------------------------

"""
    ConcoreNode

Represents a single node in the concore workflow graph.
Uses type-stable Float64 fields for performance.

Fields:
- id: unique node identifier from GraphML
- kp, ki, kd: PID controller gains
- integral: accumulated integral term (state)
- prev_error: previous error for derivative calculation (state)
"""
mutable struct ConcoreNode
    id::String
    # PID gains
    kp::Float64
    ki::Float64
    kd::Float64
    # internal state
    integral::Float64
    prev_error::Float64
end

# convenience constructor with default state
function ConcoreNode(id::String, kp::Float64, ki::Float64, kd::Float64)
    ConcoreNode(id, kp, ki, kd, 0.0, 0.0)
end

"""
    reset!(node::ConcoreNode)

Reset the internal state of a node (integral and prev_error).
"""
function reset!(node::ConcoreNode)
    node.integral = 0.0
    node.prev_error = 0.0
    return node
end

# -----------------------------------------------------------------------------
# GraphML Parsing
# -----------------------------------------------------------------------------

"""
    load_graph(filepath::String) -> Vector{ConcoreNode}

Parse a GraphML file and return a vector of ConcoreNode structs.
Expects nodes with <data key="kp/ki/kd"> child elements.

Example GraphML format:
```xml
<graphml>
  <graph>
    <node id="n1">
      <data key="kp">1.0</data>
      <data key="ki">0.1</data>
      <data key="kd">0.01</data>
    </node>
  </graph>
</graphml>
```
"""
function load_graph(filepath::String)::Vector{ConcoreNode}
    doc = readxml(filepath)
    root = doc.root
    nodes = ConcoreNode[]

    # walk the tree manually to avoid namespace issues
    for graph_elem in eachelement(root)
        if endswith(nodename(graph_elem), "graph") || nodename(graph_elem) == "graph"
            for node_elem in eachelement(graph_elem)
                if endswith(nodename(node_elem), "node") || nodename(node_elem) == "node"
                    id = node_elem["id"]
                    
                    # extract PID params from <data> children
                    kp = parse_data_key(node_elem, "kp", 1.0)
                    ki = parse_data_key(node_elem, "ki", 0.0)
                    kd = parse_data_key(node_elem, "kd", 0.0)
                    
                    push!(nodes, ConcoreNode(id, kp, ki, kd))
                end
            end
        end
    end

    return nodes
end

"""
    parse_data_key(node_elem, key::String, default::Float64) -> Float64

Helper to extract a <data key="..."> value from a node element.
Returns default if not found.
"""
function parse_data_key(node_elem, key::String, default::Float64)::Float64
    for data_elem in eachelement(node_elem)
        if nodename(data_elem) == "data" && haskey(data_elem, "key")
            if data_elem["key"] == key
                return parse(Float64, nodecontent(data_elem))
            end
        end
    end
    return default
end

# -----------------------------------------------------------------------------
# PID Execution
# -----------------------------------------------------------------------------

"""
    execute_step(node::ConcoreNode, error::Float64, dt::Float64=1.0) -> Float64

Perform one PID control step and return the control output.
Updates node's internal state (integral, prev_error).

This mirrors the control loop pattern seen in concore examples:
- Read error (setpoint - measured)
- Compute PID terms
- Write control output
"""
function execute_step(node::ConcoreNode, error::Float64, dt::Float64=1.0)::Float64
    # proportional term
    p_term = node.kp * error
    
    # integral term (accumulate)
    node.integral += error * dt
    i_term = node.ki * node.integral
    
    # derivative term
    d_term = node.kd * (error - node.prev_error) / dt
    node.prev_error = error
    
    # total output
    output = p_term + i_term + d_term
    return output
end

# -----------------------------------------------------------------------------
# File-Based Communication (concore pattern)
# -----------------------------------------------------------------------------

# module-level state (mirrors Python concore's global state)
const STATE = Dict{Symbol, Any}(
    :simtime => 0.0,
    :delay => 0.01,
    :inpath => "./in",
    :outpath => "./out",
    :s => "",
    :olds => "",
    :retrycount => 0
)

"""
    initval(simtime_val::String) -> Vector{Float64}

Initialize from a string like "[0.0, 1.0, 2.0]".
First element is simtime, rest are values.
Mirrors Python concore's initval function.
"""
function initval(simtime_val::String)::Vector{Float64}
    # parse the string as a Julia array literal
    val = eval(Meta.parse(simtime_val))
    STATE[:simtime] = val[1]
    return Float64.(val[2:end])
end

"""
    read_input(port::Int, name::String, initstr::String) -> Vector{Float64}

Read values from a file at inpath/port/name.
Falls back to initstr if file doesn't exist.
Mirrors the file-based communication in concore.
"""
function read_input(port::Int, name::String, initstr::String)::Vector{Float64}
    sleep(STATE[:delay])
    filepath = joinpath(STATE[:inpath], string(port), name)
    
    ins = ""
    try
        ins = read(filepath, String)
    catch
        ins = initstr
    end
    
    # retry if empty
    while isempty(ins)
        sleep(STATE[:delay])
        try
            ins = read(filepath, String)
        catch
            # keep trying
        end
        STATE[:retrycount] += 1
    end
    
    STATE[:s] = string(STATE[:s], ins)
    
    # parse and extract values (skip simtime at index 1)
    val = eval(Meta.parse(ins))
    STATE[:simtime] = max(STATE[:simtime], val[1])
    return Float64.(val[2:end])
end

"""
    write_output(port::Int, name::String, val::Vector{Float64}; delta::Int=0)

Write values to a file at outpath/port/name.
Prepends simtime to the output.
Mirrors the file-based communication in concore.
"""
function write_output(port::Int, name::String, val::Vector{Float64}; delta::Int=0)
    filepath = joinpath(STATE[:outpath], string(port), name)
    
    # ensure directory exists
    mkpath(dirname(filepath))
    
    # format: [simtime+delta, val1, val2, ...]
    outval = vcat(STATE[:simtime] + delta, val)
    
    open(filepath, "w") do f
        write(f, string(outval))
    end
    
    STATE[:simtime] += delta
end

"""
    unchanged() -> Bool

Check if the accumulated read string has changed.
Used in the while-unchanged loop pattern from concore.
"""
function unchanged()::Bool
    if STATE[:olds] == STATE[:s]
        STATE[:s] = ""
        return true
    else
        STATE[:olds] = STATE[:s]
        return false
    end
end

# -----------------------------------------------------------------------------
# File Watching (stub for protocol alignment)
# -----------------------------------------------------------------------------

"""
    watch_and_execute(node::ConcoreNode, watchpath::String; maxsteps::Int=100)

Watch a file for changes and execute the node when triggered.
This is a simplified stub demonstrating the concore file-watching pattern.
"""
function watch_and_execute(node::ConcoreNode, watchpath::String; maxsteps::Int=100)
    println("Watching: $watchpath")
    println("Node $(node.id): kp=$(node.kp), ki=$(node.ki), kd=$(node.kd)")
    
    step = 0
    while step < maxsteps
        # wait for file modification
        event = watch_file(watchpath)
        
        if event.changed
            # read error value from file
            content = read(watchpath, String)
            error_val = parse(Float64, strip(content))
            
            # execute PID step
            output = execute_step(node, error_val)
            
            step += 1
            println("Step $step: error=$error_val -> output=$output")
        end
    end
    
    println("Completed $maxsteps steps")
end

"""
    run_node_loop(node::ConcoreNode, errors::Vector{Float64}) -> Vector{Float64}

Run a node through a sequence of error values and return outputs.
Useful for testing without file I/O.
"""
function run_node_loop(node::ConcoreNode, errors::Vector{Float64})::Vector{Float64}
    outputs = Float64[]
    for e in errors
        u = execute_step(node, e)
        push!(outputs, u)
    end
    return outputs
end

end # module
