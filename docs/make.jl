using Table3Landais
using Documenter

DocMeta.setdocmeta!(Table3Landais, :DocTestSetup, :(using Table3Landais); recursive=true)

makedocs(;
    modules=[Table3Landais],
    authors="Elvin Le Pouhaër <elvin.lepouhaer@gmail.com> and contributors",
    repo="https://github.com/ElvinLP/Table3Landais.jl/blob/{commit}{path}#{line}",
    sitename="Table3Landais.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://ElvinLP.github.io/Table3Landais.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/ElvinLP/Table3Landais.jl",
    devbranch="main",
)
