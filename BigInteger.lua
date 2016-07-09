local bit32 = bit32

local function makepositive(val)
    local vallength = #val
    local keep
    local index
    local extraint
    local result
    local resultlength
    
    keep = 1
    while keep <= vallength and val[keep] == -1 then
        keep = keep + 1
    end
    
    index = keep
    while index <= vallength and val[index] == 0 then
        index = index + 1
    end
    
    extraint = index == vallength + 1 and 1 or 0
    resultlength = vallength - keep + extraint
    result = {}
    
    index = keep
    while index <= vallength do
        result[index - keep + extraint + 1] = bit32.bnot(val[index])
        index = index + 1
    end
    
    index = vallength
    result[index] = result[index] + 1
    while result[index] == 0 do
        index = index - 1
        result[index] = result[index] + 1
    end
    
    return result
end

local function copyofrange(val, start, fin)
    local copy = {}
    
    for index = start, fin do
        copy[index - start + 1] = val[index]
    end
    
    return copy
end

local function stripleadingzeros(val)
    local vallength = #val
    local keep = 1
    
    while keep <= vallength and val[keep] == 0 do
        keep = keep + 1
    end
    
    return copyofrange(val, keep, vallength)
end

local function createbiginteger(mag, signum)
    return {mag = mag, signum = signum}
end

function biginteger(val)
    local mag, signum
    if #val == 0 then
        error("Zero length BigInteger")
    end
    
    if val[1] < 0 then
        mag = makepositive(val)
        signum = -1
    else
        mag = stripleadingzeros(val)
        signum = #mag == 0 and 0 or 1
    end
    --if #mag >= MAX_MAG_LENGTH then
        --checkrange(mag)
    --end
    return createbiginteger(mag, signum)
end
