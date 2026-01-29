#=
concore_loop_example.jl - Demonstrates concore-style control loop

This example mirrors the typical concore pattern seen in Python/C++:
- Initialize with initval()
- Loop while simtime < maxtime
- Read inputs, process, write outputs
- Use the unchanged() pattern for synchronization
=#

# Activate the parent project
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using Concore

println("=" ^ 60)
println("Concore.jl - Control Loop Example (mirrors Python/C++ pattern)")
println("=" ^ 60)

# --- Setup (similar to Python concore examples) ---

# configure paths and timing
Concore.STATE[:delay] = 0.01
Concore.STATE[:inpath] = "./in"
Concore.STATE[:outpath] = "./out"

maxtime = 10

# initial value strings (concore format: [simtime, val1, val2, ...])
init_simtime_u = "[0.0, 0.0, 0.0]"
init_simtime_ym = "[0.0, 0.0, 0.0]"

# --- Create a simple controller node ---
controller = ConcoreNode("pid_controller", 2.0, 0.5, 0.1)

println("\nController: $(controller.id)")
println("  kp=$(controller.kp), ki=$(controller.ki), kd=$(controller.kd)")

# --- Simulate the control loop (without actual file I/O) ---
println("\n--- Simulating Control Loop ---")
println("(This simulates the concore read/write pattern without files)\n")

# initialize
u = initval(init_simtime_u)
ym = [0.0, 0.0]  # simulated plant output

# setpoint for the control
setpoint = 100.0

println("Setpoint: $setpoint")
println("Initial u: $u")
println()

step = 0
while Concore.STATE[:simtime] < maxtime
    global step += 1
    
    # --- Simulated plant dynamics ---
    # In real concore, this would be: ym = read(port, "ym", init_simtime_ym)
    # Here we simulate: plant output moves toward control input
    ym[1] = ym[1] + 0.3 * (u[1] - ym[1])  # simple first-order response
    
    # --- Controller logic ---
    error = setpoint - ym[1]
    control_output = execute_step(controller, error)
    u[1] = control_output
    
    # advance simtime (normally done by write with delta)
    Concore.STATE[:simtime] += 1
    
    # --- Output ---
    println("Step $step: simtime=$(Int(Concore.STATE[:simtime])), " *
            "ym=$(round(ym[1], digits=2)), " *
            "error=$(round(error, digits=2)), " *
            "u=$(round(u[1], digits=2))")
end

println("\n--- Loop Complete ---")
println("Final plant output: $(round(ym[1], digits=2))")
println("Retry count: $(Concore.STATE[:retrycount])")

# --- Show what file I/O would look like ---
println("\n--- File I/O Demo (creates actual files) ---")

# create test directories
mkpath("./out/1")

# demonstrate write_output (creates file in concore format)
test_values = [42.0, 3.14]
write_output(1, "test_signal", test_values, delta=0)

written_file = "./out/1/test_signal"
if isfile(written_file)
    content = read(written_file, String)
    println("Wrote to $written_file: $content")
end

println("\n" * "=" ^ 60)
println("Example complete!")
println("=" ^ 60)
