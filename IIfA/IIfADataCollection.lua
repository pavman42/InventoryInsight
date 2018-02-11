local IIfA 			= IIfA
local EMPTY_STRING 	= ""

local task 			= LibStub("LibAsync"):Create("IIfA_DataCollection")
IIfA.task			= task	

local function p(...) IIfA:DebugOut(...) end

local function grabBagContent(bagId, override)
	local bagItems = GetBagSize(bagId)
	for slotId=0, bagItems, 1 do
		dbItem, itemKey = IIfA:EvalBagItem(bagId, slotId, false, nil, nil, nil, nil, override)
	end
end

function IIfA:DeleteCharacterData(name)
	if (name) then
		--delete selected character
		for characterName, character in pairs(IIfA.data.accountCharacters) do
			if(characterName == name) then
				IIfA.data.accountCharacters[name] = nil
			end
		end
	end
end

function IIfA:DeleteGuildData(name)
	if (name) then
		--delete selected guild
		for guildName, guild in pairs(IIfA.data.guildBanks) do
			if guildName == name then
				IIfA.data.guildBanks[name] = nil
			end
        end
		IIfA:ClearUnowned()
	end
end

function IIfA:CollectGuildBank()	

	-- add roomba support
	if Roomba and Roomba.WorkInProgress and Roomba.WorkInProgress() then 
		CALLBACK_MANAGER:FireCallbacks("Roomba-EndStacking", function() IIfA:CollectGuildBank() end)
		return
	end
	 
	local curGB = GetSelectedGuildBankId()

	if not IIfA.data.bCollectGuildBankData or curGB == nil then
		return
	end

	if not IIfA.data.guildBanks then IIfA.data.guildBanks = {} end
	local curGuild = GetGuildName(curGB)

	IIfA:DebugOut("Collecting Guild Bank Data for " .. curGuild)

	if IIfA.data.guildBanks[curGuild] ~= nil then
		if not IIfA.data.guildBanks[curGuild].bCollectData then
			return
		end
	end

	SelectGuildBank(CurGB)
	local count = 0

	if(IIfA.data.guildBanks[curGuild] == nil) then
		IIfA.data.guildBanks[curGuild] = {}
		IIfA.data.guildBanks[curGuild].bCollectData = true		-- default to true just so it's here and ok
	end
	
	-- call with libAsync to avoid lags
	task:Call(function()
		local guildData = IIfA.data.guildBanks[curGuild]
		guildData.items = #ZO_GuildBankBackpack.data
		guildData.lastCollected = GetDate() .. "@" .. GetFormattedTime();
		IIfA:ClearLocationData(curGuild)
		IIfA:DebugOut(" - " .. #ZO_GuildBankBackpack.data .. " items")
		for i=1, #ZO_GuildBankBackpack.data do
			local slotIndex = ZO_GuildBankBackpack.data[i].data.slotIndex
			IIfA:EvalBagItem(BAG_GUILDBANK, slotIndex)
		end
	end)
--	d("IIfA - Guild Bank Collected - " .. curGuild)
end



local function scanBags()
	local playerName = GetUnitName('player')
	
	IIfA.data.accountCharacters 			= IIfA.data.accountCharacters or {}
	IIfA.data.accountCharacters[playerName] = IIfA.data.accountCharacters[playerName] or {}
			
	IIfA:ClearLocationData(IIfA.currentCharacterId)
	
	if not IIfA:IsCharacterEquipIgnored(playerName) then 
		-- call with libAsync to avoid lags
		task:Call(function()
			grabBagContent(BAG_WORN)
		end)
	end	
	if not IIfA:IsCharacterInventoryIgnored(playerName) then 
		-- call with libAsync to avoid lags
		task:Call(function()
			grabBagContent(BAG_BACKPACK)
		end)
	end
	task:Call(function()
		IIfA:MakeBSI()
	end)
end
IIfA.ScanCurrentCharacter = scanBags

local function tryScanHouseBank()
	if GetAPIVersion() < 100022 then return end
	local bagId = GetBankingBag()
	if not bagId then return end
	local collectibleId = GetCollectibleForHouseBankBag(bagId)
	
	if IsCollectibleUnlocked(collectibleId) then
	
		IIfA:DebugOut(zo_strformat("tryScanHouseBank(<<1>>)", collectibleId))
		
		local collectibleName = GetCollectibleNickname(collectibleId)
		if collectibleName == EMPTY_STRING then collectibleName = GetCollectibleName(collectibleId) end
		-- call with libAsync to avoid lags
		task:Call(function()
			IIfA:ClearLocationData(collectibleId)
		end):Then(function()
			grabBagContent(bagId, true)
		end)
	end
	
	return true
end

function IIfA:ScanBank()

	if tryScanHouseBank() then return end
	-- call with libAsync to avoid lags
	task:Call(function()
		IIfA:ClearLocationData(GetString(IIFA_BAG_BANK))
	end):Then(function()
		grabBagContent(BAG_BANK)
	end)
	
	local slotId = nil
	if HasCraftBagAccess() then		
		task:Call(function()
			grabBagContent(BAG_SUBSCRIBER_BANK)
		end):Then(function()
			IIfA:ClearLocationData(GetString(IIFA_BAG_CRAFTBAG))
		end):Then(function()
			slotId = GetNextVirtualBagSlotId(slotId)
			while slotId ~= nil do
				IIfA:EvalBagItem(BAG_VIRTUAL, slotId)
				slotId = GetNextVirtualBagSlotId(slotId)
			end
		end)
	end
	
end

function IIfA:UpdateBSI(bagId, slotId, locationId)
	if locationId then
		IIfA:MakeBSI()
	elseif  nil ~= bagId and  nil ~= slotId and nil ~= IIfA.BagSlotInfo[bagId] then
		IIfA.BagSlotInfo[bagId][slotId] = GetItemLink(bagId, slotId)
	end
end


-- only grabs the content of bagpack and worn on the first login - hence we set the function to insta-return below.
function IIfA:OnFirstInventoryOpen()
	
	if IIfA.BagsScanned then return end
	IIfA.BagsScanned = true
	
	scanBags()
	-- call with libAsync to avoid lags
	task:Call(function()
		
	end):Then(function()
		IIfA:ScanBank()	
	end)
end

function IIfA:CheckForAgedGuildBankData( days )
	local results = false
	local days = days or 5
	if IIfA.data.bCollectGuildBankData then
		IIfA:CleanEmptyGuildBug()
		for guildName, guildData in pairs(IIfA.data.guildBanks)do
			local today = GetDate()
			local lastCollected = guildData.lastCollected:match('(........)')
			if(lastCollected and lastCollected ~= EMPTY_STRING)then
				if(today - lastCollected >= days)then
					d("[IIfA]:Warning - " .. guildName .. " Guild Bank data not collected in " .. days .. " or more days!")
					results = true
				end
			else
				d("[IIfA]:Warning - " .. guildName .. " Guild Bank data has not been collected!")
				results = true
			end
		end
		return results
	end
	return true
end

function IIfA:UpdateGuildBankData()
	if IIfA.data.bCollectGuildBankData then
		local tempGuildBankBag = {
			items = 0;
			lastCollected = EMPTY_STRING;
		}
		for index=1, GetNumGuilds() do
			local guildName = GetGuildName(index)
			local guildBank = IIfA.data.guildBanks[guildName]
			if(not guildBank) then
				IIfA.data.guildBanks[guildName] = tempGuildBankBag
			end
		end
	end
end

function IIfA:CleanEmptyGuildBug()
	local emptyGuild = IIfA.data.guildBanks[EMPTY_STRING]
	if(emptyGuild)then
		IIfA.data.guildBanks[EMPTY_STRING] = nil
	end
end

function IIfA:GuildBankReady()
	-- call with libAsync to avoid lags
	task:Call(function()
		IIfA:DebugOut("GuildBankReady...")
		IIfA.isGuildBankReady = false
		IIfA:UpdateGuildBankData()
	end):Then(function()
		IIfA:CleanEmptyGuildBug()
	end):Then(function()
		IIfA:CollectGuildBank()
	end)
end

function IIfA:GuildBankDelayReady()
	IIfA:DebugOut("GuildBankDelayReady...")
	if not IIfA.isGuildBankReady then
		IIfA.isGuildBankReady = true
		-- call with libAsync to avoid lags
		task:Call(function()
			IIfA:GuildBankReady()
		end)
	end
end

function IIfA:GuildBankAddRemove(eventID, slotId)
	IIfA:DebugOut("Guild Bank Add or Remove...")
	-- call with libAsync to avoid lags
	task:Call(function()
		IIfA:UpdateGuildBankData()
		IIfA:CleanEmptyGuildBug()
	end):Then(function()
	--IIfA:CollectGuildBank()
		local dbItem, itemKey
		if eventID == EVENT_GUILD_BANK_ITEM_ADDED then
	--		d("GB Add")
			dbItem, itemKey = IIfA:EvalBagItem(BAG_GUILDBANK, slotId, true, 0)
			IIfA:ValidateItemCounts(BAG_GUILDBANK, slotId, dbItem, itemKey)
		else
	--		d("GB Remove")
	--		d(GetItemLink(BAG_GUILDBANK, slotId))
	--		dbItem, itemKey = IIfA:EvalBagItem(BAG_BACKPACK, slotId)
	--		IIfA:ValidateItemCounts(BAG_GUILDBANK, slotId, dbItem, itemKey)
		end
	end)
end

function IIfA:ActionLayerInventoryUpdate()
	-- IIfA:CollectAll()
end


function IIfA:AddFurnitureItem(itemLink, itemCount, houseCollectibleId, fromInitialize)

	local location = houseCollectibleId
	IIfA:EvalBagItem(houseCollectibleId, IIfA:GetItemID(itemLink), false, itemCount, itemLink, GetItemLinkName(itemLink), houseCollectibleId)
end

--[[
Data collection notes:
	Currently crafting items are coming back from getitemlink with level info in them.
	If it's a crafting item, strip the level info and store only the item number as the itemKey
	Use function GetItemCraftingInfo, if usedInCraftingType indicates it's NOT a material, check for other item types

	When showing items in tooltips, check for both stolen & owned, show both
--]]

function IIfA:RescanHouse(houseCollectibleId)
	
	houseCollectibleId = houseCollectibleId or GetCollectibleIdForHouse(GetCurrentZoneHouseId())
	if not houseCollectibleId then return end
	
	if not IIfA:GetTrackedBags()[houseCollectibleId] then return end

	--- stuff them all into an array
	local function getAllPlacedFurniture()
		local ret = {}
		 while(true) do
			furnitureId = GetNextPlacedHousingFurnitureId(furnitureId)
			if(not furnitureId) then return ret end
			local itemLink = GetPlacedFurnitureLink(furnitureId, LINK_STYLE_BRACKETS)
			if not ret[itemLink] then 
				ret[itemLink] = 1
			else
				ret[itemLink] = ret[itemLink] +1
			end
		end	
	end
	
	-- call with libAsync to avoid lags
	task:Call(function()	
		-- clear and re-create, faster than conditionally updating
		IIfA:ClearLocationData(houseCollectibleId)
	end):Then(function()
		for itemLink, itemCount in pairs(getAllPlacedFurniture()) do
			IIfA:AddFurnitureItem(itemLink, itemCount, houseCollectibleId, true)
		end
	end)
	
end

-- try to read item link from bag/slot - if that's an empty string, we try to read it from BSI
local function getItemLink(bagId, slotId)
	if nil == bagId or nil == slotId then return end
	local itemLink = GetItemLink(bagId, slotId, LINK_STYLE_BRACKETS)
	if itemLink ~= "" then 
		-- got an item link, save it to the BSI for reverse lookups
		IIfA:SaveBagSlotIndex(bagId, slotId, itemLink)
		return itemLink 
	end
	if nil == IIfA.BagSlotInfo[bagId] then return end
	return IIfA.BagSlotInfo[bagId][slotId]
end

-- try to read item name from bag/slot - if that's empty, we read it from item link that we generated from BSI
local function getItemName(bagId, slotId, itemLink)
	local itemName = GetItemName(bagId, slotId)
	if "" ~= itemName then return itemName end
	if nil == itemLink then return end
	return GetItemLinkName(itemLink)
end

-- returns the item's db key, we only save under the item link if we need to save level information etc, else we use the ID
local function getItemKey(itemLink, usedInCraftingType, itemType)
	
	-- crafting materials get saved by ID
	if usedInCraftingType ~= CRAFTING_TYPE_INVALID and
	   itemType ~= ITEMTYPE_GLYPH_ARMOR and
	   itemType ~= ITEMTYPE_GLYPH_JEWELRY and
	   itemType ~= ITEMTYPE_GLYPH_WEAPON then
	   return IIfA:GetItemID(itemLink)
	end
	-- raw materials 
	itemType = itemType or GetItemLinkItemType(itemLink)
	if  itemType == ITEMTYPE_STYLE_MATERIAL or
		itemType == ITEMTYPE_ARMOR_TRAIT or
		itemType == ITEMTYPE_WEAPON_TRAIT or
		itemType == ITEMTYPE_LOCKPICK or
		itemType == ITEMTYPE_RAW_MATERIAL or
		itemType == ITEMTYPE_RACIAL_STYLE_MOTIF or		-- 9-12-16 AM - added because motifs now appear to have level info in them
		itemType == ITEMTYPE_RECIPE then
		return IIfA:GetItemID(itemLink)
	end
	return itemLink
end

local function getItemCount(bagId, slotId, itemLink)
	
	local stackCountBackpack, stackCountBank, stackCountCraftBag, itemCount
	-- first try to read item count from bag/slot
	_, itemCount =  GetItemInfo(bagId, slotId) 
	if 0 < itemCount then return itemCount end
	
	-- try to find it by item link - only works for bag_backpack / bank / virtual
	stackCountBackpack, stackCountBank, stackCountCraftBag = GetItemLinkStacks(itemLink)	
	if 		bagId == BAG_BACKPACK 	and 0 < stackCountBackpack 	then return stackCountBackpack
	elseif 	bagId == BAG_BANK 		and 0 < stackCountBank 		then return stackCountBank
	elseif 	bagId == BAG_VIRTUAL 	and 0 < stackCountCraftBag 	then return  stackCountCraftBag end
	
	-- return 1 if no slot size was found - in that case it's an equip item
	return 1
end

local function getLocation(location, bagId)
	if(bagId == BAG_BACKPACK or bagId == BAG_WORN) then
		return IIfA.currentCharacterId
	elseif(bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK) then
		return GetString(IIFA_BAG_BANK)
	elseif(bagId == BAG_VIRTUAL) then
		return GetString(IIFA_BAG_CRAFTBAG)
	elseif(bagId == BAG_GUILDBANK) then
		return GetGuildName(GetSelectedGuildBankId())
	elseif GetAPIVersion() >= 100022 and 0 < GetCollectibleForHouseBankBag(bagId) then
		return GetCollectibleForHouseBankBag(bagId)
	end
end

function IIfA:SaveBagSlotIndex(bagId, slotId, itemLink)
	if not bagId or not slotId then return end
	IIfA.BagSlotInfo[bagId] = IIfA.BagSlotInfo[bagId] or {}
	IIfA.BagSlotInfo[bagId][slotId] = IIfA.BagSlotInfo[bagId][slotId] or itemLink
end

function IIfA:AddOrRemoveFurnitureItem(itemLink, itemCount, houseCollectibleId, fromInitialize)
	-- d(zo_strformat("trying to add/remove <<1>> x <<2>> from houseCollectibleId <<3>>", itemLink, itemCount, houseCollectibleId))
	local location = houseCollectibleId
	IIfA:EvalBagItem(houseCollectibleId, IIfA:GetItemID(itemLink), false, itemCount, itemLink, GetItemLinkName(itemLink), houseCollectibleId)
end

function IIfA:EvalBagItem(bagId, slotId, fromXfer, itemCount, itemLink, itemName, locationID)
	if not IIfA.trackedBags[bagId] then return end
	
	IIfA.database = IIfA.database or {}
	local DBv3 = IIfA.database

	-- item link is either passed as arg or we need to read it from the BSI
	itemLink = itemLink or getItemLink(bagId, slotId)
	
	-- return if we don't have any item to track
	if nil == itemLink or #itemLink == 0 then return end
	
	-- item nams is either passed or we get it from bag/slot or item link
	itemName = itemName or getItemName(bagId, slotId, itemLink) or EMPTY_STRING	
	
	-- item count is either passed or we have to get it from bag/slot ID or item link
	itemCount = itemCount or getItemCount(bagId, slotId, itemLink)	
	
	-- get item key from crafting type
	local usedInCraftingType, itemType = GetItemCraftingInfo(bagId, slotId)
	
	
	local qty, itemQuality
	_, qty, _, _, _, _, _, itemQuality = GetItemInfo(bagId, slotId)
	
	if 0 == qty and itemLink then 
		itemQuality			= GetItemLinkQuality(itemLink)
		usedInCraftingType 	= GetItemLinkCraftingSkillType(itemLink)
		itemType 			= GetItemLinkItemType(itemLink)
	end
	
	itemKey = getItemKey(itemLink, usedInCraftingType, itemType)
	
	itemFilterType = GetItemFilterTypeInfo(bagId, slotId) or 0
	DBitem = DBv3[itemKey]
	location = 
	location = locationID or getLocation(location, bagId) or EMPTY_STRING
	
	if(DBitem) then
		DBitemlocation = DBitem.locations[location]
		if DBitemlocation then
			DBitemlocation.itemCount = DBitemlocation.itemCount + itemCount
			DBitemlocation.bagSlot = DBitemlocation.bagSlot or slotId
		else
			DBitem.locations[location] = {}
			DBitem.locations[location].bagID = bagId
			DBitem.locations[location].bagSlot = slotId
			DBitem.locations[location].itemCount = itemCount
		end
		if qty < 1 then
			DBitem.locations[location].itemCount = getItemCount(bagId, slotId, itemLink)
		end
	else
		DBv3[itemKey] = {}
		DBv3[itemKey].filterType = itemFilterType
		DBv3[itemKey].itemQuality = itemQuality
		DBv3[itemKey].itemName = itemName
		DBv3[itemKey].locations = {}
		DBv3[itemKey].locations[location] = {}
		DBv3[itemKey].locations[location].bagID = bagId
		DBv3[itemKey].locations[location].bagSlot = slotId
		DBv3[itemKey].locations[location].itemCount = itemCount
	end
	if zo_strlen(itemKey) < 10 then
		DBv3[itemKey].itemLink = itemLink
	end
	if (IIfA.trackedBags[bagId]) and fromXfer then
		IIfA:ValidateItemCounts(bagId, slotId, DBv3[itemKey], itemKey, itemLink, true)
	end

	return DBv3[itemKey], itemKey
	
end

function IIfA:ValidateItemCounts(bagID, slotId, dbItem, itemKey, itemLinkOverride, override)
	
	local itemCount
	local itemLink, itemLinkCheck
	if zo_strlen(itemKey) < 10 then
		itemLink = GetItemLink(bagID, slotId) or dbItem.itemLink or (override and itemLinkOverride)
	else
		itemLink = itemKey
	end
	IIfA:DebugOut(zo_strformat("ValidateItemCounts: <<1>> in bag <<2>>/<<3>>", itemLink, bagID, slotId))

	for locName, data in pairs(dbItem.locations) do
		if (data.bagID == BAG_GUILDBANK and locName == GetGuildName(GetSelectedGuildBankId())) or	
		-- we're looking at the right guild bank
			data.bagID == BAG_VIRTUAL or
			data.bagID == BAG_BANK or
			data.bagID == BAG_SUBSCRIBER_BANK or 
			nil ~= GetCollectibleForHouseBankBag and nil ~= GetCollectibleForHouseBankBag(data.bagID) or -- is housing bank, manaeeee
		   ((data.bagID == BAG_BACKPACK or data.bagID == BAG_WORN) and locName == GetCurrentCharacterId()) then
			
			itemLinkCheck = GetItemLink(data.bagID, data.bagSlot, LINK_STYLE_BRACKETS)
			if itemLinkCheck == nil then
				itemLinkCheck = (override and itemLinkOverride) or EMPTY_STRING
			end
			if itemLinkCheck ~= itemLink then
				if bagID ~= data.bagID and slotId ~= data.bagSlot then
				-- it's no longer the same item, or it's not there at all						
					IIfA.database[itemKey].locations[locName] = nil
				end
			-- item link is valid, just make sure we have our count right
			elseif bagId == data.bagID then
					_, data.itemCount = GetItemInfo(bagID, slotId)
				
			end			
		end
	end	
	-- mana: Do we need this here? It should already happen in Eval. Need to check when brain working.
	IIfA:UpdateBSI(bagID, slotId)
end



function IIfA:CollectAll()
	local bagItems = nil
	local itemLink, dbItem = nil
	local itemKey
	local location = EMPTY_STRING
	local BagList = IIfA:GetTrackedBags() -- 20.1. mana: Iterating over a list now

	for bagId, tracked in ipairs(BagList) do
		-- call with libAsync to avoid lags
		task:Call(function()		
			bagItems = GetBagSize(bagId)
			if(bagId == BAG_WORN)then	--location for BAG_BACKPACK and BAG_WORN is the same so only reset once
				IIfA:ClearLocationData(IIfA.currentCharacterId)
			elseif(bagId == BAG_BANK) then	-- do NOT add BAG_SUBSCRIBER_BANK here, it'll wipe whatever already got put into the bank on first hit
				IIfA:ClearLocationData(GetString(IIFA_BAG_BANK))
			elseif(bagId == BAG_VIRTUAL)then
				IIfA:ClearLocationData(GetString(IIFA_BAG_CRAFTBAG))
			elseif GetAPIVersion() >= 100022 then -- 20.1. mana: bag bag bag
				local collectibleId = GetCollectibleForHouseBankBag(bagId)
				if IsCollectibleUnlocked(collectibleId) then
					local name = GetCollectibleNickname(collectibleId) or GetCollectibleName(collectibleId)
					IIfA:ClearLocationData(name)
				end
			end
	--		d("  BagItemCount=" .. bagItems)
			if bagId ~= BAG_VIRTUAL and tracked then
				for slotId=0, bagItems, 1 do
					dbItem, itemKey = IIfA:EvalBagItem(bagId, slotId)
				end
			else
				if HasCraftBagAccess() then
					slotId = GetNextVirtualBagSlotId(nil)
					while slotId ~= nil do
						IIfA:EvalBagItem(bagId, slotId)
						slotId = GetNextVirtualBagSlotId(slotId)
					end
				end
			end
			
		end)
	end

	-- 6-3-17 AM - need to clear unowned items when deleting char/guildbank too
	IIfA:ClearUnowned()
end

function IIfA:TrySaveBagInfo()
	
end

function IIfA:ClearUnowned()
-- 2015-3-7 Assembler Maniac - new code added to go through full inventory list, remove any un-owned items
	local DBv3 = IIfA.database
	local n, ItemLink, DBItem
	local ItemOwner, ItemData
	for ItemLink, DBItem in pairs(DBv3) do
		n = 0
		for ItemOwner, ItemData in pairs(DBItem.locations) do
			n = n + 1
			if ItemOwner ~= "Bank" and ItemOwner ~= "CraftBag" then
				if ItemData.bagID == BAG_BACKPACK or ItemData.bagID == BAG_WORN then
					if IIfA.CharIdToName[ItemOwner] == nil then
						DBItem[ItemOwner] = nil
	  				end
				elseif ItemData.bagID == BAG_GUILDBANK then
					if IIfA.data.guildBanks[ItemOwner] == nil then
						DBItem[ItemOwner] = nil
					end
				end
			end
		end
		if (n == 0) then
			DBv3[ItemLink] = nil
		end
	end
-- 2015-3-7 end of addition
end


function IIfA:ClearLocationData(location)
	local DBv3 = IIfA.database
	local itemLocation = nil
	local LocationCount = 0
	local itemName, itemData

	if(DBv3)then
		
		IIfA:DebugOut(zo_strformat("IIfA:ClearLocationData(<<1>>)", location))
		
		for itemName, itemData in pairs(DBv3) do
			itemLocation = itemData.locations[location]
			if (itemLocation) then
				itemData.locations[location] = nil
			end
			LocationCount = 0
			for locName, location in pairs(itemData.locations) do
				LocationCount = LocationCount + 1
				break
			end
			if(LocationCount == 0)then
				DBv3[itemName] = nil
			end
		end
	end
end

-- rewrite item links with proper level value in them, instead of random value based on who knows what
-- written by SirInsidiator
local function RewriteItemLink(itemLink)
    local requiredLevel = select(6, ZO_LinkHandler_ParseLink(itemLink))
    requiredLevel = tonumber(requiredLevel)
    local trueRequiredLevel = GetItemLinkRequiredLevel(itemLink)

    itemLink = string.gsub(itemLink, "|H(%d):item:(.*)" , "|H0:item:%2")

    if requiredLevel ~= trueRequiredLevel then
        itemLink = string.gsub(itemLink, "|H0:item:(%d+):(%d+):(%d+)(.*)" , "|H0:item:%1:%2:".. trueRequiredLevel .."%4")
    end

    return itemLink
end

local function GetItemIdentifier(itemLink)
    local itemType = GetItemLinkItemType(itemLink)
    local data = {zo_strsplit(":", itemLink:match("|H(.-)|h.-|h"))}
    local itemId = data[3]
    local level = GetItemLinkRequiredLevel(itemLink)
    local cp = GetItemLinkRequiredChampionPoints(itemLink)
--	local results
--	results.itemId = itemId
--	results.itemType = itemType
--	results.level = level
--	results.cp = cp
    if(itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR) then
        local trait = GetItemLinkTraitInfo(itemLink)
        return string.format("%s,%s,%d,%d,%d", itemId, data[4], trait, level, cp)
    elseif(itemType == ITEMTYPE_POISON or itemType == ITEMTYPE_POTION) then
        return string.format("%s,%d,%d,%s", itemId, level, cp, data[23])
    elseif(hasDifferentQualities[itemType]) then
        return string.format("%s,%s", itemId, data[4])
    else
        return itemId
    end
end

function IIfA:RenameItems()
	local DBv3 = IIfA.database
	local item = nil
	local itemName

	if(DBv3)then
		for item, itemData in pairs(DBv3) do
			itemName = nil
			if item:match("|H") then
				itemName = GetItemLinkName(item)
			else
				itemName = GetItemLinkName(itemData.itemLink)
			end
			if itemName ~= nil then
				itemData.itemName = itemName
			end
		end
	end
end


