using ArgParse
using EarthEngine
using EarthEngineREST
using ProgressMeter
using NCDatasets
using Dates
using ArgParse

Initialize(opt_url="https://earthengine-highvolume.googleapis.com")

function persist_stack(outpath, stack, lons, lats, dates)
   ds = NCDataset(outpath, "c", attrib=Dict(
        "title" => "Sentinel-1 Observation Time Series",
        "history" => "date_created: $(now(Dates.UTC))+00:00",
    ))

   defDim(ds,"lon",length(lons))
   defDim(ds,"lat",length(lats))
   defDim(ds,"time",length(dates))

   v = defVar(ds, "VV", Float32, ("lon", "lat", "time"), fillvalue = -9999.,attrib = Dict(
      "long_name" => "SAR VV Backscatter",
      "units" => "dB"
   ))
   v[:,:,:] = stack[:,end:-1:1,:]

   lon = defVar(ds, "lon", Float32,("lon",),
      attrib = Dict(
         "long_name" => "Longitude",
         "units" => "degrees_east",
         "standard_name" => "longitude"
      )
   )
   lon[:] = lons[:]

   lat = defVar(ds, "lat", Float32,("lat",),
      attrib = Dict(
         "long_name" => "Latitude",
         "units" => "degrees_north",
         "standard_name" => "latitude"
      )
   )
   lat[:] = lats[:]

   time = defVar(ds, "time", Int64, ("time",),
      attrib = Dict(
         "calendar" => "gregorian",
         "units" => "days since 1970-01-01"
      )
   )
   time[:] = dates[:]

   close(ds)
end

function input_data(pt,secretkey,outfile;resolution::Float64=0.0015, basinlvl::Int=7, ascending::Bool=true)

   session = EESession(secretkey)
   # Initialize(session)

   point = Point(pt...)
   basins = filterBounds(EE.FeatureCollection("WWF/HydroSHEDS/v1/Basins/hybas_$basinlvl"), point);
   basin_geo = geometry(basins)

   basinmask = mask(reduceToImage(basins,["HYBAS_ID"],firstNonNull()))

   jrc = toFloat(unmask(select(EE.Image("JRC/GSW1_2/GlobalSurfaceWater"), "occurrence"),0)) / 100
   permanentwater = jrc < 0.8

   hand = select(EE.Image("MERIT/Hydro/v1_0_1"), "hnd")
   handmask = hand < 15

   path = ascending ? "ASCENDING" : "DESCENDING"

   scenes = filter(
      filterBounds(EE.ImageCollection("COPERNICUS/S1_GRD"), basins),
      And(
         eq(EE.Filter(),"orbitProperties_pass", path),
         eq(EE.Filter(),"instrumentMode", "IW"),
      )
   )

   # aoi = geometry(EE.Image(get(toList(scenes,2),1)));
   aoi = basin_geo

   pixelgrid = PixelGrid(session, aoi, resolution, "EPSG:4326")

   eedates = distinct(
      map(
         aggregate_array(
            filterDate(scenes, "2015-01-01", "2021-01-01"),
            "system:time_start"
         ),
         @eefunc x -> format(EE.Date(x),"YYYY-MM-dd") EE.ComputedObject
      )
   )

   dates = computevalue(session,eedates)

   datesp = s1_date_pairs(dates)

   eedatesp = EE.List(datesp)

   function aggs1(date::EE.ComputedObject)
      t1 = EE.Date(date)
      t2 = advance(date, 1, "day")
      comp = filterDate(scenes,t1,t2)
      # return updateMask(mosaic(comp), And(permanentwater, handmask))
      return updateMask(mosaic(comp), And(permanentwater,basinmask))
   end

   # functions to process the sentinel series into something usable by fier
   # aggregate the data by to prevent swath seams
   function sq_agg(i)
       i = EE.List(i)
       x = set(mean(filterDate(scenes, get(i,0),get(i,1))),"system:time_start",millis(EE.Date(get(i,0))))
       return updateMask(float(x), And(permanentwater,basinmask))
   end

   imglist = map(eedatesp, @eefunc sq_agg EE.ComputedObject)

   # nimgs = computevalue(session, size(imglist))
   nimgs = computevalue(session,size(imglist))
   x_size = pixelgrid.dimensions.width
   y_size = pixelgrid.dimensions.height

   stack = Array{Union{Missing, Float64}, 3}(undef, x_size, y_size, nimgs);
   slice = Array{Union{Missing,Float64}, 3}(undef, x_size, y_size, 1);

   @showprogress for i in 1:nimgs
      img = unmask(get(imglist,i-1),999)
      slice[:,:,:] = computepixels(session, pixelgrid, img, ["VV",])[:,:,:]
      slice[findall(slice .>= 999)] .= missing
      stack[:,:,i] = slice[:,:,1]
   end

   lons,lats = EarthEngineREST.extract_gridcoordinates(pixelgrid)

   basedate = DateTime("1970-01-01")

   finaldates = map(x -> x[1], datesp)

   ncdates = @. Dates.value(Day(DateTime(finaldates) - basedate))

   persist_stack(outfile, stack, lons, lats, ncdates)

   return

end

# look at adjacent swaths within aoi and aggregate
function s1_date_pairs(d)
    d = sort(d)
    n = length(d)
    i = 1
    date_pairs = []
    while i < n
        j=1
        t1 = DateTime(d[i])
        t2 = DateTime(d[i+1])
        daydiff = Day(t2-t1)
        if (Dates.value(daydiff % 6) != 0) & (i+1<n)
            still_looking = true
            while still_looking
                t2_ = DateTime(d[i+j])
                daydiff_ = Day(t2_-t1)
                if (Dates.value(daydiff_ % 6) != 0)
                    j+=1
                else
                    still_looking = false
               end
            end
            push!(date_pairs,(d[i],d[i+j]))
            i = i + j
        elseif i+1 > n
            push!(date_pairs, (d[i],Dates.format(t2+Day(1),"YYYY-mm-dd")))
            i+=1
        else
            push!(date_pairs,(d[i],d[i+1]))
            i += 1
         end
   end

   return date_pairs
end

function parse_commandline()
   s = ArgParseSettings(
      description = "Forecasting of Inundation Extents using REOF (FIER) Command Line Application",
      add_version = true,
      version = @project_version
   )

   @add_arg_table s begin
      "--point", "-p"
         nargs = 2
         arg_type = Float64
         help = "point to intersect with watersheds. formatted at x y"
         required = true

      "--secretkey", "-k"
         arg_type = String
         help = "toml file specifying the configuration for command"
         required = true

      "--outfile", "-o"
         arg_type = String
         help = "output file path"
         required = true

      "--resolution"
         arg_type = Float64
         help = "resolution to request and store data"
         default = 0.001

      "--basinlvl"
         arg_type = Int64
         help = "resolution of basin information to query"
         default = 7

      "--ascending"
         arg_type = Bool
         help = "boolean argument to processes ascending or descending orbit"
         default = true
   end

   return parse_args(s)
end

function main()
   args = parse_commandline()
   println(args)
   input_data(
      args["point"],
      args["secretkey"],
      args["outfile"];
      resolution=args["resolution"],
      basinlvl=args["basinlvl"],
      ascending=args["ascending"]
   )
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
