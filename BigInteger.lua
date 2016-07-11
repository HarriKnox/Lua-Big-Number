-- Local fields/constants
local bit32 = bit32
local math = math
local maxinteger = math.maxinteger or (2 ^ 53 - 1)


local bitsperdigit = {   0, 1024, 1624, 2048, 2378, 2648,
                      2875, 3072, 3247, 3402, 3543, 3672,
                      3790, 3899, 4001, 4096, 4186, 4271,
                      4350, 4426, 4498, 4567, 4633, 4696,
                      4756, 4814, 4870, 4923, 4975, 5025,
                      5074, 5120, 5166, 5210, 5253, 5295}

-- Testing functions
local function isvalidbytearray(val)
    for i = 1, #val do
        if type(val[i]) ~= 'number' then
            return false
        end
    end
    return true
end

local function isvalidradix(radix)
    return radix >= 2 and radix <= 36 and radix % 1 == 0
end

local function isvalidstringnumber(str)
    return not not string.match(str, '^[%-+]?[0-9A-Za-z]+$')
end


-- Helper Functions
local function make32bitinteger(number)
    return bit32.bor(number, 0)
end

local function getdigitvalue(character)
    local bytevalue = string.byte(character)
    
    if bytevalue >= 48 and bytevalue <= 57 then -- if character is a number, returns in [0, 9]
        return bytevalue - 48
    elseif bytevalue >= 65 and bytevalue <= 90 then -- if character is uppercase Latin, returns in [10, 35]
        return bytevalue - 55
    elseif bytevalue >= 97 and bytevalue <= 122 then -- if character is lowercase Latin, returns in [10, 35]
        return bytevalue - 87
    end
end

local function copyofrange(val, start, fin)
    local copy = {}
    
    for index = start, fin do
        copy[index - start + 1] = make32bitinteger(val[index])
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

local function makepositive(val)
    local vallength = #val
    local keep
    local index
    local extraint
    local result
    local resultlength
    
    keep = 1
    while keep <= vallength and val[keep] == -1 do
        keep = keep + 1
    end
    
    index = keep
    while index <= vallength and val[index] == 0 do
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


-- Constructors
local function createbiginteger(val, sig)
    return {mag = val, signum = sig}
end

local function constructornumber(num)
    local mag, signum
    local higherword
    
    if num < 0 then
        signum = -1
        num = -num
    else
        signum = num == 0 and 0 or 1
    end
    
    if num > maxinteger then
        error("Number too large to be an integer")
    end
    
    higherword = math.floor(num / (2 ^ 32))
    lowerword = make32bitinteger(num)
    
    mag = stripleadingzeros({higherword, lowerword})
    
    return createbiginteger(mag, signum)
end

local function constructorsignmagnitude(sig, val)
    local mag, signum
    if sig < -1 or sig > 1 or sig % 1 ~= 0 then
        error("Invalid sign value", 3)
    end
    
    if not isvalidbytearray(val) then
        error("Invalid byte array", 3)
    end
    
    mag = stripleadingzeros(val)
    
    if #mag == 0 then
        signum = 0
    else
        if sig == 0 then
            error("Sign-magnitude mismatch", 3)
        end
        signum = sig
    end
    --if #mag >= MAX_MAG_LENGTH then
        --checkrange(mag)
    --end
    
    return createbiginteger(mag, signum)
end

local function constructormagnitude(val)
    local mag, signum
    if #val == 0 then
        error("Zero length BigInteger", 3)
    end
    if not validbytearray(val) then
        error("Invalid byte array", 3)
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

local function constructorstringradix(str, radix)
    local mag, signum
    
    local strlength = #str
    local sign, cursor, strsign, numberofdigits
    local numberofbits, numberofwords, magnitude
    local firstgrouplength, superradix, groupvalue
    
    if not isvalidradix(radix) then
        error("Invalid radix: " .. radix, 3)
    end
    
    if not isvalidstringnumber(str) then
        error("Invalid string integer", 3)
    end
    
    strsign = string.match(str, '[-+]')
    
    sign = strsign == '-' and -1 or 1
    cursor = strsign and 2 or 1
    
    if cursor == strlength then
        error("Zero length BigInteger", 3)
    end
    
    while cursor <= strlength and string.sub(str, cursor, cursor) == '0' then
        cursor = cursor + 1
    end
    
    if cursor == strlength then
        return createbiginteger({}, 0)
    end
    
    numberofdigits = strlength - cursor
    numberofbits = bit32.lrshift(numberofdigits * bitsperdigit[radix], 10) + 1
    
end


local biginteger
function biginteger(a, b)
    local typea = type(a)
    local typeb = type(b)
    
    if typea == "number" then
        if typeb == "nil" then
            return constructornumber(a)
        elseif typeb == "table" then
            return constructorsignmagnitude(a, b)
        end
    elseif typea == "table" and typeb == "nil" then
        return constructormagnitude(a)
    elseif typea == "string" then
        if typeb == "nil" then
            return constructorstringradix(a, 10)
        elseif typeb == "number" then
            return constructorstringradix(a, b)
        end
    end
    
    error("Could not understand passed parameters: " .. typea .. " and " .. typeb, 2)
end

if _CC_VERSION then
    if tonumber(_CC_VERSION) < 1.75 then
        error("BigInteger library compatibility for ComputerCraft requires CC version 1.75 or later")
    end
    _ENV.biginteger = biginteger
    return
end

return {biginteger = biginteger}
