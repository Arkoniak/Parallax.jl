using Underscores
using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer

include("engine.jl")
include("astras.jl")

engine = init(AstraGame)
game = AstraGame(engine; nlayers = 5, rastras = 10:20, max_speed = 800, min_speed = 300, explosions = 10)
# game = AstraGame(engine; nlayers = 20, rastras = 40:60, max_speed = 800, min_speed = 300, explosions = 10000)
engine.g = game
load_assets(engine)

run(engine)
gclose(engine)

#########################
using BenchmarkTools

@btime update!($engine, $engine.g, 0.01)
@time (for _ in 1:1000; update!(engine, engine.g, 0.01); end)
