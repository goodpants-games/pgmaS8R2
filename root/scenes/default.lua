local scene = require("sceneman").scene()
local fontres = require("fontres")

function scene.draw()
    Lg.setFont(fontres.monogram)
    Lg.setColor(1, 1, 1)
    Lg.print("Hello, world!")
end

return scene