export EGSParticle

function rest_energy(p::ParticleType)::Float64
    if p == photon
        0.
    elseif p == electron
        0.511
    elseif p == positron
        0.511
    else
        msg = "Rest energy of $p should not be used"
        throw(ArgumentError(msg))
    end
end

function kin2total(Ekin::Float32, p::ParticleType)
    Float32(Float64(Ekin) + rest_energy(p))
end
function total2kin(Etotal::Float32, p::ParticleType)
    Float32(Float64(Etotal) - rest_energy(p))
end

function read_ZLAST(io::IO)
    mode = prod([read_(io, Char) for _ in 1:5])
    if mode == "MODE0"
        Nothing
    elseif mode == "MODE2"
        Float32
    else
        error("Unknown mode $mode")
    end
end

struct EGSParticle{ZLAST <: Union{Nothing, Float32}}
    typ::ParticleType
    E::Float32  # kinetic energy
    weight::Float32
    x::Float32
    y::Float32
    u::Float32
    v::Float32
    w::Float32
    new_history::Bool
    zlast::ZLAST
    latch::UInt32
end

function EGSParticle(;typ,E,weight=1,x,y,
                  u,v,w,
                  new_history=true,
                  zlast=nothing,
                  latch = latchpattern(typ))
    ZLAST = typeof(zlast)
    EGSParticle{ZLAST}(typ, E, weight,
                     x,y, u,v,w,
                     new_history,
                     zlast, latch)
end

function Base.show(io::IO, p::EGSParticle)
    zlast = sprint(show, p.zlast)
    print(io, "EGSParticle(typ=$(p.typ), E=$(p.E), weight=$(p.weight), x=$(p.x), y=$(p.y), u=$(p.u), v=$(p.v), w=$(p.w), new_history=$(p.new_history), zlast=$(zlast), latch=$(p.latch))")
end

struct EGSHeader{P <: EGSParticle}
    particlecount::Int32
    photoncount::Int32
    max_E_kin::Float32
    min_E_kin_electrons::Float32
    originalcount::Float32
end

struct EGSPhspIterator{H <: EGSHeader, I <:IO} <: AbstractPhspIterator
    io::I
    header::H
    length::Int64
end

function Base.eltype(::Type{<:EGSPhspIterator{H}}) where {H}
    ptype(H)
end

function Base.isapprox(p1::EGSParticle,
                       p2::EGSParticle;kw...)
    true
    if p1.zlast == nothing
        p2.zlast == nothing || return false
    else
        isapprox(p1.zlast, p2.zlast; kw...) || return false
    end
    p1.typ == p2.typ  &&
    p1.latch == p2.latch &&
    p1.new_history   == p2.new_history    &&
    isapprox(
             [p1.E, p1.weight, p1.x, p1.y, p1.u, p1.v, p1.w],
             [p2.E, p2.weight, p2.x, p2.y, p2.u, p2.v, p2.w];
            kw...)
end

function zlast_type(::Type{EGSParticle{ZLAST}}) where {ZLAST}   
    ZLAST
end
function zlast_type(::Type{EGSHeader{P}}) where {P}
    zlast_type(P)
end
function zlast_type(o)
    zlast_type(typeof(o))
end
function ptype(::Type{EGSHeader{P}}) where {P}
    P
end

function ptype_disksize(h::EGSHeader)
    ZLAST = zlast_type(h)
    sizeof(ZLAST) + 7 * 4
end

function consume_egs_header(io::IO)
    ZLAST = read_ZLAST(io)
    P = EGSParticle{ZLAST}
    nphsp = read_(io, Int32)
    nphotphsp = read_(io, Int32)
    ekmaxphsp = read_(io, Float32)
    ekminphspe = read_(io, Float32)
    nincphsp = read_(io, Float32)
    EGSHeader{P}(nphsp, nphotphsp, ekmaxphsp, ekminphspe, nincphsp)
end

function egs_iterator(io::IO)
    h = consume_egs_header(io)
    total_size  = bytelength(io)
    particle_size = ptype_disksize(h)
    header_size = particle_size
    body_size = total_size - header_size
    len = Int64(body_size / particle_size)
    @assert len == h.particlecount
    EGSPhspIterator(io, h, len)
end

function particle_type_from_latch(latch)::ParticleType
    latchmask = (1<<30) | (1<<29)
    latch &= latchmask
    if latch == latchpattern(photon)
        photon
    elseif latch == latchpattern(electron)
        electron
    elseif latch == latchpattern(positron)
        positron
    else
        msg = "Unsupported latch pattern $latch"
        throw(ArgumentError(msg))
    end
end

function latchpattern(p::ParticleType)::UInt32
    if p == photon
        UInt32(0)
    elseif p == electron
        UInt32(1 << 30)
    elseif p == positron
        UInt32(1 << 29)
    else
        msg = "Unsupported particle type $p"
        throw(ArgumentError(msg))
    end
end

function read_particle(io::IO, h::EGSHeader)
    latch = read_(io,UInt32)
    
    E_tot = read_(io, Float32)
    new_history = E_tot < 0
    E_tot = abs(E_tot)
    
    x = read_(io, Float32)
    y = read_(io, Float32)
    u = read_(io, Float32)
    v = read_(io, Float32)
    
    weight = read_(io, Float32)
    
    sign_w = sign(weight)
    weight = abs(weight)
    u,v,w = compute_u_v_w(u,v,sign_w)

    ZLAST = zlast_type(h)
    zlast = read_(io, ZLAST)
    typ = particle_type_from_latch(latch)
    E = total2kin(E_tot, typ)
    EGSParticle(
        typ::ParticleType,
        E::Float32,
        weight::Float32,
        x::Float32,
        y::Float32,
        u::Float32,
        v::Float32,
        w::Float32,
        new_history::Bool,
        zlast::ZLAST,
        latch::UInt32,
   )
end

function Base.iterate(iter::EGSPhspIterator)
    # skip header
    pos = ptype_disksize(iter.header)
    seek(iter.io, pos)
    _iterate(iter)
end

function write_header(io::IO, h::EGSHeader)
    ZLAST = zlast_type(h)
    mode = if ZLAST == Nothing
        "MODE0"
    else
        @assert ZLAST == Float32
        "MODE2"
    end

    ret = 0
    ret += write(io, mode)
    ret += write(io, h.particlecount)
    ret += write(io, h.photoncount)
    ret += write(io, h.max_E_kin)
    ret += write(io, h.min_E_kin_electrons)
    ret += write(io, h.originalcount)
    while (ret < ptype_disksize(h))
        ret += write(io, '\0')
    end
    @assert ret == ptype_disksize(h)
    ret
end
function write_particle(io::IO, p::EGSParticle, h::EGSHeader)
    ret = write_particle(io,p)
    @assert ret == ptype_disksize(h)
    ret
end
function write_particle(io::IO, p::EGSParticle)
    sign_E = (-1)^p.new_history
    sign_weight = sign(p.w)
    E = sign_E * kin2total(p.E, p.typ)
    ret = 0
    ret += write(io, p.latch)
    ret += write(io, E  )
    ret += write(io, p.x)
    ret += write(io, p.y)
    ret += write(io, p.u)
    ret += write(io, p.v)
    ret += write(io, sign_weight * p.weight)
    if p.zlast != nothing
        ret += write(io, p.zlast)
    end
    ret
end

mutable struct EGSWriter{P <: EGSParticle, I}
    io::IO
    particlecount::Int32
    photoncount::Int32
    max_E_kin::Float32
    min_E_kin_electrons::Float32
    originalcount::Float32
end

function Base.write(w::EGSWriter{P}, p::P) where {P <: EGSParticle}
    w.particlecount += 1
    if p.typ == photon
        w.photoncount += 1
    end
    w.max_E_kin = max(w.max_E_kin, p.E)
    if p.typ == electron
        w.min_E_kin_electrons = min(w.min_E_kin_electrons, p.E)
    end
    write_particle(w.io, p)
end

function create_header(w::EGSWriter{P}) where {P}
    h = EGSHeader{P}(
        w.particlecount::Int32,
        w.photoncount::Int32,
        w.max_E_kin::Float32,
        w.min_E_kin_electrons::Float32,
        w.originalcount::Float32,
   )
end

function egs_writer(f, path, P)
    w = egs_writer(path, P)
    ret = call_fenced(f,w)
    close(w)
    ret
end

function egs_writer(path::AbstractString, P)
    io = open(path, "w")
    egs_writer(io, P)
end

function egs_writer(io::IO, ::Type{P}) where {P <: EGSParticle}
    I = typeof(io)
    w = EGSWriter{P,I}(io, Int32(0),Int32(0),Float32(-Inf),Float32(Inf),Float32(1.))
    h = create_header(w)
    write_header(io, h)
    w
end

function Base.close(w::EGSWriter)
    h = create_header(w)
    seekstart(w.io)
    write_header(w.io, h)
    close(w.io)
end
