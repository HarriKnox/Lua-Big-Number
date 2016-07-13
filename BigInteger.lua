-- Local fields/constants
local bitand = (bit32 or bit).band
local bitor = (bit32 or bit).bor
local bitnot = (bit32 or bit).bnot
local bitxor = (bit32 or bit).bxor
local bitleftshift = (bit32 and bit32.lshift) or (bit and bit.blshift)
local bitrightshift = (bit32 and bit32.rshift) or (bit and bit.blogit_rshift)
local bitarithmaticrightshift = (bit32 and bit32.arshift) or (bit and bit.brshift)

local floor = floor or math.floor
local max = max or math.max
local min = min or math.min
local random = random or math.random

local maxinteger = math.maxinteger or (2 ^ 53 - 1)
local maxmagnitudelength = 67108864 -- Integer.maxvalue / Integer.size = 2 ^ 26

local stringsub = string.sub
local stringmatch = string.match

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
local function isbiginteger(bigint)
   return type(bigint) == 'table' and bigint.magnitude and bigint.sign
end

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
   return not not stringmatch(str, '^[%-+]?[0-9A-Za-z]+$')
end


-- Helper Functions
local function make32bitinteger(number)
   return bitand(number, 0xffffffff)
end

local function long32bitrightshift(number)
   return floor(number / 0x100000000)
end

local function long16bitrightshift(number)
   return floor(number / 0x10000)
end

local function long32bitleftshift(number)
   return number * 0x100000000
end

local function long16bitleftshift(number)
   return number * 0x10000
end

local function integermultiplyandaddtolong(x, ab, c)
   local a = bitrightshift(ab, 16)
   local b = bitand(ab, 0xffff)
   
   local xa = x * a
   local xb = x * b
   
   local xahigh = long16bitrightshift(xa)
   local xalow = bitleftshift(xa, 16)
   
   local xbhigh = long32bitrightshift(xb)
   local xblow = make32bitinteger(xb)
   
   local lowword = xalow + xblow + c
   local highword = xahigh + xbhigh + long32bitrightshift(lowword)
   lowword = make32bitinteger(lowword)
   
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
   local vallength = #val
   
   if start < 0 then
      -- adjust for negative index (index from end of val)
      start = vallength + start + 1
   end
   if fin < 0 then
      fin = vallength + fin + 1
   end
   
   if start > fin then
      error("start > fin")
   end
   
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
      result[index - keep + extraint + 1] = bitnot(val[index])
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
   return {magnitude = val, sign = sig}
end

local function constructornumber(num)
   local signum
   local higherword
   
   if num < 0 then
      signum = -1
      num = -num
   else
      signum = num == 0 and 0 or 1
   end
   
   if num > maxinteger then
      error("Number too large to be an integer", 3)
   end
   
   higherword = long32bitrightshift(num)
   lowerword = make32bitinteger(num)
   
   return createbiginteger(stripleadingzeros({higherword, lowerword}), signum)
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
   if #mag >= maxmagnitudelength then
      error("BigInteger would overflow supported range", 3)
   end
   
   return createbiginteger(mag, signum)
end

local function constructorbitsrng(bitlength, randomnumbergenerator)
   local tempmagnitude = {}
   local numberofwords, excessbytes
   
   if bitlength < 0 or bitlength % 1 ~= 0 then
      error("bitlength must be a non-negative integer", 3)
   end
   
   if type(randomnumbergenerator()) ~= "number" then
      error("RNG function must return a number between 0 and 1", 3)
   end
   
   numberofwords = floor((bitlength + 15) / 16)
   for i = 1, numberofwords do
      tempmagnitude[i] = floor(randomnumbergenerator() * 0x10000) * 0x10000 + floor(randomnumbergenerator() * 0x10000)
   end
   
   excessbytes = 16 * numberofwords - bitlength
   tempmagnitude[1] = bitand(tempmagnitude[1], 2 ^ (16 - excessbytes) - 1)
   
   return createbiginteger(stripleadingzeros(tempmagnitude), 1)
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
   if #mag >= maxmagnitudelength then
      error("BigInteger would overflow supported range", 3)
   end
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
   
   strsign = stringmatch(str, '[-+]')
   
   sign = strsign == '-' and -1 or 1
   cursor = strsign and 2 or 1
   
   if stringmatch(str, '^[-+]?0+$') then
      return createbiginteger({}, 0)
   end
   
   while cursor <= strlength and stringsub(str, cursor, cursor) == '0' do
      cursor = cursor + 1
   end
   -- Back to Java-faithful code
   numberofdigits = strlength - cursor + 1
   signum = sign
   
   numberofbits = bitrightshift(numberofdigits * bitsperdigit[radix], 10) + 1
   
   if numberofbits + 31 > 0xffffffff then
      error("BigInteger would overflow supported range", 3)
   end
   
   numberofwords = bitrightshift(numberofbits + 31, 5)
   tempmagnitude = {}
   for i = 1, numberofwords do
      tempmagnitude[i] = 0
   end
   
   -- a small deviation but here to prevent numerous calls to digitsperinteger
   digitsperintegerradix = digitsperinteger[radix]
   
   firstgrouplength = numberofdigits % digitsperintegerradix
   if firstgrouplength == 0 then
      firstgrouplength = digitsperintegerradix
   end
   
   -- Process first group
   group = stringsub(str, cursor, cursor + firstgrouplength - 1)
   cursor = cursor + firstgrouplength
   groupvalue = tonumber(group, radix)
   
   if not groupvalue then
      error("Illegal digit", 3)
   end
   tempmagnitude[numberofwords] = groupvalue
   
   -- Process remaining groups
   superradix = intradix[radix]
   while cursor <= strlength do
      group = stringsub(str, cursor, cursor + digitsperintegerradix - 1)
      cursor = cursor + digitsperintegerradix
      groupvalue = tonumber(group, radix)
      if not groupvalue then
         error("Illegal digit", 3)
      end
      destructivemultiplyandadd(tempmagnitude, superradix, groupvalue)
   end
   
   mag = stripleadingzeros(tempmagnitude)
   if #mag >= maxmagnitudelength then
      error("BigInteger would overflow supported range", 3)
   end
   return createbiginteger(mag, signum)
end

-- Main Constructor
-- will interpret passed arguments to call appropriate constructor
local function biginteger(a, b)
   local typea = type(a)
   local typeb = type(b)
   
   if typea == "number" then
      if typeb == "nil" then
         return constructornumber(a)
      elseif typeb == "table" then
         return constructorsignmagnitude(a, b)
      elseif typeb == "function" then
         return constructorbitsrng(a, b)
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


-- Comparison Functions
local function equals(thisbigint, thatbigint)
   local thismag, thatmag
   
   if rawequal(thisbigint, thatbigint) then
      return true
   end
   
   if not isbiginteger(thatbigint) then
      return false
   end
   
   if thisbigint.sign ~= thatbigint.sign then
      return false
   end
   
   thismag = thisbigint.magnitude
   thatmag = thatbigint.magnitude
   
   if #thismag ~= #thatmag then
      return false
   end
   
   for i = 1, #thismag do
      if thismag[i] ~= thatmag[i] then
         return false
      end
   end
   return true
end

local function compare(thisbigint, thatbigint)
   local thismag, thatmag
   
   if rawequal(thisbigint, thatbigint) then
      return 0
   end
   
   if thisbigint.sign ~= thatbigint.sign then
      -- If the signs differ, then they cannot be equal
      return thisbigint.sign > thatbigint.sign and 1 or -1
   end
   
   thismag = thisbigint.magnitude
   thatmag = thatbigint.magnitude
   
   if #thismag ~= #thatmag then
      -- If the numbers are different sizes, then they cannot be equal
      return #thismag > #thatmag and 1 or -1
   end
   
   for i = 1, #thismag do
      if thismag[i] ~= thatmag[i] then
         return thismag[i] > thatmag[i] and 1 or -1
      end
   end
   
   return 0
end

-- Math Functions
local function negate(bigint)
   return createbiginteger(copyofrange(bigint.magnitude, 1, -1), -bigint.sign)
end

local function abs(bigint)
   return bigint.sign < 0 and negate(bigint) or bigint
end


-- Computercraft `os.loadAPI` compatibility
if _CC_VERSION then
   if tonumber(_CC_VERSION) < 1.75 then
      error("BigInteger library compatibility for ComputerCraft requires CC " ..
         "version 1.75 or later", 2)
   end
   _ENV.biginteger = biginteger
   return
end

--[[ Uncomment for testing
_G.bi = biginteger
_G.cp = copyofrange
_G.negate = negate
_G.abs = abs
_G.compare = compare
_G.equals = equals
--]]
return {biginteger = biginteger}
