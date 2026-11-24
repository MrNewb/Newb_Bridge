local phone = {}

function phone.getPlayerPhone(src)
    return exports.gksphone:GetPhoneBySource(src) or false
end

function phone.sendEmail(src, email, title, message)
    exports.gksphone:SendNewMail(src, {
        sender = email,
        image = '/html/static/img/icons/mail.png',
        subject = title,
        message = message,
    })
    return true
end

return phone
