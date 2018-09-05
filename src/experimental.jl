export Collect, energy

struct Collect
    count::Int64
end

function (c::Collect)(iter)
    ret = eltype(iter)[]
    for (i,xi) in enumerate(iter)
        push!(ret, xi)
        i < c.count || break
    end
    return ret
end

energy(p::Particle) = p.E*p.weight