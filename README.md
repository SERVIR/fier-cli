# fier-cli
Command line interface for running the Forecasting of Inundation Extents using REOF process

## Installation

This software is written using the [Julia language](https://julialang.org/), thus Julia needs to be installed for use (it is recommended to use the [official binaries](https://julialang.org/downloads/)). No other dependencies are required, the build script illustrated below installs all of the necessary packages and dependencies.

```
git clone https://github.com/servir/fier-cli.git

cd fier-cli/build/

julia --color=yes buildcli.jl
```
After running `buildcli.jl` there will be some output to the console and a directory called "fierapp" in the build directory.

At this time, we do not distribute pre-built bundles of the `fier-cli` due to the size of the compiled application. This is due to the FIER application being build with the MKL backend for BLAS/LinearAlgebra which results in a larger package (>2GB) but faster runtimes for the computationally intensive operations.

### Compatiability

This software has been built and tested using the following platforms and Julia versions:

| Operating System | OS Version | Julia Version        |
| ---------------- | ---------- | -------------------- |
| MacOS            | 11.6       | v1.6.4 <br/> v1.7.0  |
| Windows          | 10         | v1.X.X        |
| Linux            | tbd        | tbd        |

Please note that this software is free/open source and comes with no guarantees, expressed or implied, as to suitability, completeness, accuracy, and whatever other claims. If there is an bug or suggestion with the application, please [submit an issue on GitHub](https://github.com/SERVIR/fier-cli/issues) and we will try to address as quickly as possible.

## Usage

After the build script is run, there you can see three folders in the "fierapp" directory. The only file that is directly used is `bin/fier`. All three folders need to stay together though because the program relies on the others.


```
./fierapp/bin/fier -h

usage: <PROGRAM> -c CONFIG [--verbose] [--version] [-h] subcommand

Forecasting of Inundation Extents using REOF (FIER) Command Line
Application

positional arguments:
  subcommand           which operation to run, options are
                       'buildregressions', 'synthesis'

optional arguments:
  -c, --config CONFIG  toml file specifying the configuration for
                       command
  --verbose            flag to set the process to print info
  --version            show version information and exit
  -h, --help           show this help message and exit
```

See the documentation on detailed information on how to structure the configuration files and run the different processes.
