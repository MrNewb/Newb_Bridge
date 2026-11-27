local banking = {}

function banking.getAccountMoney(account)
    local row = exports['ShitDevScripts-Banking']:GetSocietyAccount(account)
    return row and tonumber(row.balance) or 0
end

function banking.addAccountMoney(account, amount, reason)
    return exports['ShitDevScripts-Banking']:AddSocietyMoney(account, amount, 'deposit', reason)
end

function banking.removeAccountMoney(account, amount, reason)
    return exports['ShitDevScripts-Banking']:RemoveSocietyMoney(account, amount, 'withdrawal', reason)
end

return banking
