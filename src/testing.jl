module Testing
using PhaseSpaceIO: Particle, ParticleType,
EGSHeader, EGSParticle
export arbitrary

function arbitrary(::Type{Particle{Nf,Ni}}) where {Nf, Ni}
    typ = rand([instances(ParticleType)...])
    E = 100*rand()
    weight = rand()
    x = randn(Float32)
    y = randn(Float32)
    z = randn(Float32)
    u = randn(Float64)
    v = randn(Float64)
    w = randn(Float64)
    scale = 1/sqrt(u^2 + v^2 + w^2)
    u *= scale
    v *= scale
    w *= scale
    new_history  = rand(Bool)
    extra_floats = tuple(randn(Float32, Nf)...)
    extra_ints   = tuple(rand(Int32, Ni)...)
    Particle{Nf,Ni}(typ,
                    E,
                    weight,
                    x,y,z,
                    u,v,w,
                    new_history,
                    extra_floats,
                    extra_ints)
end

function arbitrary(H::Type{EGSHeader{MODE}}; 
    particlecount = Int32(rand(1:typemax(Int32))),
    photoncount = Int32(rand(1:particlecount)),
    max_E_kin = Float32(25*rand()),
    min_E_kin_electrons= Float32(rand()),
    originalcount = Float32(10^(10*rand()))
    ) where {MODE}
    H(particlecount,
    photoncount,
    max_E_kin,
    min_E_kin_electrons,
    originalcount)
end

function arbitrary(P::Type{EGSParticle{ZLAST}}) where {ZLAST}
    E = rand(Float32)
    latch = rand(UInt32)
    x = randn(Float32)
    y = randn(Float32)
    u = randn()
    v = randn()
    w = randn()
    scale = 1/sqrt(u^2 + v^2 + w^2)
    u = Float32(scale * u)
    v = Float32(scale * v)
    w = Float32(scale * w)
    new_history = rand(Bool)
    weight = 10*rand(Float32)
    charge = 999
    if ZLAST == Nothing
        zlast = nothing
    else
        zlast = Float32(randn())
    end
    
    EGSParticle(
        latch::UInt32,
        E::Float32,
        x::Float32,
        y::Float32,
        u::Float32,
        v::Float32,
        w::Float32,
        new_history::Bool,
        weight::Float32,
        charge::Int,
        zlast::ZLAST,
    )
end

end
