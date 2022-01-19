
function reof(
    array::AbstractArray{<:Any,3};
    nmodes = nothing,
    maxrotations::Int = 50,
    nsims::Int = 10,
)

    eof = EmpiricalOrthogonalFunction(array)

    if isnothing(nmodes)
        centered = eof.dataset[:, eof.valididx]
        eigenvals = eigenvalues(eof)
        sigmodes = montecarlo_significance(centered, eigenvals; nsims = nsims)
        nmodes = max(sigmodes...)
    end

    reof = orthorotation(eof, n = nmodes)

    temporal_modes = convert(Array{Float32}, pcs(reof))
    spatial_modes = reshape(eofs(reof), (size(array)[1:2]..., nmodes))
    center = reshape(eof.center, size(array)[1:2])

    varfrac = variancefraction(reof)

    return center, spatial_modes, temporal_modes, varfrac
end

function montecarlo_significance(
    centered::AbstractArray{<:Any,2},
    eigenvals::AbstractArray{<:Any,1};
    nsims::Int = 10,
)
    nt = length(eigenvals)

    norm = nt - 1
    mc_lamb = zeros(Float64, nt, nsims)

    obstemp = deepcopy(centered)

    @simd for i = 1:nsims
        # ----- Randomize the observation (space-wise randomization)
        @threads for j = 1:size(obstemp, 1)
            seed = now().instant.periods.value
            rng = MersenneTwister(seed)
            shuffle!(rng, @view obstemp[i, :])
        end

        # run eof to get eigen vales of randomized (in space) observations
        rnd_eof = EmpiricalOrthogonalFunction(obstemp)

        mc_lamb[:, i] = eigenvalues(rnd_eof)
    end

    mean_mc_lamb = Statistics.mean(mc_lamb, dims = 2)
    std_mc_lamb = Statistics.std(mc_lamb, dims = 2)

    eigengt = eigenvals .> mean_mc_lamb

    sig_modes = findall(eigengt[:, 1])

    return sig_modes
end

function filter_dates(
    df::DataFrame,
    dates::Vector{DateTime};
    timecol::AbstractString = "Date",
)
    # TODO: check to make sure that dates range is within df[:,"datetime"] range
    # produces inconsistent results if not ... not sure why...
    mask = sum(map(x -> x .== df[:, timecol], dates), dims = 1)[1]
    indices = findall(!iszero, mask)

    df[indices, :]
end

function fitmodes(
    temporal_modes::AbstractArray{<:Real,2},
    dfs::Vector{DataFrame};
    datacol::AbstractString = "H",
    removeoutliers::Bool = true,
)

    nmodes = size(temporal_modes, 2)
    cormat = zeros(length(dfs), nmodes)
    outcoeffs = zeros(3, nmodes)

    @inbounds for i = 1:nmodes
        models = Polynomial[]

        @inbounds for (j, df) in enumerate(dfs)
            x = df[!, datacol]
            if removeoutliers
                x_z = StatsBase.zscore(x)
                idx = findall(x -> abs(x) <= 3.0, x_z)
            else
                idx = findall(x -> !ismissing(x), x_z)
            end

            @views cormat[j, i] = cor(x[idx], temporal_modes[idx, i])

            @views model = Polynomials.fit(x[idx], temporal_modes[idx, i], 2)

            push!(models, model)
        end

        m, best_idx = findmax(abs.(cormat[:, i]))
        best_model = models[best_idx]

        outcoeffs[:, i] = coeffs(best_model)
    end

    return outcoeffs, cormat
end
