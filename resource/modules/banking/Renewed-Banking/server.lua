local banking = {}

function banking.getAccountMoney(account)
    return exports['Renewed-Banking']:getAccountMoney(account) or 0
end

function banking.addAccountMoney(account, amount)
    return exports['Renewed-Banking']:addAccountMoney(account, amount)
end

function banking.removeAccountMoney(account, amount)
    return exports['Renewed-Banking']:removeAccountMoney(account, amount)
end

return banking
