######################
# Generic stuff

mutable struct Camera
    x::Int
    y::Int
    w::Int
    h::Int
end

abstract type AbstractGame end
function start!(game::AbstractGame) end

abstract type AbstractTexture end

mutable struct Game{G <: AbstractGame}
    win
    textures::Dict{String, AbstractTexture}
    renderer
    cam::Camera
    ev::Vector{UInt8}
    g::G

    function Game{G}() where {G <: AbstractGame}
        g = new{G}()
        g.ev = Vector{UInt8}(undef, 56)
        g.textures = Dict{String, AbstractTexture}()

        return g
    end
end

isrunning(game::Game) = isrunning(game.g)
render(game::Game) = render(game, game.g)
load_assets(engine::Game) = load_assets(engine, engine.g)

function init(G; x = 1050, y = 20, w = 800, h = 600)
    SDL2.GL_SetAttribute(SDL2.GL_MULTISAMPLEBUFFERS, 16)
    SDL2.GL_SetAttribute(SDL2.GL_MULTISAMPLESAMPLES, 16)

    SDL2.init()
    SDL2.IMG_Init(Int32(SDL2.IMG_INIT_PNG))

    win = SDL2.CreateWindow("Stellar", Int32(x), Int32(y), Int32(w), Int32(h), UInt32(SDL2.WINDOW_SHOWN))

    # SDL2.SetWindowResizable(win,true)

    renderer = SDL2.CreateRenderer(win, Int32(-1),
        UInt32(SDL2.RENDERER_ACCELERATED | SDL2.RENDERER_PRESENTVSYNC | SDL2.IMG_INIT_PNG))

    game = Game{G}()
    game.renderer = renderer
    game.win = win
    game.cam = Camera(0, 0, w, h)

    return game
end

function gclose(game)
    for texture in values(game.textures)
        SDL2.DestroyTexture(texture.texture)    # clean up resources before exiting
    end
    SDL2.DestroyRenderer(game.renderer)
    SDL2.DestroyWindow(game.win)
    SDL2.IMG_Quit()
    SDL2.Quit()
end

function clear(game)
    SDL2.SetRenderDrawColor(game.renderer, 0, 0, 0, 255)
    SDL2.RenderClear(game.renderer)
end

function gflush(game)
    SDL2.RenderPresent(game.renderer)
end

############################
# Textures processing
struct TileTexture{T, R} <: AbstractTexture
    texture::T
    win_rect::R
    tex_rect::R
    w0::Int
    h0::Int
    w::Int
    h::Int
end

struct Texture{T, R} <: AbstractTexture
    texture::T
    tex_rect::R
    win_rect::R
end

function load_texture!(game, filename, assetname)
    surface = SDL2.IMG_Load(filename)
    tex = SDL2.CreateTextureFromSurface(game.renderer, surface)
    SDL2.FreeSurface(surface)

    w0 = Ref{Cint}(0)
    h0 = Ref{Cint}(0)
    SDL2.QueryTexture(tex, C_NULL, C_NULL, w0, h0)
    tex_rect = SDL2.Rect(0, 0, w0[], h0[])
    win_rect = SDL2.Rect(0, 0, w0[], h0[])
    texture = Texture(tex, tex_rect, win_rect)
    game.textures[assetname] = texture

    return game
end

function load_tiles!(e, filename, assetname, w, h)
    surface = SDL2.IMG_Load(filename)
    tex = SDL2.CreateTextureFromSurface(e.renderer, surface)
    SDL2.FreeSurface(surface)

    w0 = Ref{Cint}(0)
    h0 = Ref{Cint}(0)
    SDL2.QueryTexture(tex, C_NULL, C_NULL, w0, h0)
    w1 = Int(w0[]/w)
    h1 = Int(h0[]/h)
    tex_rect = SDL2.Rect(0, 0, w1, h1)
    win_rect = SDL2.Rect(0, 0, w1, h1)
    texture = TileTexture(tex, win_rect, tex_rect, w, h, w1, h1)
    e.textures[assetname] = texture

    return e
end

function render(renderer, texture::Texture, x, y, w, h, c)
    texture.win_rect.x = x
    texture.win_rect.y = y
    texture.win_rect.w = w
    texture.win_rect.h = h
    SDL2.SetTextureColorMod(texture.texture, c...)
    SDL2.RenderCopy(renderer, texture.texture, C_NULL,
                    pointer_from_objref(texture.win_rect))
end

function set_tile(texture::TileTexture, i)
    i = UInt32(i)
    x = i % texture.w0
    y = i ÷ texture.w0
    texture.tex_rect.x = x * texture.w
    texture.tex_rect.y = y * texture.h
end

function render(renderer, texture::TileTexture, i, x, y, w, h, c = nothing)
    set_tile(texture, i)
    texture.win_rect.x = x
    texture.win_rect.y = y
    texture.win_rect.w = w
    texture.win_rect.h = h
    if !isnothing(c)
        SDL2.SetTextureColorMod(texture.texture, c...)
    end
    SDL2.RenderCopy(renderer, texture.texture, pointer_from_objref(texture.tex_rect),
                    pointer_from_objref(texture.win_rect))
end

#########################
# Event processor

function extract_type(ev)
    UInt32(ev[1]) | (UInt32(ev[2]) << 8) | UInt32(ev[3] << 16) | UInt32(ev[4] << 24)
end

function get_event(game)
    res = SDL2.PollEvent(game.ev)
    res == 0 && return nothing

    tp = extract_type(game.ev)
    evtype = SDL2.Event(tp)
    event = unsafe_load(Ptr{evtype}(pointer(game.ev)))

    return event
end

function process(::SDL2.AbstractEvent) end
function process(::Nothing) end

abstract type Command end
execute(cmd::Command, game::Game) = execute(cmd, game.g, game)
execute(::Nothing, ::Game) = nothing

############################
# Game loop

function run(game::Game)
    time_step_s = 0.01
    start!(game.g)
    tick = SDL2.GetTicks()
    frames_cnt = [tick]
    cnt = 1
    while isrunning(game)
        clear(game)
        render(game)
        gflush(game)

        cmd = process(get_event(game))
        execute(cmd, game)
        tock = SDL2.GetTicks()
        dt = (tock - tick)/1000
        tick = tock
        update!(game, game.g, dt)

        push!(frames_cnt, tick)
        filter!(x -> tick - x <= 10_000, frames_cnt)
        if cnt >= 100
            cnt = 1
            println("FPS: $(length(frames_cnt)/(frames_cnt[end] - frames_cnt[begin])*1000)")
        else
            cnt += 1
        end

        SDL2.Delay(UInt32(10))
    end
end
