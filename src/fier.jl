module fier

using ArgParse
using Base.Threads
using CSV
using DataFrames
using Dates
using EmpiricalOrthogonalFunctions
using LinearAlgebra
using Logging
using MKL
using NCDatasets
using Statistics
using StatsBase
using Polynomials
using Random
using TOML

include("io.jl")
include("reof_fitting.jl")
include("synthesis.jl")
include("fier_interface.jl")

function julia_main()::Cint
    try
        real_main()
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

function real_main()
    args = parse_commandline()

    # unpack the command line arguments
    inconfig = args["config"]

    if !isfile(inconfig)
        @error("could not find file $inconfig")
        return
    else
        config = read_config(inconfig)
    end

    # set the BLAS backend to use as many threads as julia process
    BLAS.set_num_threads(nthreads())

    if !args["verbose"]
        Logging.disable_logging(Logging.Info)
    else
        # Run information
        @info "Logging set to info"
        @info "Using $(Threads.nthreads()) threads"
    end

    if args["subcommand"] == "synthesis"
        @info "Running subcommand $(args["subcommand"])"

        synthesize(config)

    elseif args["subcommand"] == "buildregressions"
        @info "Running subcommand $(args["subcommand"])"

        buildregressions(config)

    else
        @error(
            "Could not understand subcommand argument, " *
            "options are 'buildregressions', 'synthesis'"
        )
        return
    end

    return
end

function parse_commandline()
    s = ArgParseSettings(
        description = "Forecasting of Inundation Extents using REOF (FIER) Command Line Application",
        add_version = true,
        version = @project_version
    )

    @add_arg_table s begin
        "subcommand"
        help = "which operation to run, options are 'buildregressions', 'synthesis'"
        required = true

        "--config", "-c"
        arg_type = String
        help = "toml file specifying the configuration for command"
        required = true

        "--verbose"
        help = "flag to set the process to print info"
        action = :store_true

    end

    return parse_args(s)
end

if abspath(PROGRAM_FILE) == @__FILE__
    real_main()
end

end # module
