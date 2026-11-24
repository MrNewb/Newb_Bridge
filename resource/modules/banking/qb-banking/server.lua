local banking = {}

function banking.getAccountMoney(account)
    return exports['qb-banking']:GetAccountBalance(account) or 0
end

function banking.addAccountMoney(account, amount, reason)
    return exports['qb-banking']:AddMoney(account, amount, reason)
end

function banking.removeAccountMoney(account, amount, reason)
    return exports['qb-banking']:RemoveMoney(account, amount, reason)
end

return banking
