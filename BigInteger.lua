-- Local fields/constants
local bit32 = bit32
local math = math
local maxinteger = math.maxinteger or (2 ^ 53 - 1)
local maxmagnitudelength = 2 ^ 32

-- Number of bits contained in a digit grouping in a string integer
-- rounded up, indexed by radix
local bitsperdigit = {
      0, 1024, 1624, 2048, 2378, 2648,
   2875, 3072, 3247, 3402, 3543, 3672,
   3790, 3899, 4001, 4096, 4186, 4271,
   4350, 4426, 4498, 4567, 4633, 4696,
   4756, 4814, 4870, 4923, 4975, 5025,
   5074, 5120, 5166, 5210, 5253, 5295}

-- The number of digits of a given radix that can fit in a 32 bit integer
-- without overflowing or going negative, indexed by radix
local digitsperinteger = {
    0, 30, 19, 15, 13, 11,
   11, 10,  9,  9,  8,  8,
    8,  8,  7,  7,  7,  7,
    7,  7,  7,  6,  6,  6,
    6,  6,  6,  6,  6,  6,
    6,  6,  6,  6,  6,  5}

-- Casts each number to "int digits" which contain the number of digits
-- specified in digitsperinteger
-- intradix[radix] = radix * digitsperinteger[radix]
local intradix = {
   0x00000000, 0x40000000, 0x4546b3db, 0x40000000, 0x48c27395, 0x159fd800,
   0x75db9c97, 0x40000000, 0x17179149, 0x3b9aca00, 0x0cc6db61, 0x19a10000,
   0x309f1021, 0x57f6c100, 0x0a2f1b6f, 0x10000000, 0x18754571, 0x247dbc80,
   0x3547667b, 0x4c4b4000, 0x6b5a6e1d, 0x06c20a40, 0x08d2d931, 0x0b640000,
   0x0e8d4a51, 0x1269ae40, 0x17179149, 0x1cb91000, 0x23744899, 0x2b73a840,
   0x34e63b41, 0x40000000, 0x4cfa3cc1, 0x5c13d840, 0x6d91b519, 0x039aa400}

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

local function long32bitrightshift(number)
   return math.floor(number / 0x100000000)
end

local function long16bitrightshift(number)
   return math.floor(number / 0x10000)
end

local function long32bitleftshift(number)
   return number * 0x100000000
end

local function long16bitleftshift(number)
   return number * 0x10000
end

local function integermultiplicationandaddtolong(x, ab, c)
   local a = bit32.rshift(ab, 16)
   local b = bit32.band(ab, 0xffff)
   
   local xa = x * a
   local xb = x * b
   
   local xahigh = long16bitrightshift(xa)
   local xalow = bit32.lshift(xa, 16)
   
   local xbhigh = long32bitrightshift(xb)
   local xblow = bit32.bor(xb, 0)
   
   local lowword = xalow + xblow + c
   local highword = xahigh + xbhigh + long32bitrightshift(lowword)
   lowword = bit32.bor(lowword, 0)
   
   return highword, lowword
end

local function getdigitvalue(character)
   local bytevalue = string.byte(character)
   
   if bytevalue >= 48 and bytevalue <= 57 then
      -- if character is a number, returns in [0, 9]
      return bytevalue - 48
   elseif bytevalue >= 65 and bytevalue <= 90 then
      -- if character is uppercase Latin, returns in [10, 35]
      return bytevalue - 55
   elseif bytevalue >= 97 and bytevalue <= 122 then
      -- if character is lowercase Latin, returns in [10, 35]
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

local function destructivemultiplyandadd(mag, factor, addend)
   local maglength = #mag
   local product = 0
   local carry = 0
   local index = maglength
   local sum = 0
   
   while index > 0 do
      carry, mag[index] = integermultiplyandaddtolong(factor, mag[index], carry)
      index = index - 1
   end
   
   carry = addend
   index = maglength
   while index > 0 do
      sum = mag[index] + carry
      carry = long32bitrightshift(sum)
      mag[index] = make32bitinteger(sum)
      index = index - 1
   end
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
   
   higherword = long32bitrightshift(num)
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
   local sign, cursor, strsign, numberofdigits, digitsperintegerradix
   local numberofbits, numberofwords, tempmagnitude
   local firstgrouplength, superradix, group, groupvalue
   -- Some edits and changes occurred here
   if not isvalidradix(radix) then
      error("Invalid radix: " .. radix, 3)
   end
   
   if not isvalidstringnumber(str) then
      error("Invalid string integer", 3)
   end
   
   strsign = string.match(str, '[-+]')
   
   sign = strsign == '-' and -1 or 1
   cursor = strsign and 2 or 1
   
   if string.match(str, '^[-+]?0+') then
      return createbiginteger({}, 0)
   end
   
   while cursor <= strlength and string.sub(str, cursor, cursor) == '0' then
      cursor = cursor + 1
   end
   -- Back to Java-faithful code
   numberofdigits = strlength - cursor
   signum = sign
   
   numberofbits = bit32.lrshift(numberofdigits * bitsperdigit[radix], 10) + 1
   
   if numberofbits + 31 >= maxmagnitudelength then
      error("BigInteger would overflow supported range", 3)
   end
   
   numberofwords = bit32.lrshift(numberofbits + 31, 5)
   tempmagnitude = {}
   
   -- a small deviation but here to prevent numerous calls to digitsperinteger
   digitsperintegerradix = digitsperinteger[radix]
   
   firstgrouplength = numberofdigits % digitsperintegerradix
   if firstgrouplength == 0 then
      firstgrouplength = digitsperintegerradix
   end
   -- Process first group
   group = string.sub(val, cursor, cursor + firstgrouplength)
   cursor = cursor + firstgrouplength
   groupvalue = tonumber(group, radix)
   if not groupvalue then
      error("Illegal digit", 3)
   end
   tempmagnitude[numberofwords] = groupvalue
   
   -- Process remaining groups
   superradix = intradix[radix]
   while cursor <= strlength do
      group = string.sub(val, cursor, cursor + digitsperintegerradix)
      cursor = cursor + digitsperintegerradix
      groupvalue = tonumber(group, radix)
      if not groupvalue then
         error("Illegal digit", 3)
      end
      destructivemultiplyandadd(tempmagnitude, superradix, groupvalue)
   end
   
   mag = stripleadingzeros(tempmagnitude)
   return createbiginteger(mag, signum)
end


local function biginteger(a, b)
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
   
   error("Could not understand passed parameters: " ..
      typea .. " and " .. typeb, 2)
end

if _CC_VERSION then
   if tonumber(_CC_VERSION) < 1.75 then
      error("BigInteger library compatibility for ComputerCraft requires CC " ..
         "version 1.75 or later")
   end
   _ENV.biginteger = biginteger
   return
end

return {biginteger = biginteger}
