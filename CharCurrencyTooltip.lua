local CharCurrencyFrame = ZO_Object:Subclass()
if IIfA == nil then IIfA = {} end
IIfA.CharCurrencyFrame = CharCurrencyFrame

function CharCurrencyFrame:SetQty(control, field, fieldType, qty)
	local ctl = control:GetNamedChild(field)
	if qty == nil then
		qty = 0
	end
	ZO_CurrencyControl_SetSimpleCurrency(ctl, fieldType, qty, ZO_KEYBOARD_CARRIED_CURRENCY_OPTIONS)
	-- text in control looks like this
    -- "@|u0:4:currency:1,748,124|u|t12:12:EsoUI/Art/currency/currency_gold.dds|t",
	-- need to chop off the |t and all after to get rid of the icon

	local ctlText = ctl:GetText()
	ctl:SetText(ctlText:sub(1, ctlText:find("|t") - 1))
end

function CharCurrencyFrame:UpdateAssets()
	if self.currAssets ~= nil then
		self.currAssets.gold = GetCarriedCurrencyAmount(CURT_MONEY)
		self.currAssets.tv = GetCarriedCurrencyAmount(CURT_TELVAR_STONES)
		self.currAssets.ap = GetCarriedCurrencyAmount(CURT_ALLIANCE_POINTS)
		self.currAssets.wv = GetCarriedCurrencyAmount(CURT_WRIT_VOUCHERS)
	end
end

function CharCurrencyFrame:FillCharAndBank()
	self:UpdateAssets()

	local gold = self.currAssets.gold
	local tv = self.currAssets.tv
	local ap = self.currAssets.ap
	local wv = self.currAssets.wv

	self:SetQty(self.charControl, "qtyGold", CURT_MONEY, gold)
	self:SetQty(self.charControl, "qtyTV", CURT_TELVAR_STONES, tv)
	self:SetQty(self.charControl, "qtyAP", CURT_ALLIANCE_POINTS, ap)
	self:SetQty(self.charControl, "qtyWV", CURT_WRIT_VOUCHERS, wv)

	self:SetQty(self.bankControl, "qtyGold", CURT_MONEY, GetBankedCurrencyAmount(CURT_MONEY))
	self:SetQty(self.bankControl, "qtyTV", CURT_TELVAR_STONES, GetBankedCurrencyAmount(CURT_TELVAR_STONES))
	self:SetQty(self.bankControl, "qtyAP", CURT_ALLIANCE_POINTS, GetBankedCurrencyAmount(CURT_ALLIANCE_POINTS))
	self:SetQty(self.bankControl, "qtyWV", CURT_WRIT_VOUCHERS, GetBankedCurrencyAmount(CURT_WRIT_VOUCHERS))

	gold = gold + GetBankedCurrencyAmount(CURT_MONEY) + self.totGold
	tv = tv + GetBankedCurrencyAmount(CURT_TELVAR_STONES) + self.totTV
	ap = ap + GetBankedCurrencyAmount(CURT_ALLIANCE_POINTS) + self.totAP
	wv = wv + GetBankedCurrencyAmount(CURT_WRIT_VOUCHERS) + self.totWV

	self:SetQty(self.totControl, "qtyGold", CURT_MONEY, gold)
	self:SetQty(self.totControl, "qtyTV", CURT_TELVAR_STONES, tv)
	self:SetQty(self.totControl, "qtyAP", CURT_ALLIANCE_POINTS, ap)
	self:SetQty(self.totControl, "qtyWV", CURT_WRIT_VOUCHERS, wv)

-- field width testing
--	self:SetQty(self.totControl, "qtyGold", CURT_MONEY, 99999999)
--	self:SetQty(self.totControl, "qtyTV", CURT_TELVAR_STONES, 99999999)
--	self:SetQty(self.totControl, "qtyAP", CURT_ALLIANCE_POINTS, 99999999)
end


function CharCurrencyFrame:Initialize(objectForAssets)
	self.frame = IIFA_CharCurrencyFrame
	local tControl
	local prevControl = self.frame
	local currId = GetCurrentCharacterId()

	if objectForAssets.assets == nil then
		objectForAssets.assets = {}
	end
	local assets = objectForAssets.assets

	if assets[currId] == nil then
		assets[currId] = {}
		assets[currId].gold = 0
		assets[currId].tv = 0
		assets[currId].ap = 0
		assets[currId].wv = 0
	else
		if assets[currId].gold == nil then
			assets[currId].gold = 0
		end
		if assets[currId].tv == nil then
			assets[currId].tv = 0
		end
		if assets[currId].ap == nil then
			assets[currId].ap = 0
		end
		if assets[currId].wv == nil then
			assets[currId].wv = 0
		end
	end

	self.currAssets = assets[currId]

	self.frame:SetAnchor(TOPLEFT, IIFA_GUI_Header_GoldButton, TOPRIGHT, 5, 0)
	self.totGold = 0
	self.totTV = 0
	self.totAP = 0
	self.totWV = 0

	for i=1, GetNumCharacters() do
		local charName, _, _, _, _, _, charId, _ = GetCharacterInfo(i)
		charName = charName:sub(1, charName:find("%^") - 1)
		tControl = CreateControlFromVirtual("IIFA_GUI_AssetsGrid_Row_" .. i, self.frame, "IIFA_CharCurrencyRow")
		if i == 1 then
			tControl:SetAnchor(TOPLEFT, prevControl:GetNamedChild("_Title"), BOTTOMLEFT, 0, 26)
		else
			tControl:SetAnchor(TOPLEFT, prevControl, BOTTOMLEFT, 0, 2)
		end
		tControl:GetNamedChild("charName"):SetText(charName)
		if GetCurrentCharacterId() == charId then
			self.charControl = tControl
		else
			if assets[charId] ~= nil then
				if assets[charId].gold == nil then
					assets[charId].gold = 0
				end
				self.totGold = self.totGold + assets[charId].gold

				if assets[charId].tv == nil then
					assets[charId].tv = 0
				end
				self.totTV = self.totTV + assets[charId].tv

				if assets[charId].ap == nil then
					assets[charId].ap = 0
				end
				self.totAP = self.totAP + assets[charId].ap

				if assets[charId].wv == nil then
					assets[charId].wv = 0
				end
				self.totWV = self.totWV + assets[charId].wv

				self:SetQty(tControl, "qtyGold", CURT_MONEY, assets[charId].gold)
				self:SetQty(tControl, "qtyTV", CURT_TELVAR_STONES, assets[charId].tv)
				self:SetQty(tControl, "qtyAP", CURT_ALLIANCE_POINTS, assets[charId].ap)
				self:SetQty(tControl, "qtyWV", CURT_WRIT_VOUCHERS, assets[charId].wv)
			end
		end
		prevControl = tControl
	end
	tControl = CreateControlFromVirtual("IIFA_GUI_AssetsGrid_Row_Bank", self.frame, "IIFA_CharCurrencyRow")
	tControl:GetNamedChild("charName"):SetText("Bank")
	tControl:SetAnchor(TOPLEFT, prevControl, BOTTOMLEFT, 0, 0)
	self.bankControl = tControl

	tControl = CreateControlFromVirtual("IIFA_GUI_AssetsGrid_Row_Tots", self.frame, "IIFA_CharCurrencyRow")
	tControl:GetNamedChild("charName"):SetText("Totals")
	tControl:SetAnchor(TOPLEFT, self.bankControl, BOTTOMLEFT, 0, 0)
	self.totControl = tControl

	self.frame:SetHeight((GetNumCharacters() + 4) * 26)	-- numchars + 4 represents # chars + bank + total + title and col titles

	self:FillCharAndBank()

	self.isInitialized = true
end

function CharCurrencyFrame:Show(control)
	if self.isInitialized == nil then return end
	if not self.isShowing then
		self.isShowing = true
		self:FillCharAndBank()
		self.frame:SetHidden(false)
	end
end

function CharCurrencyFrame:Hide(control)
	if self.isInitialized == nil then return end
	if self.isShowing then
		self.isShowing = false
		self.frame:SetHidden(true)
	end
end

