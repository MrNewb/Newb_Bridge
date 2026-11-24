local banking = {}

function banking.getAccountMoney(account)
    return exports['kartik-banking']:GetAccountMoney(account) or 0
end

function banking.addAccountMoney(account, amount, reason)
    return exports['kartik-banking']:AddAccountMoney(account, amount, reason)
end

function banking.removeAccountMoney(account, amount, reason)
    return exports['kartik-banking']:RemoveAccountMoney(account, amount, reason)
end

return banking
