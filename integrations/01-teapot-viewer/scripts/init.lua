-- DIAGNOSTIC init.lua — magenta clear with the template teapot on top.
-- Used to verify the clear color actually reaches the back buffer under
-- llvmpipe ES 3.2, and to rule out "teapot rendered in black on black".
print("[diag] integration init.lua loaded")

tram.ui.SetWindowSize(640, 480)

tram.render.SetScreenClearColor(tram.math.vec3(1.0, 0.0, 1.0))  -- magenta
tram.render.SetAmbientColor(tram.math.vec3(1.0, 1.0, 1.0))      -- full ambient so model self-lights
tram.render.SetSunColor(tram.math.vec3(1.0, 1.0, 1.0))
tram.render.SetSunDirection(tram.math.vec3(0.0, 0.0, -1.0))

tram.render.SetViewPosition(tram.math.vec3(0.0, 0.0, 1.5))

scene_light = tram.components.Light()
scene_light:SetColor(tram.render.COLOR_WHITE)
scene_light:SetLocation(tram.math.vec3(5.0, 5.0, 5.0))
scene_light:Init()

teapot = tram.components.Render()
teapot:SetModel("teapot")
teapot:Init()
