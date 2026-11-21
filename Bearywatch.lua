local addon = _G.BearyWatch
if type(addon) ~= "table" then
  addon = {}
  _G.BearyWatch = addon
end
addon.environment = addon.environment or setmetatable({ addon = addon }, { __index = _G })
addon.environment.addon = addon
