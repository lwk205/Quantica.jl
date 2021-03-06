# Quantica.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://pablosanjose.github.io/Quantica.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://pablosanjose.github.io/Quantica.jl/dev)
[![Build Status](https://github.com/pablosanjose/Quantica.jl/workflows/CI/badge.svg)](https://github.com/pablosanjose/Quantica.jl/actions)
[![Coverage](https://codecov.io/gh/pablosanjose/Quantica.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/pablosanjose/Quantica.jl)
[![GitHub commits since last release](https://img.shields.io/github/commits-since/pablosanjose/Quantica.jl/latest?include_prereleases&sort=semver&style=social)](https://github.com/pablosanjose/Quantica.jl)

The Quantica.jl package provides an expressive API to build arbitrary quantum systems on a discrete lattice, and to compute a number of their properties.

# Some current features

- Build Hamiltonians on discrete lattices of arbitrary dimensions, using tight-binding models with arbitrary number of orbitals
- Compute band structures of periodic systems and extract individual bands by interpolation
- Compute electronic structures and expectation values using Kernel Polynomial methods

# Exported API
- `lattice`, `sublat`: build lattices
- `hopping`, `onsite`, `siteselector`, `hopselector`, `nrange`, `not`: build tightbinding models
- `hamiltonian`: build a Hamiltonian from tightbinding model and a lattice
- `bloch`, `bloch!`, `similarmatrix`: build the Bloch matrix of a Hamiltonian
- `parametric`, `@onsite!`, `@hopping!`, `parameters`: build a parametric Hamiltonian
- `dims`, `sitepositions`, `siteindices`, `bravais`: inspect lattices and Hamiltonians
- `supercell`, `unitcell`, `wrap`, `transform!`, `combine`: build derived lattices or Hamiltonians
- `flatten`, `unflatten`, `orbitalstructure`: operate with multiorbital Hamiltonian or Subspaces
- `cuboid`: build a bandstructure discretization mesh
- `bandstructure`, `spectrum`, `diagonalizer`: compute the generalized bandstructure of a Hamiltonian or a ParametricHamiltonian
- `bands`, `energies`, `states`: inspect spectrum and bandstructure objects
- `momentaKPM`, `dosKPM`, `averageKPM`, `densityKPM`, `bandrangeKPM`: Kernel Polynomial Method (KPM)
- `ket`, `randomkets`: define ket models for use in e.g. KPM routines
- `greens`, `greensolver`: build Green's functions of a Hamiltonian

Some of this functionality require loading one or more third-party packages, which include the following:
- KPM: `FFTW`, `ArnoldiMethod`
- Bandstructures: `Arpack`, `ArnoldiMethod`, `KrylovKit`

The user is told when this is needed. We do this to reduce dependencies and launch time with packages whose functionality is not essential for the use of Quantica.jl

Other functions become available after loading specific third-party packages:
- Makie: enables `plot(::Hamiltonian)` and `plot(::Bandstructure)` (for 1D and 2D bandstructures)
- VegaLite: enables `vlplot(::Hamiltonian)` and `vlplot(::Bandstructure)` (for 1D bandstructures)

### Funding

    This work has been partly funded by the Spanish Ministry of Economy and Competitiveness under Grant Nos. FIS2015-65706-P, PCI2018-093026, and the CSIC Intramural Project 201760I086.
