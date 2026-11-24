local banking = {}

function banking.getAccountMoney(account)
    return exports['okokBanking']:GetAccount(account) or 0
end

function banking.addAccountMoney(account, amount)
    return exports['okokBanking']:AddMoney(account, amount)
end

function banking.removeAccountMoney(account, amount)
    return exports['okokBanking']:RemoveMoney(account, amount)
end

return banking
