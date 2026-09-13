# SMS++ tap

Homebrew formulae of the [SMS++](https://gitlab.com/smspp/smspp-project)
framework and of the dependency of its stochastic modules that
homebrew-core does not carry:

    brew tap SMSpp-Project/smspp
    brew install smspp

The keg holds the shared library of every module, the CMake configuration that
`find_package(SMS++)` and `find_package(<Module>)` find, and every
command-line tool with its configuration files, its examples and its man page,
under `share/SMS++_tools/<tool>`.

## What the formula builds

| formula | what it is |
| --- | --- |
| `smspp` | the whole framework: the core, its Blocks and Solvers, and the tools |
| `stopt` | StOpt, the stochastic optimization library that SDDPBlock and InvestmentBlock use, with the geners serialization library it carries |

Homebrew installs one keg per formula, so there is no split per module as on
apt and conda: `brew install smspp` gives everything. The parts that are left
out, and why:

- CPLEX, Gurobi and SCIP are not redistributable, so the MILP Solvers come
  with the HiGHS backend alone; a build against the others is still the one of
  the sources;

- `MCFLemonSolver` needs the LEMON graph library, which is neither in
  homebrew-core (whose `lemon` is the parser generator of SQLite) nor packaged
  here yet, since release 1.3.1 wants patching on a recent clang.

## A release

The formula points at the release tarball of the umbrella, so a new release is
the `url`, the `sha256` and, when a module changes its dependencies, the
`depends_on` lines. The commit of FastFlow, which the core would otherwise
fetch while configuring, is pinned here as a resource and is the same one the
vcpkg port and the conda recipe pin.
