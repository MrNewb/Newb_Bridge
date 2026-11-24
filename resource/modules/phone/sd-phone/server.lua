local phone = {}

-- sd-phone has no number export of its own; its lb-phone compatibility layer answers this one.
function phone.getPlayerPhone(src)
    return exports['lb-phone']:GetEquippedPhoneNumber(src) or false
end

function phone.sendEmail(src, email, title, message)
    local accounts = exports['sd-phone']:getMailAccounts(src)
    local address = accounts[1] and accounts[1].email
    if not address then return false end

    local result = exports['sd-phone']:sendMail({
        to = address,
        subject = title,
        body = message,
        from = { name = email },
    })
    return result.success == true
end

return phone
