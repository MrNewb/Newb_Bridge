local phone = {}

function phone.getPlayerPhone(src)
    return exports['lb-phone']:GetEquippedPhoneNumber(src) or false
end

function phone.sendEmail(src, email, title, message)
    local number = exports['lb-phone']:GetEquippedPhoneNumber(src)
    if not number then return false end

    local address = exports['lb-phone']:GetEmailAddress(number)
    if not address then return false end

    local sent = exports['lb-phone']:SendMail({
        to = address,
        sender = email,
        subject = title,
        message = message,
    })
    return sent or false
end

return phone
