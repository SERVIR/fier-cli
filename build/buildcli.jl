using Logging
try
    using PackageCompiler
catch
    @warn "PackageCompiler is not installed, attempting to install"
    using Pkg
    Pkg.add("PackageCompiler")
    using PackageCompiler
end

create_app("..", "fierapp", filter_stdlibs = true)
