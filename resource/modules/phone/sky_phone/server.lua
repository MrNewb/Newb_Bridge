local phone = {}

function phone.getPlayerPhone(src)
    return exports.sky_phone:GetEquippedPhoneNumber(src) or false
end

-- sky_phone has no export that sends a system mail, so this always reports that nothing was sent.
function phone.sendEmail()
    return false
end

return phone
