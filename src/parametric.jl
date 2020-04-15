#######################################################################
# ParametricHamiltonian
#######################################################################
struct ParametricHamiltonian{N,M<:NTuple{N,ElementModifier},P<:NTuple{N,Any},H<:Hamiltonian}
    originalh::H
    h::H
    modifiers::M  # N modifiers
    ptrdata::P    # P is an NTuple{N,Vector{Vector{ptrdata}}}, one per harmonic
end               # ptrdata may be a nzval ptr, a (ptr,r) or a (ptr, r, dr)

function Base.show(io::IO, ::MIME"text/plain", pham::ParametricHamiltonian{N}) where {N}
    i = get(io, :indent, "")
    print(io, i, "Parametric")
    show(io, pham.h)
    print(io, i, "\n", "$i  Parameters       : $(parameters(pham))")
end

"""
    parametric(h::Hamiltonian, modifiers::ElementModifier...)

Builds a `ParametricHamiltonian` that can be used to efficiently apply `modifiers` to `h`.
`modifiers` can be any number of `@onsite!(args -> body; kw...)` and `@hopping!(args -> body;
kw...)` transformations, each with a set of parameters `ps` given as keyword arguments of
functions `f = (...; ps...) -> body`. The resulting `ph::ParamtricHamiltonian` can be used
to produced the modified Hamiltonian simply by calling it with those same parameters as
keyword arguments.

Note 1: for sparse `h`, `parametric` only modifies existing onsites and hoppings in `h`,
so be sure to add zero onsites and/or hoppings to `h` if they are originally not present but
you need to apply modifiers to them.

Note 2: `optimize!(h)` is called prior to building the parametric Hamiltonian. This can lead
to extra zero onsites and hoppings being stored in sparse `h`s.

    h |> parametric(modifiers::ElementModifier...)

Function form of `parametric`, equivalent to `parametric(h, modifiers...)`.

# Examples
```@meta
DocTestSetup = quote
    using Quantica
end
```
```jldoctest
julia> ph = LatticePresets.honeycomb() |> hamiltonian(onsite(0) + hopping(1, range = 1/√3)) |>
       unitcell(10) |> parametric(@onsite!((o; μ) -> o - μ))
ParametricHamiltonian{<:Lattice} : Hamiltonian on a 2D Lattice in 2D space
  Bloch harmonics  : 5 (SparseMatrixCSC, sparse)
  Harmonic size    : 200 × 200
  Orbitals         : ((:a,), (:a,))
  Element type     : scalar (Complex{Float64})
  Onsites          : 200
  Hoppings         : 640
  Coordination     : 3.2
  Parameters       : (:μ,)

julia> ph(μ = 2)
Hamiltonian{<:Lattice} : Hamiltonian on a 2D Lattice in 2D space
  Bloch harmonics  : 5 (SparseMatrixCSC, sparse)
  Harmonic size    : 200 × 200
  Orbitals         : ((:a,), (:a,))
  Element type     : scalar (Complex{Float64})
  Onsites          : 200
  Hoppings         : 640
  Coordination     : 3.2
```
```@meta
DocTestSetup = nothing
```
# See also
    `@onsite!`, `@hopping!`
"""
function parametric(h::Hamiltonian, ts::ElementModifier...)
    ts´ = resolve.(ts, Ref(h.lattice))
    optimize!(h)  # to avoid ptrs getting out of sync if optimize! later
    return ParametricHamiltonian(h, copy(h), ts´, parametric_ptrdata.(Ref(h), ts´))
end

parametric(ts::ElementModifier...) = h -> parametric(h, ts...)

function parametric_ptrdata(h::Hamiltonian{LA,L,M,<:AbstractSparseMatrix}, t::ElementModifier) where {LA,L,M}
    harmonic_ptrdata = empty_ptrdata(h, t)
    lat = h.lattice
    selector = t.selector
    for (har, ptrdata) in zip(h.harmonics, harmonic_ptrdata)
        matrix = har.h
        dn = har.dn
        rows = rowvals(matrix)
        for col in 1:size(matrix, 2), ptr in nzrange(matrix, col)
            row = rows[ptr]
            selected  = selector(lat, (row, col), (dn, zero(dn)))
            selected´ = t.selector.forcehermitian && selector(lat, (col, row), (zero(dn), dn))
            selected  && push!(ptrdata, ptrdatum(t, lat,  ptr, (row, col)))
            selected´ && push!(ptrdata, ptrdatum(t, lat, -ptr, (col, row)))
        end
    end
    return harmonic_ptrdata
end

# Uniform case, one vector of nzval ptr per harmonic
empty_ptrdata(h, t::UniformModifier)  = [Int[] for _ in h.harmonics]
# Non-uniform case, one vector of (ptr, r, dr) per harmonic
function empty_ptrdata(h, t::OnsiteModifier)
    S = positiontype(h.lattice)
    return [Tuple{Int,S}[] for _ in h.harmonics]
end
function empty_ptrdata(h, t::HoppingModifier)
    S = positiontype(h.lattice)
    return [Tuple{Int,S,S}[] for _ in h.harmonics]
end

# Uniform case
ptrdatum(t::UniformModifier, lat, ptr, (row, col)) = ptr
# Non-uniform case
ptrdatum(t::OnsiteModifier, lat, ptr, (row, col)) = (ptr, sites(lat)[col])
function ptrdatum(t::HoppingModifier, lat, ptr, (row, col))
    r, dr = _rdr(sites(lat)[col], sites(lat)[row])
    return (ptr, r, dr)
end

function (ph::ParametricHamiltonian)(; kw...)
    checkconsistency(ph, false) # only weak check for performance
    applymodifier_ptrdata!.(Ref(ph.h), Ref(ph.originalh), ph.modifiers, ph.ptrdata, Ref(values(kw)))
    return ph.h
end

function applymodifier_ptrdata!(h, originalh, modifier, ptrdata, kw)
    for (ohar, har, hardata) in zip(originalh.harmonics, h.harmonics, ptrdata)
        nz = nonzeros(har.h)
        onz = nonzeros(ohar.h)
        for data in hardata
            ptr = first(data)
            isadjoint = ptr < 0
            isadjoint && (ptr = -ptr)
            args = modifier_args(onz, data)
            val = modifier(args...; kw...)
            nz[ptr] = isadjoint ? val' : val
        end
    end
    return h
end

modifier_args(onz, ptr::Int) = (onz[abs(ptr)],)
modifier_args(onz, (ptr, r)::Tuple{Int,SVector}) = (onz[abs(ptr)], r)
modifier_args(onz, (ptr, r, dr)::Tuple{Int,SVector,SVector}) = (onz[abs(ptr)], r, dr)

function checkconsistency(ph::ParametricHamiltonian, fullcheck = true)
    isconsistent = true
    length(ph.originalh.harmonics) == length(ph.h.harmonics) || (isconsitent = false)
    if fullcheck && isconsistent
        for (ohar, har) in zip(ph.originalh.harmonics, ph.h.harmonics)
            length(nonzeros(har.h)) == length(nonzeros(ohar.h)) || (isconsistent = false; break)
            rowvals(har.h) == rowvals(ohar.h) || (isconsistent = false; break)
            getcolptr(har.h) == getcolptr(ohar.h) || (isconsistent = false; break)
        end
    end
    isconsistent ||
        throw(error("ParametricHamiltonian is not internally consistent, it may have been modified after creation"))
    return nothing
end

"""
    parameters(ph::ParametricHamiltonian)

Return the names of the parameter that `ph` depends on
"""
parameters(ph::ParametricHamiltonian) = mergetuples(parameters.(ph.modifiers)...)

Base.copy(ph::ParametricHamiltonian) =
    ParametricHamiltonian(copy(ph.originalh), copy(ph.h), ph.modifiers, copy(h.ptrdata))

Base.size(ph::ParametricHamiltonian, n...) = size(ph.h, n...)

bravais(ph::ParametricHamiltonian) = bravais(ph.hamiltonian.lattice)

Base.eltype(ph::ParametricHamiltonian) = eltype(ph.h)