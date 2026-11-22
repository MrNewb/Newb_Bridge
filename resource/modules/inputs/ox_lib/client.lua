local inputs = {}

function inputs.inputdialog(heading, rows, options)
    return lib.inputDialog(heading, rows, options)
end

function inputs.closeinput()
    return lib.closeInputDialog()
end

return inputs
