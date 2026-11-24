local phone = {}

function phone.getPlayerPhone(src)
    return exports.yseries:GetPhoneNumberBySourceId(src) or false
end

function phone.sendEmail(src, email, title, message)
    local number = exports.yseries:GetPhoneNumberBySourceId(src)
    if not number then return false end

    local _, received = exports.yseries:SendMail({
        title = title,
        sender = email,
        senderDisplayName = email,
        content = message,
    }, 'phoneNumber', number)
    return received or false
end

return phone
