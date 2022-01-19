
function buildregressions(config::Dict{<:Any,<:Any})

    @info config


    # extract out the information on reading observation
    obspath = config["observations"]["path"]
    datavar = config["observations"]["datavar"]
    timevar = config["observations"]["timevar"]
    yvar = config["observations"]["yvar"]
    xvar = config["observations"]["xvar"]

    # extract out the information on hydrologic info for regressions
    intables = config["tables"]["paths"]
    datacol = config["tables"]["datacol"]
    timecol = config["tables"]["timecol"]

    # extract out output location for regression
    outpath = config["output"]["path"]

    # extract processing options if any
    if "options" in keys(config)
        optkeys = keys(config["options"])

        nmodes = "nmodes" in optkeys ? config["options"]["nmodes"] : nothing

        removeoutliers =
            "removeoutliers" in optkeys ? config["options"]["removeoutliers"] :
            false

        nsims = "nsimulations" in optkeys ? config["options"]["nsimulations"] : 10

    end

    # read in the space-time data
    @info "Reading observation data"
    datain, dates, lons, lats = read_stack(
        obspath,
        datavar;
        timevar = timevar,
        xvar = xvar,
        yvar = yvar,
    )

    # read in the data tables
    @info "Reading table data"
    dfs = read_tables(intables, dates; timecol = timecol, datacol = datacol)

    # calculate the eof and apply rotations
    @info "EOF calculation"
    @info "using $nmodes modes"
    @info "using $nsims simulations"
    center, spatial_modes, temporal_modes, varfrac = reof(datain; nmodes = nmodes, nsims = nsims)

    @info "finding coefficients"
    coeffcients, correlations = fitmodes(
        temporal_modes,
        dfs;
        datacol = datacol,
        removeoutliers = removeoutliers,
    )

    @info "writing regressions"
    write_fits(
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

    return 0

end

function synthesize(config::Dict{<:Any,<:Any})

    @info config

    # extract out the information on reading observation
    fitpath = config["fit"]["path"]
    timevar = config["fit"]["timevar"]
    yvar = config["fit"]["yvar"]
    xvar = config["fit"]["xvar"]

    # extract out the information on hydrologic info for synthesis
    intables = config["tables"]["paths"]
    datacol = config["tables"]["datacol"]
    timecol = config["tables"]["timecol"]

    # extract out output location for synthesis
    outpath = config["output"]["path"]
    starttime = config["output"]["starttime"]
    endtime = config["output"]["endtime"]

    # extract processing options if any
    if "options" in keys(config)
        optkeys = keys(config["options"])

        corthresh = "corthresh" in optkeys ? config["options"]["corthresh"] : 0.6

    end

    #extract out the data stored from the fit process
    spatial_modes, temporal_modes, center, coefficients, correlations, lons, lats =
        read_fit(fitpath)

    # create date information
    dates = collect(DateTime(starttime):Day(1):DateTime(endtime))

    # read in the data tables
    @info "Reading table data"
    dfs = read_tables(intables, dates; timecol = timecol, datacol = datacol)

    # extract out the values from the dataframes
    xvals = zeros(length(dfs), size(dfs[1], 1))
    for i = 1:length(dfs)
        xvals[i, :] = dfs[i][!, datacol]
    end

    @info "applying synthesis"
    synthesis = synth(
        spatial_modes,
        temporal_modes,
        center,
        xvals,
        coefficients,
        correlations,
        corthresh = corthresh,
    )

    # watermaps = extractwater(synth)

    @info "writing file"
    write_synthesis(
        outpath,
        synthesis,
        dates,
        lons,
        lats,
    )

end
