local phone = {}

function phone.getPlayerPhone(src)
    return exports['qs-base']:GetPlayerPhone(src) or false
end

-- qs-smartphone mails have no sender field, so the sender address is not shown.
function phone.sendEmail(src, email, title, message)
    return exports['qs-smartphone']:SendMail(src, title, message) or false
end

return phone
