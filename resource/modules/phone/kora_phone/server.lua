local phone = {}

function phone.getPlayerPhone(src)
    return exports.kora_phone:GetPhoneNumber(src) or false
end

function phone.sendEmail(src, email, title, message)
    local citizenId = bridge.framework.getIdentifier(src)
    if not citizenId then return false end

    return exports.kora_phone:SendSystemMail(tostring(citizenId), {
        sender = email,
        subject = title,
        message = message,
    }) or false
end

return phone
