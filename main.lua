local favPlugins = PersistentDB:GetStructuredData("favPlugins") or {}
local showFav = PersistentDB:GetBool("showFav") ~= false
local originalPositions, pluginRows, modifiedComps = {}, {}, {}
local favIcon
local lastSortLayer

-- Move plugins up the list or restore their original position
function updateFavFilter()
    local visibleIndex = 0

    for _, row in ipairs(pluginRows) do
        local component = row.component
        local pos = originalPositions[component]
        if not pos then goto continue end

        if not showFav then
            component:SetPos(pos.x, pos.y)
        elseif not favPlugins[row.name] then
            component:SetPos(5000, 5000)
        else
            component:SetPos(pos.x, pluginRows[1].y + visibleIndex * row.height)
            visibleIndex = visibleIndex + 1
        end

        ::continue::
    end
end

function checkPluginScreen()
	local parentWindow = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PARENT_WINDOW_LAYER)
	if not parentWindow then
		favIcon = nil
		return
	end

	-- Multiple interfaces use this parent, we only care if it's the Plugin Hub
	local windowTitle = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PARENT_WINDOW_BORDER):GetChild(0, 14)
	if not windowTitle then return end
	if windowTitle.content ~= "Plugin Hub" then return end

	-- The selected tab is always the 27th child of PARENT_WINDOW_TABS
	local selectedTab = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PARENT_WINDOW_TABS):GetChild(0, 27)
	if not selectedTab then return end
	if selectedTab.content ~= "Manage" then return end
	
	local sortLayer = ui.Interfaces:GetComponent(id.Component.PLUGIN_HUB_PARENT_MANAGE__SORT)
	if not sortLayer then return end

	if favIcon and lastSortLayer == sortLayer then return end

	lastSortLayer = sortLayer

	favIcon = ui.Sprite.new(sortLayer)
	favIcon.sprite = showFav and 31190 or 31192
	favIcon:SetSize(30, 30)
	favIcon:SetPos(sortLayer.width - 45, 0)
	favIcon:Subscribe(ui.Hook.ONMOUSEOVER, function(self, x, y)
		self.sprite = 31191
	end)
	favIcon:Subscribe(ui.Hook.ONMOUSELEAVE, function(self, x, y)
		self.sprite = showFav and 31190 or 31192
	end)
	favIcon:Subscribe(ui.Hook.ONCLICK, function(self, x, y)
		showFav = not showFav
		self.sprite = showFav and 31190 or 31192
		updateFavFilter()
	end)

	local pluginList = ui.Interfaces:GetComponent(id.Component.PLUGIN_HUB_PARENT_MANAGE__LIST)
	if not pluginList then return end

	pluginRows, originalPositions, modifiedComps = {}, {}, {}

	pluginList:IterateDynamicComponents(function(component, _)
		component:IterateDynamicComponents(function(childComp, _)
			if childComp and childComp.font == 28 then -- font 28 is used exclusively for a plugin's title
				local pluginName = childComp.content

				if modifiedComps[component] then return end
				modifiedComps[component] = true

				-- Record original position
				originalPositions[component] = {x = component.x, y = component.y}

				table.insert(pluginRows, {
					component = component,
					name = pluginName,
					height = component.height,
					y = component.y
				})

				local favActionBtn = ui.Sprite.new(component)
				favActionBtn.sprite = favPlugins[pluginName] and 31190 or 31189
				favActionBtn:SetSize(20, 20)
				favActionBtn:SetPos(childComp.x, 2)
				favActionBtn:MoveToFront()
				favActionBtn:Subscribe(ui.Hook.ONCLICK, function(self, x, y)
					if favPlugins[pluginName] then
						favPlugins[pluginName] = nil
						self.sprite = 31189
					else
						favPlugins[pluginName] = true
						self.sprite = 31190
					end
					updateFavFilter()
				end)
				favActionBtn:Subscribe(ui.Hook.ONMOUSEOVER, function(self, x, y)
					self.sprite = 31191
				end)
				favActionBtn:Subscribe(ui.Hook.ONMOUSELEAVE, function(self, x, y)
					self.sprite = favPlugins[pluginName] and 31190 or 31189
				end)

				 -- Move the plugin name so there's space for the favActionBtn
				childComp:SetPos(childComp.x + favActionBtn.width + 2, childComp.y)
			end
		end)
	end)
	updateFavFilter()
end

Event.ServerLogic.Subscribe("pluginScreen", checkPluginScreen)

function PluginShutdown()
	Event.ServerLogic.Unsubscribe("pluginScreen")
	PersistentDB:SetStructuredData("favPlugins", favPlugins)
	PersistentDB:SetBool("showFav", showFav)
end