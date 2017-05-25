--[[
Wisent - a framework for free positioning of buffs.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to:
	
Free Software Foundation, I.,
51 Franklin Street, Fifth Floor,
Boston, MA  02110-1301, USA.
--]]

local MAJOR = "combo"

local Addon  = LibStub( "AceAddon-3.0"):GetAddon( "Wisent")
local L      = LibStub( "AceLocale-3.0"):GetLocale( "Wisent")
local AceGUI = LibStub( "AceGUI-3.0")

local NOTHING = {}
local UPDATE_TIME = 0.2
local MAX_BUTTON  = 5

local Module = Addon:NewBarModule( MAJOR)
Module.filter  = "HELPFUL"
Module.color   = { r=0.2, g=0.4, b=0.9 }
Module.proName = "combo"

local args = {
	option = { 
		type = "group", order = 10, name = L.OptionName, inline = true, 
		args = {
			show     = { type = "toggle", order = 10, name = L.ShowName,     desc = L.ShowDesc, width = "full" },
--			sort     = { type = "select", order = 20, name = L.SortName,     desc = L.SortDesc, get = "GetSortType", set = "SetSortType", values = "GetSortDesc" },
			timer    = { type = "select", order = 30, name = L.TimerName,    desc = L.TimerDesc, values = "GetTimerDesc" },
			flashing = { type = "toggle", order = 40, name = L.FlashingName, desc = L.FlashingDesc },
--			spell    = { type = "toggle", order = 50, name = L.SpellName,    desc = L.SpellDesc },
		} 
	},
	layout = { 
		type = "group", order = 20, name = L.BarName, inline = true, 
		args = {
			horizontal = { type = "toggle", order = 10, name = L.HorizontalName, desc = L.HorizontalDesc, width = "full" },
--			number     = { type = "range",  order = 30, name = L.NumberName,     desc = L.NumberDesc,   set = "SetNumber",   min = 1,    max = MAX_BUTTON, step = 1 },
			scale      = { type = "range",  order = 40, name = L.ScaleName,      desc = L.ScaleDesc,    set = "SetScale",    min = 0.01, max = 2,          step = 0.01, isPercent = true },
			cols       = { type = "range",  order = 50, name = L.ColsName,       desc = L.ColsDesc,     set = "SetCols",     min = 1,    max = MAX_BUTTON, step = 1 },
			xPadding   = { type = "range",  order = 60, name = L.XPaddingName,   desc = L.XPaddingDesc, set = "SetXPadding", min = -20,  max = 20,         step = 1 },
			rows       = { type = "range",  order = 70, name = L.RowsName,       desc = L.RowsDesc,     set = "SetRows",     min = 1,    max = MAX_BUTTON, step = 1 },
			yPadding   = { type = "range",  order = 80, name = L.YPaddingName,   desc = L.YPaddingDesc, set = "SetYPadding", min = -50,  max = 50,         step = 1 },
			bigger     = { type = "range",  order = 90, name = L.BiggerName,     desc = L.BiggerDesc,   set = "SetBigger",   min = 1,    max = 2,          step = 0.01, isPercent = true },
		} 
	}
}
local blizzOptions = {
	type = "group", order = 50, name = L.DescProgs, handler = Module, get = "GetProperty", set = "SetProperty", args = args
}
local dialogOptions = {
	type = "group", order = 20, name = L.BarCombo, handler = Module, get = "GetProperty", set = "SetProperty", args = args,
	plugins = {
		p1 = { 
			descr = { type = "description", order = 5, name = L.DescProgs, fontSize = "large" }
		}
	}
}
local comboIcon
local comboSpell
local comboFkt
local comboCount = 5

------------------------------------------------------------------------------------
-- Main
------------------------------------------------------------------------------------
function Module:OnModuleInitialize()
	self:RegisterOptions( blizzOptions, L.BarCombo)
	for i = 1,5 do
		tinsert( self.aura, { id = i, name = "__combo__", count = 1 })
	end
end

function Module:OnModuleEnable()
	self:ACTIVE_TALENT_GROUP_CHANGED()
	self:RegisterEvent( "ACTIVE_TALENT_GROUP_CHANGED")
end

function Module:GetOptionTable()
	return dialogOptions
end

function Module:UpdateAnchors( sort)
--	Addon:Debug( self, ":UpdateAnchors", self.profile.show)
	if self.profile.show and comboIcon and PlayerFrame.unit == "player" then
		local maxStacks = comboFkt and comboFkt() or 0
--		Addon:Debug( self, ":UpdateAnchors", maxStacks)
		for i,a in pairs( self.aura) do
			local buff = self:GetUserBuff( "BuffComboButton", a.id)
			local child = self.group.children[i]
			child:SetUserData( "bigger", i == comboCount)
			if child and i <= maxStacks then -- Display one icon per power
				buff:SetScript( "OnEnter", nil)
				a.texture = comboIcon
				self:UpdateLBF( buff)
				-- MOD
				self:UpdateMasque(buff)
				-- /MOD
				buff:Show()
				local icon = _G[buff:GetName().."Icon"] -- TODO: Rename to icon1, icon2 etc?
				if icon then
					icon:SetTexture( a.texture)
				end
--				if GameTooltip:IsOwned( buff) and comboSpell then
--					GameTooltip:SetSpell( comboSpell, "spell")
--				end
				child:SetBuff( buff)
			elseif child then
				a.texture = nil
				buff:Hide()
				child:SetBuff( nil)
			else
				a.texture = nil
				buff:Hide()
			end
		end
	end
end

function Module:UpdateEnchantAnchors()
	self:UpdateAnchors()
end

function Module:MoveTo( offset)
	for i,child in pairs( self.group.children) do
		child:SetBuff( nil)
	end
	for id = 1,#self.aura do
		local buff = self:GetUserBuff( "BuffComboButton", id)
		buff:Hide()
		buff.duration:Hide()
		buff:SetScript( "OnUpdate", nil)
	end
end

------------------------------------------------------------------------------------
-- Local
------------------------------------------------------------------------------------
local function ScanAura( unit, id, filter)
	local name = GetSpellInfo( id)
	local _, _, _, count = UnitAura( unit, name, nil, filter)
	return count or 0
end


-- local function PointsWarlock()
	-- return UnitPower( "player", SPELL_POWER_SOUL_SHARDS)
-- end

------------------------------------------------------------------------------------
-- Event
------------------------------------------------------------------------------------

	-- LUT for the class powers / GetClassPowers (stored here to avoid excess garbage creation)
	local classPowers = {
		{  -- 1		Warrior		WARRIOR
			{	-- 1	Arms > Nothing
			["GetCurrentStacks"] = function()
					return 0
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "",
			},
		
			{	-- 2	Fury > Furious Slash
				["GetCurrentStacks"] = function()
					return ScanAura("player", 100130, "HELPFUL")
				end,
				["maxStacks"] = 5, -- TODO
				["spell"] = 100130,
				["icon"] = "ability_warrior_weaponmastery", 
			},
		
			{	-- 3	Protection > Nothing
				["GetCurrentStacks"] = function()
					return 0
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "",
			}
		},
		
		{  -- 2		Paladin		PALADIN
			{	-- 1	Holy > Nothing
				["GetCurrentStacks"] = function()
					return 0
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "",
			},
		
			{	-- 2	Protection > Nothing
				["GetCurrentStacks"] = function()
					return 
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "", 
			},
		
			{	-- 3	Retribution > Holy Power
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_HOLY_POWER)
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "Spell_Holy_HolyBolt",
			}
		
		},		

		{  -- 3 		Hunter 	HUNTER
			{	-- 1	Beast Mastery > Nothing
			["GetCurrentStacks"] = function()
					return 0
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "",
			},
		
			{	-- 2	Marksmanship > Nothing
				["GetCurrentStacks"] = function()
					return 0
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "", 
			},
		
			{	-- 3	Survival > Mongoose Fury
				["GetCurrentStacks"] = function()
					return ScanAura("player", 190928, "HELPFUL")
				end,
				["maxStacks"] = 6,
				["spell"] = 190931,
				["icon"] = "ability_hunter_mongoosebite",
			}
		},

		{  -- 4		Rogue		ROGUE
			{	-- 1	Assassination > Combo Points
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_COMBO_POINTS)
				end,
				["maxStacks"] = 10,
				["spell"] = 0,
				["icon"] = "Ability_DualWield",
			},
		
			{	-- 2	Outlaw > Combo Points
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_COMBO_POINTS)
				end,
				["maxStacks"] = 10,
				["spell"] = 0,
				["icon"] = "Ability_DualWield", 
			},
		
			{	-- 3	Subtletly > Combo Points
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_COMBO_POINTS)
				end,
				["maxStacks"] = 10,
				["spell"] = 0,
				["icon"] = "Ability_DualWield",
			}
		
		},		
	
		{  -- 5 		Priest 	PRIEST
			{	-- 1	Discipline > Nothing
			["GetCurrentStacks"] = function()
					return 0
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "",
			},
		
			{	-- 2	Holy > Nothing
				["GetCurrentStacks"] = function()
					return 0
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "", 
			},
		
			{	-- 3	Shadow > Voidform
				["GetCurrentStacks"] = function()
					return ScanAura(227386)
				end,
				["maxStacks"] = 100, -- TODO
				["spell"] = 227386,
				["icon"] = "spell_priest_voidform",
			}
		},

		{  -- 6		Death Knight		DEATHKNIGHT
			{	-- 1	Blood > Runes
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_RUNES)
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "spell_shadow_rune",
			},
		
			{	-- 2	Frost > Runes
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_RUNES)
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "spell_shadow_rune", 
			},
		
			{	-- 3	Unholy > Runes
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_RUNES)
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "spell_shadow_rune",
			}
		
		},		
	
		{  -- 7 		Shaman 	SHAMAN
			{	-- 1	Elemental > Lava Surge
			["GetCurrentStacks"] = function()
					return ScanAura("player", 77762, "HELPFUL")
				end,
				["maxStacks"] = 2,
				["spell"] = 77762,
				["icon"] = "spell_shaman_lavasurge",
			},
		
			{	-- 2	Enhancement > Stormbringer
				["GetCurrentStacks"] = function()
					return ScanAura("player", 201845, "HELPFUL")
				end,
				["maxStacks"] = 2,
				["spell"] = 201845, -- 17364
				["icon"] = "ability_shaman_stormstrike",  -- spell_nature_stormreach
			},
		
			{	-- 3	Restoration > Tidal Waves
				["GetCurrentStacks"] = function()
					return ScanAura("player", 53390, "HELPFUL")
				end,
				["maxStacks"] = 2,
				["spell"] = 53390,
				["icon"] = "spell_shaman_tidalwaves",
			}
		},

		{  -- 8		Mage		MAGE
			{	-- 1	Arcane > Arcane Charges
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_ARCANE_CHARGES)
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "ability_mage_arcanebarrage",
			},
		
			{	-- 2	Frost > Fingers of Frost
				["GetCurrentStacks"] = function()
					return ScanAura("player", 112965, "HELPFUL")
				end,
				["maxStacks"] = 2,
				["spell"] = 44544,
				["icon"] = "ability_mage_wintersgrasp", 
			},
		
			{	-- 3	Fire > Nothing
				["GetCurrentStacks"] = function()
					return 0
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "",
			}
		
		},			
		
		{  -- 9		Warlock		WARLOCK
			{	-- 1	Affliction > Soul Shards
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_SOUL_SHARDS)
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "INV_Misc_Gem_Amethyst_02",
			},
		
			{	-- 2	Demonology > Soul Shards
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_SOUL_SHARDS)
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "INV_Misc_Gem_Amethyst_02", 
			},
		
			{	-- 3	Destruction > Soul Shards
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_SOUL_SHARDS)
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "INV_Misc_Gem_Amethyst_02",
			}
		
		},		
		
		{  -- 10		Monk		MONK
			{	-- 1	Brewmaster > Chi
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_CHI)
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "ability_monk_chiwave",
			},
		
			{	-- 2	Mistweaver > Chi
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_CHI)
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "ability_monk_chiwave", 
			},
		
			{	-- 3	Windwalker > Chi
				["GetCurrentStacks"] = function()
					return UnitPower( "player", SPELL_POWER_CHI)
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "ability_monk_chiwave",
			}
		
		},		
			
		{  -- 11 		Druid 	DRUID
			{	-- 1	Balance > Nothing
			["GetCurrentStacks"] = function()
					return 0
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "",
			},
		
			{	-- 2	Feral > Combo Points
				["GetCurrentStacks"] = function()
					return UnitPower("player",  SPELL_POWER_COMBO_POINTS)  -- TODO: Cat/bear form differentiation?  ->		if GetShapeshiftFormID() == BEAR_FORM then // 	elseif GetShapeshiftFormID() == CAT_FORM then
				end,
				["maxStacks"] = 5,
				["spell"] = 0,
				["icon"] = "Ability_DualWield", 
			},
		
			{	-- 3	Guardian > Lacerate
				["GetCurrentStacks"] = function()
					return ScanAura("target", 61896, "HARMFUL") -- TODO: Show one stack with count for different targets?
				end,
				["maxStacks"] = 5,
				["spell"] = 61896,
				["icon"] = "ability_druid_lacerate",
			},
			
			{	-- 4	Restoration > Nothing
				["GetCurrentStacks"] = function()
					return 0
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "",
			}
			
		},

		{	-- 12		Demon Hunter		DEMONHUNTER
			{	-- 1	Havoc > Nothing
			["GetCurrentStacks"] = function()
					return 0
				end,
				["maxStacks"] = 0,
				["spell"] = 0,
				["icon"] = "",
			},
		
			{	-- 2	Vengeance > Demon Spikes
				["GetCurrentStacks"] = function()
					return ScanAura("player", 203720, "HELPFUL")
				end,
				["maxStacks"] = 2,
				["spell"] = 203720,
				["icon"] = "ability_demonhunter_demonspikes", 
			},
		
		},
	
	}


-- Returns the updateFunction, maxStacks, spellID, icon for each class/spec
local function GetClassPowers(classID, specID)

	if not (classID or specID or classPowers[classID] or classPowers[classID][specID]) then return end -- Invalid parameters -> skip and let the caller deal with the nil value/error out
	
	return classPowers[classID][specID]

end

-- Update comboBar icons (Called on each buff:update event)
function Module:ACTIVE_TALENT_GROUP_CHANGED()

	local localizedClassName, class, classID = UnitClass( "player")
	local specID = GetSpecialization()
	local specName = GetSpecializationInfo(specID)
	
	Addon:Debug(self, format("ACTIVE_TALENT_GROUP_CHANGED (Current spec: %s - %s for class %s / %s)", specID, specName, class, localizedClassName))

	-- Get info to display with the icon for this class/spec
	local powers = GetClassPowers(classID, specID)
	if not powers then -- Not a valid class/spec combination -> Skip update
		Addon:Debug(self, "Invalid parameters given when calling GetClassPowers")
		return
	end
	
	-- TODO: Only one power per class is supported?
	local GetCurrentStacks, maxStacks, spellID, icon = powers["GetCurrentStacks"], powers["maxStacks"], powers["spell"], powers["icon"]

	-- TODO: Rework this to be more universal/reusable? It*s kind of awkward in its original design
	comboCount = maxStacks
	comboIcon = "Interface\\Icons\\" .. icon
	comboSpell = spellID -- will be displayed on icon:mouseover -> set to nil for resources (Combo Points, Holy Power, ...)
	comboFkt = function() -- This is the function that will be called every time the icon is supposed to update
		
		if GetCurrentStacks then
			return GetCurrentStacks() or 0 -- Returns the current stacks for the respective class/spec
		end
		
		return 0
		
	end

end

-- TODO: Is it still necessary?
function Module:UPDATE_SHAPESHIFT_FORM()
	self:ACTIVE_TALENT_GROUP_CHANGED()
end
