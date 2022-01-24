# FIER Configuration Files

The different options and data setup for running FIER is defined using configuration files. The configuration files for different subcommands follow similar patterns but have different options and required fields for extracting/setting up the commands.

## `buildregressions`

An example of a configuration file for the `buildregressions` command can be found on the Github repo: [Regression config example](https://github.com/SERVIR/fier-cli/blob/main/test/test_regression_config.toml)

### [input]

The inputs section defines the input netCDF file and structure of dimensions to extract data. The time dimension in the input file is used to select data from other time series.

* `path` : Full path to netCDF file of space-time observations to extract signals from
* `timevar` : variable name for time dimension in netCDF file
* `xvar` : variable name for x coordinate dimension in netCDF file
* `yvar` : variable name for y coordinate in netCDF file
* `datavar` : variable name for data to use in netCDF file

#### Example

```
[input]
path = "~/fier/inputs/sentinel1_timeseries.nc"
timevar = "time"
xvar = "lon"
yvar = "lat"
datavar = "VV"
```

### [tables]

The tables section allows users to specifies multiple series of inputs in tabular format to correlate with the temporal modes derived from the input data. Currently only CSV file format is supported for reading tables.

* `paths` : List of full paths to CSV files to use for building regressions
* `timecol` : Column name specifying time (time column should be formatted as YYYY-MM-dd)
* `datacol` : Column name of of variable to use in regressions

#### Example

```
[tables]
paths = [
    "~/fier/inputs/DailyAveH_KH-020101_manual.csv",
    "~/fier/inputs/DailyAveH_KH-020102_manual.csv",
]
timecol = "Date"
datacol = "H"
```

### [geoglows]

The [GEOGloWS streamflow service](https://geoglows.ecmwf.int/) provides modeled streamflow for every reach across the globe. This section provides users with the capability to read in the netCDF files from the service and use to build regressions.

* `paths` : Full path to GEOGloWS netCDF file
* `rivids` : List of river ID values to extract and build regressions from

#### Example

```
[geoglows]
path = "~/fier/inputs/Qout_era5_t640_24hr_19790101to20210630.nc"
rivids = [
    5074949,
    5075705,
]
```

### [output]
The output section defines where the output file should be written to. This section has one field:

* `path`: Full path to write output to

#### Example

```
[output]
path = "~/fier/outputs/reof_regressions.nc"
```

### [options]

These are optional configuration parameters that a user can specify. If no options are provided then the program will use defaults. A list of options are as follows:

* `nsimulations` : number of Monte Carlo iterations to test for significant modes in REOF analysis. Default = 10
* `nmodes` : number of modes to select from REOF analysis. Providing this option will supersedes `nsimulations`. Default = nothing
* `removeoutliers` : remove outliers from tables/geoglows inputs before calculating regression coeffcients. Default = true

#### Example

```
[options]
nsimulations = 10
removeoutliers = true
```

## `synthesis`

An example of a configuration file for the `synthesis` command can be found on the Github repo: [Synthesis config example](https://github.com/SERVIR/fier-cli/blob/main/test/test_synthesis_config.toml)


### [input]

#### Example

```
[input]
path = "~/fier/outputs/reof_regressions.nc"
timevar = "time"
xvar = "lon"
yvar ="lat"
```

### [tables]

The tables section is used to specify the multiple series of inputs in tabular format to apply the regression equations to for synthesizing data. **NOTE:** *the order of tables should be the same as what was provided to `buildregressions`*. Currently only CSV file format is supported for reading tables.

* `paths` : List of full paths to CSV files to use for building regressions
* `timecol` : Column name specifying time (time column should be formatted as YYYY-MM-dd)
* `datacol` : Column name of of variable to use in regressions

#### Example

```
[tables]
paths = [
    "~/fier/inputs/DailyAveH_KH-020101_manual.csv",
    "~/fier/inputs/DailyAveH_KH-020102_manual.csv",
]
timecol = "Date"
datacol = "H"
```

### [geoglows]

This allows users to use GEOGloWS netCDF files for synthesizing data. **NOTE:** *the order of river IDs should be the same as what was provided to `buildregressions`*.

* `paths` : Full path to GEOGloWS netCDF file
* `rivids` : List of river ID values to extract and use in regressions

#### Example

```
[geoglows]
path = "~/fier/inputs/Qout_era5_t640_24hr_19790101to20210630.nc"
rivids = [
    5074949,
    5075705,
]
```

### [output]

* `path` : Full path to write output to
* `daterange` : List specifying start time and end time to synthesize data
* `dates` : List of dates to synthesize. This supersedes `daterange`

#### Example

```
[output]
path = "~/fier/outputs/reof_synthesis.nc"
daterange = ["2019-01-01","2019-12-31"]
```

### [options]

* `corthresh` : correlation threshold used to filter out weakly correlated modes. NOTE: uses absolute correlation. Default = 0.6
* `water` : segment water from synthesized data and write to output. Uses methods from [Markert et al., 2020](https://doi.org/10.3390/rs12152469) for segmenting water. Default = true

#### Example

```
[options]
corthresh = 0.6
water = true
```
