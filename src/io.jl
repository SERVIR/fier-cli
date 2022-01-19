function read_table(path::AbstractString)

    df = CSV.read(path, DataFrame)

end

function read_tables(
    files::Vector{<:AbstractString},
    dates::Vector{DateTime};
    timecol::AbstractString = "Date",
    datacol::AbstractString = "H",
)

    dfs = DataFrame[]

    for (i, f) in enumerate(files)
        df = read_table(f)
        df_sel = filter_dates(df, dates; timecol = timecol)
        df_sel[!, datacol] = Float64.(df_sel[!, datacol])
        push!(dfs, df_sel)
    end

    return dfs
end

function read_stack(
    path::AbstractString,
    datavar::AbstractString;
    timevar::AbstractString = "time",
    xvar::AbstractString = "lon",
    yvar::AbstractString = "lat",
)

    @info "open"
    ds = NCDataset(path, "r")

    @info "read dates"
    dates = ds[timevar][:]
    torder = sortperm(dates)

    dates = dates[torder]
    @info "read lons"
    lons = ds[xvar][:]
    @info "read lats"
    lats = ds[yvar][:]
    @info "read data var"
    data = ds[datavar][:]

    close(ds)

    return data[:, :, torder], dates, lons, lats
end

function read_config(path::AbstractString)
    config = TOML.parsefile(path)

    return config
end

function write_fits(
    outpath,
    center,
    spatial_modes,
    temporal_modes,
    coeffcients,
    correlations,
    varfrac,
    lons,
    lats,
    dates,
)

    refdate = DateTime("1970-01-01")

    ncdates = @. Dates.value(Day(DateTime(dates) - refdate))

    ds = NCDataset(outpath, "c")

    # set up dimensions
    defDim(ds, "lon", length(lons))
    defDim(ds, "lat", length(lats))
    defDim(ds, "time", length(dates))
    defDim(ds, "mode", size(temporal_modes, 2))
    defDim(ds, "order", size(coeffcients, 1))
    defDim(ds, "trial", size(correlations, 1))

    # create variables in dataset
    x = defVar(
        ds,
        "lon",
        Float32,
        ("lon",),
        attrib = Dict(
            "long_name" => "Longitude",
            "units" => "degrees_east",
            "standard_name" => "longitude",
        ),
    )
    y = defVar(
        ds,
        "lat",
        Float32,
        ("lat",),
        attrib = Dict(
            "long_name" => "Latitude",
            "units" => "degrees_north",
            "standard_name" => "latitude",
        ),
    )
    t = defVar(
        ds,
        "time",
        Int32,
        ("time",),
        attrib = Dict(
            "calendar" => "gregorian",
            "units" => "days since 1970-01-01",
        ),
    )
    sm = defVar(
        ds,
        "spatial_modes",
        Float32,
        ("lon", "lat", "mode"),
        fillvalue = -9999.0,
    )
    ct = defVar(ds, "center", Float32, ("lon", "lat"), fillvalue = -9999.0)
    tm = defVar(ds, "temporal_modes", Float32, ("time", "mode"))
    cv = defVar(ds, "coefficients", Float32, ("order", "mode"))
    cr = defVar(ds, "correlations", Float32, ("trial", "mode"))
    vf = defVar(ds, "variancefraction", Float32, ("mode",))

    # write data to the variables
    x[:] = lons
    y[:] = lats
    t[:] = ncdates
    sm[:] = spatial_modes
    ct[:] = center
    tm[:] = temporal_modes
    cv[:] = coeffcients
    cr[:] = correlations
    vf[:] = varfrac

    close(ds)

end

function read_fit(path::AbstractString,
    timevar::AbstractString = "time",
    xvar::AbstractString = "lon",
    yvar::AbstractString = "lat",
)

    ds = NCDataset(path, "r")

    @info "read dates"
    dates = ds[timevar][:]
    torder = sortperm(dates)

    dates = dates[torder]
    @info "read lons"
    lons = ds[xvar][:]
    @info "read lats"
    lats = ds[yvar][:]
    @info "read data var"
    spatial_modes = ds["spatial_modes"][:]
    temporal_modes = ds["temporal_modes"][:]
    center = ds["center"][:]
    coefficients = ds["coefficients"][:]
    correlations = ds["correlations"][:]

    close(ds)

    return spatial_modes, temporal_modes, center, coefficients, correlations, lons, lats
end

function write_synthesis(outpath,
    data,
    dates,
    lons,
    lats,
)

    refdate = DateTime("1970-01-01")

    ncdates = @. Dates.value(Day(DateTime(dates) - refdate))

    ds = NCDataset(outpath, "c")

    # set up dimensions
    defDim(ds, "lon", length(lons))
    defDim(ds, "lat", length(lats))
    defDim(ds, "time", length(dates))

    # create variables in dataset
    x = defVar(
        ds,
        "lon",
        Float32,
        ("lon",),
        attrib = Dict(
            "long_name" => "Longitude",
            "units" => "degrees_east",
            "standard_name" => "longitude",
        ),
    )
    y = defVar(
        ds,
        "lat",
        Float32,
        ("lat",),
        attrib = Dict(
            "long_name" => "Latitude",
            "units" => "degrees_north",
            "standard_name" => "latitude",
        ),
    )
    t = defVar(
        ds,
        "time",
        Int32,
        ("time",),
        attrib = Dict(
            "calendar" => "gregorian",
            "units" => "days since 1970-01-01",
        ),
    )
    d = defVar(
        ds,
        "synthesis",
        Float32,
        ("lon", "lat", "time"),
        fillvalue = -9999.0,
    )

    # write data to the variables
    x[:] = lons
    y[:] = lats
    t[:] = ncdates
    d[:] = data

    close(ds)

end
