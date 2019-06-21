"""
    ArrayQuantizer{U,D,T,N}

The array quantizer object. It transforms an array with elements
of type `T` into a 'quantized' version with elemetns of type `U`.

# Fields
  * `dims::NTuple{N,Int}` the original array dimensionality
  * `codebooks::Vector{CodeBook{U,T}}` the codebooks
  * `k::Int` the number of vector prototypes in each codebooks
  * `distance::D` the distance employed
"""
struct ArrayQuantizer{U,D,T,N}
    dims::NTuple{N, Int}              # original array size
    codebooks::Vector{CodeBook{U,T}}  # codebooks
    k::Int                            # number of codes/quantizer
    distance::D
end


# show methods
Base.show(io::IO, aq::ArrayQuantizer{U,D,T,N}) where {U,D,T,N} = begin
    m = length(codebooks(aq))
    qstr = ifelse(m==1, "quantizer", "quantizers")
    cstr = ifelse(aq.k==1, "code", "codes")
    print(io, "ArrayQuantizer{$U,$D,$T,$N}, $m $qstr, $(aq.k) $cstr")
end


# Constructors
ArrayQuantizer(aa::AbstractMatrix{T};
               k::Int=DEFAULT_K,
               m::Int=DEFAULT_M,
               method::Symbol=DEFAULT_METHOD,
               distance::Distances.PreMetric=DEFAULT_DISTANCE,
               kwargs...) where {T} = begin
    U = quantized_eltype(k)
    cbooks = build_codebooks(aa, k, m, U, method=method,
                             distance=distance; kwargs...)
    return ArrayQuantizer(size(aa), cbooks, k, distance)
end

ArrayQuantizer(aa::AbstractVector{T};
               k::Int=DEFAULT_K,
               m::Int=DEFAULT_M,
               method::Symbol=DEFAULT_METHOD,
               distance::Distances.PreMetric=DEFAULT_DISTANCE,
               kwargs...) where {T} = begin
    aq = ArrayQuantizer(aa', k=k, m=m, method=method, distance=distance; kwargs...)
    return ArrayQuantizer(size(aa), codebooks(aq), k, distance)
end


"""
    build_quantizer(aa [;kwargs])

Builds an array quantizer using the input array `aa`.

# Keyword arguments
  * `k::Int` the number of vector prototypes in each codebook
  * `m::Int` the number of codebooks
  * `method::Symbol` the algorithm to be employed for codebook
generation; possible values are `:sample` (default), `:pq` for
classical k-means clustering codebooks and `:opq` for 'cartesian'
k-means clustering codebooks
  * `distance::PreMetric` the distance to be used in the
codebook generation methods and data encoding

Other codebook generation algorithm specific keyword arguments
such as `maxiter::Int` can be specified as well.
"""
build_quantizer(aa::AbstractArray; kwargs...) where{T,N} = ArrayQuantizer(aa; kwargs...)


"""
    codebooks(aq)

Access the codebooks field of the array quantizer `aq`.
"""
codebooks(aq::ArrayQuantizer) = aq.codebooks


"""
    quantize_data(aq, aa)

Returns a quantized version of the array `aa` using the array quantizer `aq`.
"""
function quantize_data(aq::ArrayQuantizer{U,D,T,2}, aa::AbstractMatrix{T}) where {U,D,T}
    nrows, ncols = size(aa)
    @assert nrows == aq.dims[1] "Quantized matrix needs to have $nrows rows"
    cbooks = codebooks(aq)
    m = length(cbooks)
    qa = Matrix{U}(undef, m, ncols)
    @inbounds @simd for i in 1:m
        rr = rowrange(nrows, m, i)
        qa[i,:] = encode(cbooks[i], aa[rr,:], distance=aq.distance)
    end
    return qa
end

function quantize_data(aq::ArrayQuantizer{U,D,T,1}, aa::AbstractVector{T}) where {U,D,T}
    nrows = aq.dims[1]
    @assert nrows == length(aa) "Quantized vector needs to have $nrows elements"
    aat = aa'  # use transpose as a single row matrix and quantize that
    aqt = ArrayQuantizer(size(aat), codebooks(aq), aq.k, aq.distance)
    qat = quantize_data(aqt, aat)
    return vec(qat)  # return to vector form
end
