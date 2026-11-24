local banking = {}

function banking.getAccountMoney(account)
    return exports.wasabi_banking:GetAccountBalance(account, 'society') or 0
end

function banking.addAccountMoney(account, amount)
    return exports.wasabi_banking:AddMoney('society', account, amount)
end

function banking.removeAccountMoney(account, amount)
    return exports.wasabi_banking:RemoveMoney('society', account, amount)
end

return banking
