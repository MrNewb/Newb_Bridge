local banking = {}

-- ESX society money lives in esx_addonaccount shared accounts named society_<job>.
local function societyAccount(account)
    local found
    TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. account, function(shared) found = shared end)
    return found
end

function banking.getAccountMoney(account)
    local shared = societyAccount(account)
    return shared and shared.money or 0
end

function banking.addAccountMoney(account, amount)
    local shared = societyAccount(account)
    if not shared then return false end
    shared.addMoney(amount)
    return true
end

function banking.removeAccountMoney(account, amount)
    local shared = societyAccount(account)
    if not shared or shared.money < amount then return false end
    shared.removeMoney(amount)
    return true
end

return banking
