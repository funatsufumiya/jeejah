function printTable(t)
    printTableImpl(t)
    io.write("\n")
end

function printTableImpl(t, level)
    level = level or 0
    if type(t) == "table" then
        io.write("{\n")
        for key, value in pairs(t) do
            io.write(string.rep("\t", level) .. string.format("[%s] = ", key))
            printTableImpl(value, level)
            io.write(",\n")
        end
        io.write("}")
    else
        io.write(tostring(t))
    end
end

return {printTable=printTable}