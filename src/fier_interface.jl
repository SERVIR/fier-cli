
function buildregressions(config::Dict{<:Any,<:Any})

    # @info config


    # extract out the information on reading observation
    obspath = config["input"]["path"]
    datavar = config["input"]["datavar"]
    timevar = config["input"]["timevar"]
    yvar = config["input"]["yvar"]
    xvar = config["input"]["xvar"]

    if "geoglows" in keys(config)
        ingeoglows = config["geoglows"]["path"]
        rivids = config["geoglows"]["rivids"]
        datacol = "Q"
        timecol = "Date"
    elseif "tables" in keys(config)
        # extract out the information on hydrologic info for regressions
        intables = config["tables"]["paths"]
        datacol = config["tables"]["datacol"]
        timecol = config["tables"]["timecol"]
    else
        @error "table inputs or geoglows inputs must be specified"
        return
    end

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

    if "geoglows" in keys(config)
        @info "reading geoglows outputs"
        dfs = read_geoglows(ingeoglows, rivids, dates)
    else
        # read in the data tables
        @info "Reading table data"
        dfs = read_tables(intables, dates; timecol = timecol, datacol = datacol)
    end

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
    fitpath = config["input"]["path"]
    timevar = config["input"]["timevar"]
    yvar = config["input"]["yvar"]
    xvar = config["input"]["xvar"]

    # extract out the information on hydrologic info for synthesis
    intables = config["tables"]["paths"]
    datacol = config["tables"]["datacol"]
    timecol = config["tables"]["timecol"]

    # extract out output location for synthesis
    outpath = config["output"]["path"]

    if "dates" in keys(config["output"])
        dates = DateTime.(config["output"]["dates"])
    elseif "daterange" in keys(config["output"])
        drange = config["output"]["daterange"]
        starttime = drange[1]
        endtime = drange[2]
        # create date information
        dates = collect(DateTime(starttime):Day(1):DateTime(endtime))
    else
        @error "'daterange' or 'dates' values could not be parsed"
        return
    end

    # extract processing options if any
    if "options" in keys(config)
        optkeys = keys(config["options"])

        corthresh = "corthresh" in optkeys ? config["options"]["corthresh"] : 0.6
        procwater = "water" in optkeys ? config["options"]["water"] : true

    end

    #extract out the data stored from the fit process
    spatial_modes, temporal_modes, center, coefficients, correlations, vars, lons, lats =
        read_fit(fitpath)



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
        vars;
        corthresh = corthresh,
    )

    if procwater
        @info "segmenting water"
        water=zeros(Union{Missing,Bool}, size(synthesis));
        @inbounds for i in 1:size(synthesis,3)[1]
            water[:,:,i] = extractwater(synthesis[:,:,i],init_thresh=-16)
        end
    else
        water = nothing
    end

    # watermaps = extractwater(synth)

    @info "writing file"
    write_synthesis(
        outpath,
        synthesis,
        dates,
        lons,
        lats;
        water=water
    )

end
