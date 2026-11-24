local banking = {}

function banking.getAccountMoney(account)
    return exports['fd_banking']:GetAccount(account) or 0
end

function banking.addAccountMoney(account, amount, reason)
    return exports['fd_banking']:AddMoney(account, amount, reason)
end

function banking.removeAccountMoney(account, amount, reason)
    return exports['fd_banking']:RemoveMoney(account, amount, reason)
end

return banking
