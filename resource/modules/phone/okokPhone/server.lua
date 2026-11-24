local phone = {}

function phone.getPlayerPhone(src)
    return exports.okokPhone:getPhoneNumberFromSource(src) or false
end

function phone.sendEmail(src, email, title, message)
    local address = exports.okokPhone:getEmailAddressFromSource(src)
    if not address then return false end

    return exports.okokPhone:sendEmail({
        sender = email,
        recipients = { address },
        subject = title,
        body = message,
    }) or false
end

return phone
