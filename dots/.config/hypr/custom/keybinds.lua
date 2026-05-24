-- Enviar ventana al workspace con SUPER+SHIFT+número
local f = io.open("/tmp/hypr-custom-keybinds.log", "w")
if f then
    f:write("terminal: " .. tostring(terminal) .. "\n")
    f:close()
end

-- (sobrescribe el comportamiento: antes era SUPER+ALT+número)
for i = 1, 10 do
    local numberkey = {10,11,12,13,14,15,16,17,18,19}
    hl.bind("SUPER + SHIFT + code:"..numberkey[i], hl.dsp.window.move({ workspace = i, follow = false}) )
end

-- Activar/Desactivar el filtro verde oliva relajante usando la API de Lua
hl.bind("SUPER + SHIFT + G", function()
    local current = hl.get_config("decoration:screen_shader")
    local shaderPath = "/home/juandiego/.config/hypr/shaders/olive_green.glsl"
    
    if current == shaderPath then
        hl.config({decoration = {screen_shader = "[[EMPTY]]"}})
        hl.exec_cmd("notify-send 'Filtro Verde Oliva' 'Desactivado' -a 'Hyprland'")
    else
        hl.config({decoration = {screen_shader = shaderPath}})
        hl.exec_cmd("notify-send 'Filtro Verde Oliva' 'Activado' -a 'Hyprland'")
    end
end)

-- Cambiar el sentido de la división (horizontal/vertical)
hl.bind("SUPER + H", hl.dsp.layout("togglesplit"), {description = "Cambiar sentido del split"})


