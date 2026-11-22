local progressbar = {}

function progressbar.openprogressbar(data)
    if not data then return false end

    return lib.progressBar(data)
end

function progressbar.progressActive()
    return lib.progressActive()
end

function progressbar.cancelProgress()
    lib.cancelProgress()
end

progressbar.openProgressBar = progressbar.openprogressbar

return progressbar
