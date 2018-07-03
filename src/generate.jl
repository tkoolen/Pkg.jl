generate(path::String; kwargs...) = generate(Context(), path; kwargs...)
function generate(ctx::Context, path::String; kwargs...)
    Context!(ctx; kwargs...)
    ctx.preview && preview_info()
    dir, pkg = dirname(path), basename(path)
    isdir(path) && cmderror("$(abspath(path)) already exists")
    printstyled("Generating"; color=:green, bold=true)
    print(" project $pkg:\n")
    project(pkg, dir; preview=ctx.preview)
    entrypoint(pkg, dir; preview=ctx.preview)
    ctx.preview && preview_info()
    return
end

function genfile(f::Function, pkg::String, dir::String, file::String; preview::Bool)
    path = joinpath(dir, pkg, file)
    println(stdout, "    $path")
    preview && return
    mkpath(dirname(path))
    open(f, path, "w")
    return
end

function project(pkg::String, dir::String; preview::Bool)
    name = email = nothing
    gitname = LibGit2.getconfig("user.name", "")
    isempty(gitname) || (name = gitname)
    gitmail = LibGit2.getconfig("user.email", "")
    isempty(gitmail) || (email = gitmail)

    if name == nothing
        for env in ["GIT_AUTHOR_NAME", "GIT_COMMITTER_NAME", "USER", "USERNAME", "NAME"]
            name = get(ENV, env, nothing)
            name != nothing && break
        end
    end

    if name == nothing
        cmderror("could not determine user, please set ", Sys.iswindows() ? "USERNAME" : "USER",
                 " environment variable")
    end

    if email == nothing
        for env in ["GIT_AUTHOR_EMAIL", "GIT_COMMITTER_EMAIL", "EMAIL"];
            email = get(ENV, env, nothing)
            email != nothing && break
        end
    end

    authorstr = "[\"$name " * (email == nothing ? "" : "<$email>") * "\"]"

    genfile(pkg, dir, "Project.toml"; preview=preview) do io
        print(io,
            """
            authors = $authorstr
            name = "$pkg"
            uuid = "$(UUIDs.uuid1())"
            version = "0.1.0"

            [deps]
            """
        )
    end
end

function entrypoint(pkg::String, dir; preview::Bool)
    genfile(pkg, dir, "src/$pkg.jl"; preview=preview) do io
        print(io,
           """
            module $pkg

            greet() = print("Hello World!")

            end # module
            """
        )
    end
end


function tests(pkg::AbstractString; force::Bool=false)
    pkg_name = basename(pkg)
    genfile(pkg,"test/runtests.jl", force) do io
        print(io, """
        using $pkg_name
        using Test

        # write your own tests here
        @test 1 == 2
        """)
    end
end

function travis(pkg::AbstractString; force::Bool=false, coverage::Bool=true)
    pkg_name = basename(pkg)
    c = coverage ? "" : "#"
    vf = versionfloor(VERSION)
    if vf[end] == '-' # don't know what previous release was
        vf = string(VERSION.major, '.', VERSION.minor)
        release = "#  - $vf"
    else
        release = "  - $vf"
    end
    genfile(pkg,".travis.yml",force) do io
        print(io, """
        ## Documentation: http://docs.travis-ci.com/user/languages/julia/
        language: julia
        os:
          - linux
          - osx
        julia:
        $release
          - nightly
        notifications:
          email: false
        ## uncomment to set environment variables
        #env:
        #   - JULIA_PROJECT="@."
        #matrix:
        #  allow_failures:
        #  - julia: nightly
        ## uncomment and modify the following lines to manually install system packages
        #addons:
        #  apt: # apt-get for linux
        #    packages:
        #    - gfortran
        #before_script: # homebrew for mac
        #  - if [ \$TRAVIS_OS_NAME = osx ]; then brew install gcc; fi
        ## uncomment the following lines to override the default test script
        #script:
        #  - julia -e 'import Pkg; Pkg.build(); Pkg.test(; coverage=true)'
        $(c)after_success:
        $(c)  # push coverage results to Coveralls
        $(c)  - julia -e 'import Pkg; Pkg.add("Coverage"); using Coverage; Coveralls.submit(Coveralls.process_folder())'
        $(c)  # push coverage results to Codecov
        $(c)  - julia -e 'import Pkg; Pkg.add("Coverage"); using Coverage; Codecov.submit(Codecov.process_folder())'
        """)
    end
end


function appveyor(pkg::AbstractString; force::Bool=false)
    pkg_name = basename(pkg)
    vf = versionfloor(VERSION)
    if vf[end] == '-' # don't know what previous release was
        vf = string(VERSION.major, '.', VERSION.minor)
        rel32 = "#  - JULIA_URL: \"https://julialang-s3.julialang.org/bin/winnt/x86/$vf/julia-$vf-latest-win32.exe\""
        rel64 = "#  - JULIA_URL: \"https://julialang-s3.julialang.org/bin/winnt/x64/$vf/julia-$vf-latest-win64.exe\""
    else
        rel32 = "  - JULIA_URL: \"https://julialang-s3.julialang.org/bin/winnt/x86/$vf/julia-$vf-latest-win32.exe\""
        rel64 = "  - JULIA_URL: \"https://julialang-s3.julialang.org/bin/winnt/x64/$vf/julia-$vf-latest-win64.exe\""
    end
    genfile(pkg,"appveyor.yml",force) do io
        print(io, """
        environment:
          matrix:
        $rel32
        $rel64
          - JULIA_URL: "https://julialangnightlies-s3.julialang.org/bin/winnt/x86/julia-latest-win32.exe"
          - JULIA_URL: "https://julialangnightlies-s3.julialang.org/bin/winnt/x64/julia-latest-win64.exe"
        ## uncomment the following lines to allow failures on nightly julia
        ## (tests will run but not make your overall status red)
        #matrix:
        #  allow_failures:
        #  - JULIA_URL: "https://julialangnightlies-s3.julialang.org/bin/winnt/x86/julia-latest-win32.exe"
        #  - JULIA_URL: "https://julialangnightlies-s3.julialang.org/bin/winnt/x64/julia-latest-win64.exe"
        branches:
          only:
            - master
            - /release-.*/
        notifications:
          - provider: Email
            on_build_success: false
            on_build_failure: false
            on_build_status_changed: false
        install:
          - ps: "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12"
        # If there's a newer build queued for the same PR, cancel this one
          - ps: if (\$env:APPVEYOR_PULL_REQUEST_NUMBER -and \$env:APPVEYOR_BUILD_NUMBER -ne ((Invoke-RestMethod `
                https://ci.appveyor.com/api/projects/\$env:APPVEYOR_ACCOUNT_NAME/\$env:APPVEYOR_PROJECT_SLUG/history?recordsNumber=50).builds | `
                Where-Object pullRequestId -eq \$env:APPVEYOR_PULL_REQUEST_NUMBER)[0].buildNumber) { `
                throw "There are newer queued builds for this pull request, failing early." }
        # Download most recent Julia Windows binary
          - ps: (new-object net.webclient).DownloadFile(
                \$env:JULIA_URL,
                "C:\\projects\\julia-binary.exe")
        # Run installer silently, output to C:\\projects\\julia
          - C:\\projects\\julia-binary.exe /S /D=C:\\projects\\julia
        build_script:
          - C:\\projects\\julia\\bin\\julia -e "
              import InteractiveUtils; versioninfo();
              Pkg.build()"
        test_script:
          - C:\\projects\\julia\\bin\\julia -e "Pkg.test(\\"$pkg_name\\")"
        """)
    end
end

function gitignore(pkg::AbstractString; force::Bool=false)
    genfile(pkg,".gitignore",force) do io
        print(io, """
        *.jl.cov
        *.jl.*.cov
        *.jl.mem
        Manifest.toml
        deps/build.log
        """)
    end
end

