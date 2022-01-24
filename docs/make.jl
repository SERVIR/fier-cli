push!(LOAD_PATH, "../src/")

using fier, Documenter

pages = [
    "Home" => "index.md",
    "Usage" => "usage.md",
    "Configuration" => "config.md"
]

makedocs(;
    modules = [fier],
    authors = "Kel Markert",
    repo = "https://github.com/SERVIR/fier-cli/blob/{commit}{path}#L{line}",
    sitename = "FIER CLI",
    pages = pages,
)

deploydocs(;
    repo = "github.com/SERVIR/fier-cli.git",
    devbranch = "main",
)
