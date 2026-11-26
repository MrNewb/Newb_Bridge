local banking = {}

function banking.getAccountMoney(account)
    return exports.lation_banking:GetAccountBalance(account) or 0
end

function banking.addAccountMoney(account, amount, reason)
    return (exports.lation_banking:AddAccountMoney(account, amount, reason))
end

function banking.removeAccountMoney(account, amount, reason)
    return (exports.lation_banking:RemoveAccountMoney(account, amount, reason))
end

return banking
