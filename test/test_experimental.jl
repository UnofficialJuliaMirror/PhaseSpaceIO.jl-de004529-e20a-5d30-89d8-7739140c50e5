module TestExperimental
using Setfield
using PhaseSpaceIO
using Test
using PhaseSpaceIO.Testing

@testset "Collect" begin
    c = Collect(5)
    iter = randn(10)
    @test c(iter) == iter[1:5]
    c = Collect(20)
    @test c(iter) == iter
end

@testset "Setfield" begin
    p = Particle(1,2,3,4,5,6,0,0,1,true,(),())
    q = @set p.x = 10
    @test q.x == 10
    @test p.x == 4
end

@testset "histogram" begin
    p = arbitrary(Particle{0,0})
    p = @set p.E = 1
    p = @set p.x = 1
    p = @set p.weight = 1
    p11_w1 = p
    p11_w2 = @set p11_w1.weight = 2
    p21_w1 = @set p11_w1.E = 2
    p12_w1 = @set p11_w1.x = 2
    edges = ([0,1.5,3],)
    h = @inferred histmap(p->p.E,
                                     [p11_w1, p21_w1],
                                     edges = edges)
    @test h.edges == edges
    @test h.weights == [1,1]
    
    h = @inferred histmap(p->p.E,
                                     [p11_w2, p11_w1, p21_w1],
                                     edges=edges)
    @test h.weights == [3,1]
    h = @inferred histmap(p->p.E,
                                     [p11_w2, p11_w1, p21_w1],
                                     edges=edges, weight_function=p->1)
    @test h.weights == [2,1]
    
    edges = ([0,1.5,3], [0.9,1.1,2.1, 2.2])
    h = @inferred histmap(p->p.E, p->p.x,
                                     [p11_w2, p12_w1, p12_w1, p21_w1],
                                     edges=edges)
    @test h.edges == edges
    @test h.weights == [2 2 0; 1 0 0]
end

@testset "download" begin
    key = "VarianClinaciX_6MV_05x05"
    dir = tempdir()
    path = iaea_download(key, dir=dir)
    path2 = iaea_download(key, dir=dir)
    @test path2 == path
    ps = iaea_iterator(collect, path)
    @test length(ps) == 432410
end

end
