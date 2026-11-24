local banking = {}

function banking.getAccountMoney(account)
    return exports['tgiann-bank']:GetJobAccountBalance(account) or 0
end

function banking.addAccountMoney(account, amount)
    return exports['tgiann-bank']:AddJobMoney(account, amount)
end

function banking.removeAccountMoney(account, amount)
    return exports['tgiann-bank']:RemoveJobMoney(account, amount)
end

return banking
