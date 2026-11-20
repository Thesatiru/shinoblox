--!strict
-- Ponto de entrada do cliente: liga os controllers.

local DebugController = require(script.Parent.Combat.DebugController)
local InputController = require(script.Parent.Combat.InputController)

DebugController.start()
InputController.start()
