############################
# Single object
mutable struct Astra
    x::Float64
    y::Float64
    w::Int
    c::Tuple{UInt8, UInt8, UInt8}
end

function Astra(rw, rh; size = 3:8)
    x = rand(rw)
    y = rand(rh)
    w = rand(size)
    c = ntuple(_ -> UInt8(rand(0:255)), 3)
    
    Astra(x, y, w, c)
end

render(game, astra::Astra) = render(game.renderer, game.textures["astra"], Int(ceil(astra.x)), Int(ceil(astra.y)), astra.w, astra.w, astra.c)

function update!(astra::Astra, dx)
    astra.x -= dx
end

##############################
# Single astra field
struct Layer
    astras::Vector{Astra}
    velocity::Float64
    n::Int
end

function Layer(game::Game, velocity, num)
    cam = game.cam
    astras = Astra[]
    rw = 0:(cam.w - 1)
    rh = 0:(cam.h - 1)
    for i in 1:num
        push!(astras, Astra(rw, rh))
    end
    rw = cam.w:(2*cam.w - 1)
    for i in 1:num
        push!(astras, Astra(rw, rh))
    end

    return Layer(astras, velocity, num)
end

function render(game, layer::Layer)
    cam = game.cam
    for astra in layer.astras
        astra.x < cam.w && render(game, astra)
    end
end

function update!(game, layer::Layer, dt)
    cam = game.cam
    dx = layer.velocity * dt
    update!.(layer.astras, dx)
    @_ filter!(_.x >= 0, layer.astras)   

    lost_astras = 2*layer.n - length(layer.astras)
    rw = cam.w:(2*cam.w - 1)
    rh = 0:(cam.h - 1)
    for i in 1:lost_astras
        push!(layer.astras, Astra(rw, rh))
    end
end

####################################
# Explosions
mutable struct Explosion
    frame::Int
    x::Int
    y::Int
    size::Int
    ts::Float64
end
function Explosion(rw, rh)
    x = rand(rw)
    y = rand(rh)
    ts = -rand()

    Explosion(0, x, y, 100, ts)
end

function render(engine, expl::Explosion)
    if expl.ts >= 0
        render(engine.renderer, engine.textures["explosion"], expl.frame, expl.x, expl.y, expl.size, Int(ceil(engine.textures["explosion"].h/engine.textures["explosion"].w * expl.size)))
    end
end

function update!(expl::Explosion, dt)
    expl.ts += dt
    expl.frame = Int(expl.ts ÷ (1/48))
end

struct Explosions
    num::Int
    explosions::Vector{Explosion}
end
function Explosions(engine; num = 10)
    explosions = Explosion[]
    cam = engine.cam
    rw = 0:(cam.w - 1)
    rh = 0:(cam.h - 1)
    for _ in 1:num
        push!(explosions, Explosion(rw, rh))
    end

    return Explosions(num, explosions)
end

function render(engine, expl::Explosions)
    for e in expl.explosions
        render(engine, e)
    end
end

function update!(engine, expl::Explosions, dt)
    for e in expl.explosions
        update!(e, dt)
    end
    @_ filter!(_.frame < 48, expl.explosions)   
    lost_explosions = expl.num - length(expl.explosions)
    cam = engine.cam
    rw = 0:(cam.w - 1)
    rh = 0:(cam.h - 1)
    for i in 1:lost_explosions
        push!(expl.explosions, Explosion(rw, rh))
    end
end

##################################
# Parallax game itself

mutable struct AstraGame <: AbstractGame
    layers::Vector{Layer}
    explosions::Explosions
    state::Bool
end

function AstraGame(game; nlayers = 5, min_speed = 100, max_speed = 1000, rastras = 100:100, explosions = 10)
    layers = Layer[]

    delta_speed = nlayers == 1 ? 0.0 : (max_speed - min_speed) / (nlayers - 1)
    for i in 1:nlayers
        push!(layers, Layer(game, min_speed + (i - 1) * delta_speed, rand(rastras)))
    end
    explosions = Explosions(game; num = explosions)
    return AstraGame(layers, explosions, true)
end

isrunning(game::AstraGame) = game.state
start!(game::AstraGame) = game.state = true
function load_assets(engine::Game, game::AstraGame)
    load_texture!(engine, joinpath("assets", "pngkit_blue-sparkle-png-transparent_2614827.png"), "astra")
    load_tiles!(engine, joinpath("assets", "93-936091_drawn-explosions-sprite-explosion-sprite-sheet-doom.png"), "explosion", 8, 6)
end

function render(base, game::AstraGame)
    for layer in game.layers
        render(base, layer)
    end
    render(base, game.explosions)
end

function update!(base::Game, game::AstraGame, dt)
    for layer in game.layers
        update!(base, layer, dt)
    end
    update!(base, game.explosions, dt)
end

################################
# Control
struct QuitCommand <: Command end

function process(ev::SDL2.KeyboardEvent)
    ev._type == SDL2.KEYUP && return
    if ev.keysym.sym == SDL2.SDLK_ESCAPE
        return QuitCommand()
    end

    return
end

function execute(::QuitCommand, game::AstraGame, base)
    game.state = false
end
