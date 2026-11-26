local banking = {}

local function societyAccount(account)
    if type(account) ~= 'string' or account == '' then return nil end
    local ok, row = pcall(function()
        return exports['ShitDevScripts-Banking']:GetSocietyAccount(account)
    end)
    if not ok then return nil end
    return row
end

function banking.getAccountMoney(account)
    local row = societyAccount(account)
    if not row then return nil end
    return tonumber(row.balance) or 0
end

function banking.addAccountMoney(account, amount, reason)
    return exports['ShitDevScripts-Banking']:AddSocietyMoney(account, amount, 'deposit', reason)
end

function banking.removeAccountMoney(account, amount, reason)
    return exports['ShitDevScripts-Banking']:RemoveSocietyMoney(account, amount, 'withdrawal', reason)
end

return banking
