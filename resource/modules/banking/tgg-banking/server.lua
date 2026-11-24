local banking = {}

function banking.getAccountMoney(account)
    return exports['tgg-banking']:GetSocietyAccountMoney(account) or 0
end

function banking.addAccountMoney(account, amount)
    return exports['tgg-banking']:AddSocietyMoney(account, amount)
end

function banking.removeAccountMoney(account, amount)
    return exports['tgg-banking']:RemoveSocietyMoney(account, amount)
end

return banking
