#=
basic_example.jl - Concore.jl Prototype Demo

Demonstrates:
1. Loading a GraphML workflow
2. Running PID execution steps
3. Basic concore-style communication pattern
=#

# Activate the parent project
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Concore

println("=" ^ 50)
println("Concore.jl Prototype - Basic Example")
println("=" ^ 50)

# --- 1. Load graph from GraphML ---
println("\n[1] Loading GraphML workflow...")
graph_file = joinpath(@__DIR__, "sample_graph.graphml")
nodes = load_graph(graph_file)

println("Loaded $(length(nodes)) nodes:")
for node in nodes
    println("  - $(node.id): kp=$(node.kp), ki=$(node.ki), kd=$(node.kd)")
end

# --- 2. Run PID execution on controller node ---
println("\n[2] Running PID controller simulation...")
controller = nodes[1]  # the controller node

# simulate a setpoint tracking scenario
# error = setpoint - measured (starts high, should decrease)
errors = [10.0, 8.0, 5.0, 2.0, 0.5, 0.1, -0.2, 0.1, 0.0]

println("Simulating with error sequence: $errors")
println("\nStep | Error  | Output | Integral | Prev Error")
println("-" ^ 50)

for (i, e) in enumerate(errors)
    output = execute_step(controller, e)
    println("  $i  |  $(lpad(e, 5)) |  $(round(output, digits=3)) | $(round(controller.integral, digits=3)) | $(round(controller.prev_error, digits=3))")
end

# --- 3. Test concore-style value initialization ---
println("\n[3] Testing concore communication pattern...")

# this mirrors Python: u = concore.initval("[0.0, 1.0, 2.0]")
init_str = "[0.0, 1.5, 2.5, 3.5]"
values = initval(init_str)
println("initval(\"$init_str\") -> $values")
println("simtime is now: $(Concore.STATE[:simtime])")

# --- 4. Batch execution helper ---
println("\n[4] Batch execution test...")
reset!(controller)  # reset state for fresh run

test_errors = [5.0, 4.0, 3.0, 2.0, 1.0]
outputs = run_node_loop(controller, test_errors)

println("Inputs:  $test_errors")
println("Outputs: $(round.(outputs, digits=3))")

println("\n" * "=" ^ 50)
println("Prototype demo complete!")
println("=" ^ 50)
