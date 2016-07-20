local bi = {} -- Sandbox for testing purposes. That's why all the 'local's are commented out.
setmetatable(bi, {__index = _G})
_ENV = bi

--[[
Since I would inevitably need to write this, I'll just write it now to get it
taken care of right away. Here are some definitions:
   1) valid 32 bit integer: a value of type 'number' that is non-negative, less
      than 2 ^ 32, and an integer (no decimal)
   2) byte-array: a sequence (table) of numbers that follows these rules
      a) all numbers are valid 32 bit integers
      b) the array is one-indexed (indices start at 1 not 0)
      c) a zero-length array is logically equivalent to 0 (zero)
      d) if the first element is negative (in two's-compliment form) then the
         byte-array is considered negative (leading zeros will prevent the first
         non-zero element from being interpreted as negative)
      e) Note: For testing and iterating through byte-arrays the default length
         operator (#) is used. This means that the byte-array must have a
         sequence of numbers for all indices between 1 and #array. If
         #array == 0 then the byte-array is still valid: it has a zero-length
         sequence. Since a byte-array is a table, it may have keys and values
         that are not in the sequence (such as t.name = 'Bob'). For a sequence
         to be valid there must be no holes
         (that is for all 1 <= i <= #array t[i] ~= nil).
   3) magnitude: inherently unsigned; a type of byte-array with exceptions:
      a) all numbers are treated as unsigned (ignores negatives in
         two's-compliment form)
      b) leading zeros are not allowed, and thus a magnitude of only zeros is
         not allowed
   4) sign: Either -1, 0, or 1; determines whether the value is negative, zero,
      or positive, respectively. A sign of 0 cannot be assigned to a value that
      is not logically equivalent to 0 (zero)
   5) biginteger: a table with (at minimum) two values (sign and magnitude) such
      that every integer is logically equivalent to a unique combination of sign
      and magnitude.
--]]

-- Local fields/constants
--local
bitand = (bit32 or bit).band
--local
bitor = (bit32 or bit).bor
--local
bitnot = (bit32 or bit).bnot
--local
bitxor = (bit32 or bit).bxor
--local
bitleftshift = (bit32 and bit32.lshift) or (bit and bit.blshift)
--local
bitrightshift = (bit32 and bit32.rshift) or (bit and bit.blogit_rshift)
--local
bitarithmaticrightshift = (bit32 and bit32.arshift) or (bit and bit.brshift)
--local
bitandnot = function(x, y) return bitand(x, bitnot(y)) end

--local
floor = floor or math.floor
--local
max = max or math.max
--local
min = min or math.min
--local
random = random or math.random

--local
maxinteger = math.maxinteger or 0x7ffffffffffff
--local
maxmagnitudelength = 0x4000000 -- Integer.MAX_VALUE / Integer.SIZE  + 1 = 1 << 26
--local
negativemask = 0x80000000

--local
stringsub = string.sub
--local
stringmatch = string.match

-- Number of bits contained in a digit grouping in a string integer
-- rounded up, indexed by radix
--local
bitsperdigit = {
      0, 1024, 1624, 2048, 2378, 2648,
   2875, 3072, 3247, 3402, 3543, 3672,
   3790, 3899, 4001, 4096, 4186, 4271,
   4350, 4426, 4498, 4567, 4633, 4696,
   4756, 4814, 4870, 4923, 4975, 5025,
   5074, 5120, 5166, 5210, 5253, 5295}

-- The number of digits of a given radix that can fit in a 32 bit integer
-- without overflowing or going negative, indexed by radix
--local
digitsperinteger = {
    0, 30, 19, 15, 13, 11,
   11, 10,  9,  9,  8,  8,
    8,  8,  7,  7,  7,  7,
    7,  7,  7,  6,  6,  6,
    6,  6,  6,  6,  6,  6,
    6,  6,  6,  6,  6,  5}

-- Casts each number to "int digits" which contain the number of digits
-- specified in digitsperinteger
-- intradix[radix] = radix * digitsperinteger[radix]
--local
intradix = {
   0x00000000, 0x40000000, 0x4546b3db, 0x40000000, 0x48c27395, 0x159fd800,
   0x75db9c97, 0x40000000, 0x17179149, 0x3b9aca00, 0x0cc6db61, 0x19a10000,
   0x309f1021, 0x57f6c100, 0x0a2f1b6f, 0x10000000, 0x18754571, 0x247dbc80,
   0x3547667b, 0x4c4b4000, 0x6b5a6e1d, 0x06c20a40, 0x08d2d931, 0x0b640000,
   0x0e8d4a51, 0x1269ae40, 0x17179149, 0x1cb91000, 0x23744899, 0x2b73a840,
   0x34e63b41, 0x40000000, 0x4cfa3cc1, 0x5c13d840, 0x6d91b519, 0x039aa400}


--local
characters = {
   '1', '2', '3', '4', '5', '6', '7',
   '8', '9', 'A', 'B', 'C', 'D', 'E',
   'F', 'G', 'H', 'I', 'J', 'K', 'L',
   'M', 'N', 'O', 'P', 'Q', 'R', 'S',
   'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
   [0] = '0'}


-- Testing functions
--local
function isvalidinteger(int)
   if type(int) ~= 'number' then
      return false, "value is not a number"
   elseif int > maxinteger or int < -maxinteger then
      return false, "number magnitude is outside the allowed range"
   elseif int % 1 ~= 0 then
      return false, "number not an integer"
   end
   return true
end

--local
function isvalid32bitinteger(int)
   if type(int) ~= 'number' then
      return false, "value is not a number"
   elseif int > 0xffffffff or int < 0 then
      return false, "number is outside 32 bits"
   elseif int % 1 ~= 0 then
      return false, "number is not an integer"
   end
   
   return true
end

--local
function isvalidbytearray(val)
   local ok, reason
   if type(val) ~= 'table' then
      return false, "value is not an array"
   end
   for i = 1, #val do
      ok, reason = isvalid32bitinteger(val[i])
      if not ok then
         return false, "element " .. i .. " not a 32 bit number: " .. reason
      end
   end
   return true
end

--local
function isvalidmagnitude(mag)
   local ok, reason
   ok, reason = isvalidbytearray(mag)
   if not ok then
      return false, "not a valid byte-array: " .. reason
   end
   if #mag == 0 then
      return true
   end
   if mag[1] == 0 then
      return false, "magnitude has leading zeros"
   end
   return true
end

--local
function isvalidsign(sign)
   if type(sign) ~= 'number' then
      return false, "sign is not a number"
   elseif sign ~= -1 and sign ~= 0 and sign ~= 1 then
      return false, "sign is not in {-1, 0, 1}"
   end
   return true
end

--local
function isvalidsignmagnitudecombination(sign, mag)
   if sign == 0 and #mag ~= 0 then
      -- logically equal to 0 (zero)
      return false, "zero sign with non-zero magnitude"
   elseif sign ~= 0 and #mag == 0 then
   -- logically cannot equal 0 (zero)
      return false, "non-zero sign with zero magnitude"
   end
   return true
end

--local
function isvalidbiginteger(bigint)
   local ok, reason
   if type(bigint) ~= 'table' then
      return false, "value is not an object"
   end
   
   ok, reason = isvalidsign(bigint.sign)
   if not ok then
      return false, "value's sign is not valid: " .. reason
   end
   
   ok, reason = isvalidmagnitude(bigint.magnitude)
   if not ok then
      return false, "value's magnitude is not valid: " .. reason
   end
   
   ok, reason = isvalidsignmagnitudecombination(bigint.sign, bigint.magnitude)
   if not ok then
      return false, "value has sign-magnitude mismatch: " .. reason
   end
   
   return true
end

--local
function isvalidoperablenumber(thing)
   if isvalidinteger(thing) or isvalidbytearray(thing) or isvalidbiginteger(thing) then
      return true
   end
   return false, "value is not an operable number"
end

--local
function isvalidradix(radix)
   local ok, reason
   
   ok, reason = isvalidinteger(radix)
   if not ok then
      return false, "value is not a valid radix: " .. reason
   elseif radix < 2 or radix > 36 then
      return false, "radix is outside allowable range"
   end
   
   return true
end

--local
function isvalidstringnumber(str)
   if stringmatch(str, '^[%-+]?[0-9A-Za-z]+$') then
      return true
   end
   return false, "value is not a valid string-representation of a biginteger"
end


-- Helper Bitwise Functions
--local
function make32bitinteger(number)
   return bitand(number, 0xffffffff)
end

--local
function long32bitrightshift(number)
   return floor(number / 0x100000000)
end

--local
function long16bitrightshift(number)
   return floor(number / 0x10000)
end

--local
function long32bitleftshift(number)
   return number * 0x100000000
end

--local
function long16bitleftshift(number)
   return number * 0x10000
end


-- Helper Integer and Long Functions
--local
function splitlong(number)
   return long32bitrightshift(number), make32bitinteger(number)
end

--local
function splitlongandstripleadingzeros(number)
   local highword, lowword = splitlong(number)
   
   if highword == 0 then
      if lowword == 0 then
         return {}
      end
      return {lowword}
   end
   return {highword, lowword}
end

--local
function integermultiplyandaddtolong(x, ab, c)
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


-- Byte Array Functions
--local
function copyarray(arr)
   local copy = {}
   
   for i = 1, #arr do
      copy[i] = arr[i]
   end
   
   return copy
end

--local
function copyandstripleadingzeros(val)
   local vallength = #val
   local difference = vallength
   local copy
   local endpoint
   
   for i = 1, vallength do
      if val[i] ~= 0 then
         difference = i - 1
         break
      end
   end
   if difference == 0 then
      return copyarray(val)
   end
   
   copy = {}
   endpoint = max(vallength - difference, difference)
   for i = 1, endpoint do
      copy[i] = val[i + difference]
   end
   
   return copy
end

--local
function destructivestripleadingzeros(mag)
   local maglen = #mag
   local difference = maglen
   local endpoint
   
   for i = 1, maglen do
      if mag[i] ~= 0 then
         difference = i - 1
         break
      end
   end
   
   if difference ~= 0 then
      endpoint = max(maglen - difference, difference)
      for i = 1, endpoint do
         mag[i], mag[i + difference] = mag[i + difference], nil
      end
   end
   
   return mag
end

--local
function destructiveaddonetobytearray(bytearray)
   local addend = 1
   local index = #bytearray
   
   while addend ~= 0 and index > 0 do
      addend, bytearray[index] = splitlong(bytearray[index] + addend)
      index = index - 1
   end
   
   if addend ~= 0 then
      table.insert(bytearray, 1, addend)
   end
   
   return bytearray
end

--local
function negatebytearray(bytearray)
   local mag = {}
   local balen = #bytearray
   
   for i = 1, balen do
      mag[i] = bitnot(bytearray[i])
   end
   
   destructiveaddonetobytearray(mag)
   return destructivestripleadingzeros(mag)
end

--local
function destructivemultiplyandadd(mag, factor, addend)
   local maglength = #mag
   local product = 0
   local carry = 0
   local index = maglength
   
   while index > 0 do
      carry, mag[index] = integermultiplyandaddtolong(factor, mag[index], carry)
      index = index - 1
   end
   
   carry = addend
   index = maglength
   while index > 0 do
      carry, mag[index] = splitlong(mag[index] + carry)
      index = index - 1
   end
   
   return mag
end


-- Private Getter functions
--local
function gettype(thing)
   return (isvalidinteger(thing) and 'integer') or
          (isvalidbiginteger(thing) and 'biginteger') or
          (isvalidbytearray(thing) and 'byte-array') or
          type(thing)
end

--local
function getbytearraysign(thing)
   if #thing == 0 then
      return 0
   end
   if thing[1] >= negativemask then
      return -1
   end
   for i = 1, #thing do
      if thing[i] ~= 0 then
         return 1
      end
   end
   return 0
end

--local
function getbytearraymagnitude(thing)
   if getbytearraysign(thing) == -1 then
      return negatebytearray(thing)
   end
   return copyandstripleadingzeros(thing)
end

--local
function getbytearraysignandmagnitude(thing)
   local sign = getbytearraysign(thing)
   if sign == -1 then
      return sign, negatebytearray(thing)
   end
   return sign, copyandstripleadingzeros(thing)
end

--local
function getnumbersign(thing)
   return (thing < 0 and -1) or (thing > 0 and 1) or 0
end

--local
function getnumbermagnitude(thing)
   return splitlongandstripleadingzeros(thing < 0 and -thing or thing)
end

--local
function getnumbersignandmagnitude(thing)
   return getnumbersign(thing), getnumbermagnitude(thing)
end

--local
function getsign(thing)
   if isvalidbiginteger(thing) then
      return thing.sign
      
   elseif isvalidbytearray(thing) then
      return getbytearraysign(thing)
      
   elseif isvalidinteger(thing) then
      return getnumbersign(thing)
   end
   error("cannot obtain sign")
end

--local
function getmagnitude(thing)
   if isvalidbiginteger(thing) then
      return thing.magnitude
      
   elseif isvalidbytearray(thing) then
      return getbytearraymagnitude(thing)
      
   elseif isvalidinteger(thing) then
      return getnumbermagnitude(thing)
   end
   error("cannot obtain magnitude")
end

--local
function getsignandmagnitude(thing)
   if isvalidbiginteger(thing) then
      return thing.sign, thing.magnitude
      
   elseif isvalidbytearray(thing) then
      return getbytearraysignandmagnitude(thing)
      
   elseif isvalidinteger(thing) then
      return getnumbersignandmagnitude(thing)
   end
   error("cannot obtain sign and magnitude")
end

--local
function getfirstnonzerointfromend(mag)
   local maglen = #mag
   for i = 0, maglen - 1 do
      if mag[maglen - i] ~= 0 then
         return i
      end
   end
end

--local
function getintfromend(mag, disp)
   local maglen = #mag
   
   if disp < 0 or disp >= maglen then
      return 0
   end
   return mag[maglen - disp]
end

--local
function getintfromendwithsign(bigint, disp)
   -- Get the 32 bit integer segment that is disp from the end,
   -- disp = 0 will return the last segment
   local magint, signint
   local bimag, bisign, bilen
   
   bisign, bimag = getsignandmagnitude(bigint)
   bilen = #bimag
   signint = bisign == -1 and -1 or 0
   
   if disp >= bilen then
      return signint
   end
   
   if disp < 0 then
      return 0
   end
   
   magint = bimag[bilen - disp]
   
   if signint == 0 then
      return magint
   end
   
   if disp <= getfirstnonzerointfromend(bimag) then
      if magint == 0 then
         return 0
      end
      -- 2's compliment of magint since the return value must be non-negative
      return bitnot(magint) + 1
   end
   return bitnot(magint)
end

-- Magnitude Mappers
--local
function mapmagnitude(bigint, mapfunction)
   local mag
   local bimag
   
   bimag = getmagnitude(bigint)
   mag = {}
   for i = 1, #bimag do
      mag[i] = mapfunction(bimag[i])
   end
   
   return mag
end

--local
function mergemagnitudes(thisbigint, thatbigint, mergefunction)
   local mag, thismag, thatmag
   local thislen, thatlen, longerlen
   
   thismag = getmagnitude(thisbigint)
   thatmag = getmagnitude(thatbigint)
   
   longerlen = max(#thismag, #thatmag)
   
   mag = {}
   for i = 0, longerlen - 1 do
      mag[longerlen - i] = mergefunction(getintfromendwithsign(thisbigint, i),
                                         getintfromendwithsign(thatbigint, i))
   end
   return mag
end


-- Other Helper Functions
--local
function getcharvalue(character)
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
   -- if character is not valid in base36, then return 36 to always fail test
   return 36
end


-- Constructors
--local
function createbiginteger(sign, mag)
   local ok, reason
   
   ok, reason = isvalidsign(sign)
   if ok then
      ok, reason = isvalidmagnitude(mag)
      if ok then
         ok, reason = isvalidsignmagnitudecombination(sign, mag)
         if ok then
            return {sign = sign, magnitude = mag}
         end
      end
   end
   error(reason, 4)
end

--local
function constructorinteger(num)
   local ok, reason = isvalidinteger(num)
   if not ok then
      error(reason, 3)
   end
   
   return createbiginteger(getnumbersignandmagnitude(num))
end

--local
function constructorsignmagnitude(sign, val)
   local mag
   local ok, reason
   
   ok, reason = isvalidsign(sign)
   if not ok then
      error(reason, 3)
   end
   
   ok, reason = isvalidbytearray(val)
   if not ok then
      error(reason, 3)
   end
   
   mag = copyandstripleadingzeros(val)
   
   ok, reason = isvalidsignmagnitudecombination(sign, mag)
   if not ok then
      error(reason, 3)
   end
   
   if #mag >= maxmagnitudelength then
      error("biginteger would overflow supported range", 3)
   end
   
   return createbiginteger(sign, mag)
end

--local
function constructorbitsrng(bitlength, randomnumbergenerator)
   local mag = {}
   local numberofwords, excessbytes
   
   if bitlength < 0 or bitlength % 1 ~= 0 then
      error("bit length must be a non-negative integer", 3)
   end
   
   if type(randomnumbergenerator()) ~= "number" then
      error("RNG function must return a number in the range [0, 1)", 3)
   end
   
   numberofwords = floor((bitlength + 31) / 32)
   for i = 1, numberofwords do
      -- This weird multiplication-addition is necessary since the default
      -- math.random would not operate on all 32 bits
      mag[i] = make32bitinteger(floor(randomnumbergenerator() * 0x10000) * 0x10000 +
                                floor(randomnumbergenerator() * 0x10000))
   end
   
   excessbytes = 32 * numberofwords - bitlength
   mag[1] = bitand(mag[1], 2 ^ (32 - excessbytes) - 1)
   
   destructivestripleadingzeros(mag)
   
   return createbiginteger(1, mag)
end

--local
function constructormagnitude(val)
   local sign, mag
   local ok, reason
   
   ok, reason = isvalidbytearray(val)
   if not ok then
      error(reason, 3)
   end
   
   sign, mag = getbytearraysignandmagnitude(val)
   
   if #mag >= maxmagnitudelength then
      error("biginteger would overflow supported range", 3)
   end
   
   return createbiginteger(sign, mag)
end

--local
function constructorstringradix(str, radix)
   local mag
   local strlength = #str
   local sign, cursor, strsign, numberofdigits, digitsperintegerradix
   local numberofbits, numberofwords
   local firstgrouplength, superradix, group, groupvalue
   local ok, reason
   
   -- Some edits and changes occurred here
   ok, reason = isvalidradix(radix)
   if not ok then
      error(reason, 3)
   end
   
   ok, reason = isvalidstringnumber(str)
   if not ok then
      error(reason, 3)
   end
   
   strsign = stringmatch(str, '[-+]')
   
   sign = strsign == '-' and -1 or 1
   cursor = strsign and 2 or 1
   
   for i = cursor, strlength do
      if getcharvalue(stringsub(str, i, i)) >= radix then
         -- if a character is not a proper digit, getcharvalue will return 36,
         -- which will always be >= radix
         error("illegal digit", 3)
      end
   end
   
   if stringmatch(str, '^[-+]?0+$') then
      return createbiginteger({}, 0)
   end
   
   while cursor <= strlength and stringsub(str, cursor, cursor) == '0' do
      cursor = cursor + 1
   end
   -- Back to Java-faithful code
   numberofdigits = strlength - cursor + 1
   
   numberofbits = bitrightshift(numberofdigits * bitsperdigit[radix], 10) + 1
   
   if numberofbits + 31 > 0xffffffff then
      error("biginteger would overflow supported range", 3)
   end
   
   numberofwords = bitrightshift(numberofbits + 31, 5)
   mag = {}
   for i = 1, numberofwords do
      mag[i] = 0
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
      -- precautionary test, even though it shouldn't be needed. perhaps I'll
      -- remove this later since the check for illegal characters was done already
      error("illegal digit", 3)
   end
   mag[numberofwords] = groupvalue
   
   -- Process remaining groups
   superradix = intradix[radix]
   while cursor <= strlength do
      group = stringsub(str, cursor, cursor + digitsperintegerradix - 1)
      cursor = cursor + digitsperintegerradix
      groupvalue = tonumber(group, radix)
      if not groupvalue then
         error("illegal digit", 3)
      end
      destructivemultiplyandadd(mag, superradix, groupvalue)
   end
   
   destructivestripleadingzeros(mag)
   if #mag >= maxmagnitudelength then
      error("biginteger would overflow supported range", 3)
   end
   
   return createbiginteger(sign, mag)
end

--local
function clone(bigint)
   return constructorsignmangitude(bigint.sign, bigint.magnitude)
end

-- Main Constructor
-- will interpret passed arguments to call appropriate constructor
--local
function biginteger(a, b)
   local typea = gettype(a)
   local typeb = gettype(b)
   
   if typea == "integer" then
      if typeb == "nil" then
         return constructorinteger(a)
      elseif typeb == "byte-array" then
         return constructorsignmagnitude(a, b)
      elseif typeb == "function" then
         return constructorbitsrng(a, b)
      end
   elseif typea == "byte-array" and typeb == "nil" then
      return constructormagnitude(a)
   elseif typea == "string" then
      if typeb == "nil" then
         return constructorstringradix(a, 10)
      elseif typeb == "integer" then
         return constructorstringradix(a, b)
      end
   end
   
   error("could not understand passed parameters: " ..
      typea .. " and " .. typeb, 2)
end


-- Comparison Functions
--[[local function equals(thisbigint, thatbigint)
   local thismag, thatmag
   
   if rawequal(thisbigint, thatbigint) then
      return true
   end
   
   if not isvalidbiginteger(thatbigint) then
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
--]]

--local
function comparemagnitudes(thismag, thatmag)
   local thislen = #thismag
   local thatlen = #thatmag
   if thislen ~= thatlen then
      -- If the magnitudes are different sizes, then they cannot be equal
      return thislen > thatlen and 1 or -1
   end
   
   for i = 1, thislen do
      if thismag[i] ~= thatmag[i] then
         return thismag[i] > thatmag[i] and 1 or -1
      end
   end
   
   return 0
end

--local
function compare(thisbigint, thatbigint)
   local thismag, thatmag
   local thissign, thatsign
   
   if rawequal(thisbigint, thatbigint) then
      return 0
   end
   
   if not isvalidoperablenumber(thisbigint) or not isvalidoperablenumber(thatbigint) then
      error("attempt to perform comparison on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   thissign, thismag = getsignandmagnitude(thisbigint)
   thatsign, thatmag = getsignandmagnitude(thatbigint)
   
   if thissign ~= thatsign then
      -- If the signs differ, then they cannot be equal
      return thissign > thatsign and 1 or -1
   end
   
   return comparemagnitudes(thismag, thatmag)
end

--local
function equals(thisbigint, thatbigint)
   if not isvalidoperablenumber(thisbigint) or not isvalidoperablenumber(thatbigint) then
      error("attempt to perform equals on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   return compare(thisbigint, thatbigint) == 0
end


-- Bitwise functions
--local
function bitwisenot(bigint)
   local ok, reason = isvalidoperablenumber(bigint)
   if not ok then
      error(reason, 2)
   end
   
   return constructormagnitude(mapmagnitude(bigint, bitnot))
end

--local
function bitwiseand(thisbigint, thatbigint)
   if not isvalidoperablenumber(thisbigint) or not isvalidoperablenumber(thatbigint) then
      error("attempt to perform equals on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   return constructormagnitude(mergemagnitudes(thisbigint, thatbigint, bitand))
end

--local
function bitwiseandnot(thisbigint, thatbigint)
   if not isvalidoperablenumber(thisbigint) or not isvalidoperablenumber(thatbigint) then
      error("attempt to perform equals on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   return constructormagnitude(mergemagnitudes(thisbigint, thatbigint, bitandnot))
end

--local
function bitwiseor(thisbigint, thatbigint)
   if not isvalidoperablenumber(thisbigint) or not isvalidoperablenumber(thatbigint) then
      error("attempt to perform equals on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   return constructormagnitude(mergemagnitudes(thisbigint, thatbigint, bitor))
end

--local
function bitwisexor(thisbigint, thatbigint)
   if not isvalidoperablenumber(thisbigint) or not isvalidoperablenumber(thatbigint) then
      error("attempt to perform equals on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   return constructormagnitude(mergemagnitudes(thisbigint, thatbigint, bitxor))
end


-- Private Magnitude Functions
--local
function addmagnitudes(thismag, thatmag)
   local mag
   local longermag, shortermag
   local longerlen, shorterlen
   local carry
   
   longermag = thismag
   shortermag = thatmag
   
   longerlen = #longermag
   shorterlen = #shortermag
   
   if longerlen < shorterlen then
      longermag, shortermag = shortermag, longermag
      longerlen, shorterlen = shorterlen, longerlen
   end
   
   mag = {}
   carry = 0
   
   for i = 0, longerlen - 1 do
      carry, mag[longerlen - i] = splitlong(getintfromend(longermag, i) +
                                            getintfromend(shortermag, i) +
                                            carry)
   end
   
   if carry ~= 0 then
      -- If the carry amount exceeds the size of both magnitudes, then insert
      -- the value of the carry in front of everything.
      table.insert(mag, 1, carry)
   end
   
   return mag
end

--local
function subtractmagnitudes(minuend, subtrahend)
   local mag
   local borrow, difference
   local longerlen
   
   mag = {}
   borrow = 0
   difference = 0
   longerlen = #minuend
   
   for i = 0, longerlen - 1 do
      difference = getintfromend(minuend, i) -
                   getintfromend(subtrahend, i) -
                   borrow
      
      if difference < 0 then
         borrow = 1
         --difference = -difference
      else
         borrow = 0
      end
      mag[longerlen - i] = make32bitinteger(difference)
   end
   
   return destructivestripleadingzeros(mag)
end

-- Public Math Functions
--local
function negate(bigint)
   local ok, reason = isvalidbiginteger(bigint)
   if not ok then
      error(reason, 2)
   end
   return constructorsignmagnitude(-bigint.sign, bigint.magnitude)
end

--local
function absolutevalue(bigint)
   local ok, reason = isvalidbiginteger(bigint)
   if not ok then
      error(reason, 2)
   end
   return bigint.sign < 0 and negate(bigint) or bigint
end

--local
function add(thisbigint, thatbigint)
   local sign, mag
   local thissign, thatsign
   local thismag, thatmag
   local comparison
   
   if not isvalidoperablenumber(thisbigint) or not isvalidoperablenumber(thatbigint) then
      error("attempt to perform addition on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   thissign, thismag = getsignandmagnitude(thisbigint)
   thatsign, thatmag = getsignandmagnitude(thatbigint)
   
   if thissign == 0 then
      return thatbigint
   elseif thatsign == 0 then
      return thisbigint
   end
   
   if thissign == thatsign then
      sign = thissign
      mag = addmagnitudes(thismag, thatmag)
   else
      comparison = comparemagnitudes(thismag, thatmag)
      if comparison > 0 then
         sign = thissign
         mag = subtractmagnitudes(thismag, thatmag)
      elseif comparison < 0 then
         sign = thatsign
         mag = subtractmagnitudes(thatmag, thismag)
      else
         sign = 0
         mag = {}
      end
   end
   
   return constructorsignmagnitude(sign, mag)
end

--local
function subtract(thisbigint, thatbigint)
   local sign, mag
   local thissign, thatsign
   local thismag, thatmag
   local comparison
   
   if not isvalidoperablenumber(thisbigint) or not isvalidoperablenumber(thatbigint) then
      error("attempt to perform addition on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   thissign, thismag = getsignandmagnitude(thisbigint)
   thatsign, thatmag = getsignandmagnitude(thatbigint)
   
   if thissign == 0 then
      return negate(thatbigint)
   elseif thatsign == 0 then
      return thisbigint
   end
   
   if thissign ~= thatsign then
      sign = thissign
      mag = addmagnitudes(thismag, thatmag)
   else
      comparison = comparemagnitudes(thismag, thatmag)
      if comparison > 0 then
         sign = thissign
         mag = subtractmagnitudes(thismag, thatmag)
      elseif comparison < 0 then
         sign = thatsign
         mag = subtractmagnitudes(thatmag, thismag)
      else
         sign = 0
         mag = {}
      end
   end
   
   return constructorsignmagnitude(sign, mag)
end

-- temporary functions to print the number in hexadecimal or binary
--local
function getintegerstringhexadecimal(number)
   local str, index = {}, 1
   
   for i = 28, 0, -4 do
      str[index], index = characters[bitand(bitrightshift(number, i), 0xf)], index + 1
   end
   
   return table.concat(str)
end

--local
function getintegerstringbinary(number)
   local str, index = {}, 1
   
   for i = 31, 0, -1 do
      str[index], index = characters[bitand(bitrightshift(number, i), 0x1)], index + 1
   end
   
   return table.concat(str)
end

--local
function stringofbigintmagnitude(bigint, dobinary)
   local mag, maglen, str
   local ok, reason = isvalidoperablenumber(bigint)
   if not ok then
      error("number is not operable", 2)
   end
   
   mag = getmagnitude(bigint)
   maglen = #mag
   
   if dobinary then
      if maglen == 0 then
         return string.rep('0', 32)
      end
      
      str = getintegerstringbinary(getintfromendwithsign(bigint, 0))
   
      for i = 1, maglen - 1 do
         str = getintegerstringbinary(getintfromendwithsign(bigint, i)) .. '_' .. str
      end
   else
      if maglen == 0 then
         return string.rep('0', 8)
      end
      
      str = getintegerstringhexadecimal(getintfromendwithsign(bigint, 0))
   
      for i = 1, maglen - 1 do
         str = getintegerstringhexadecimal(getintfromendwithsign(bigint, i)) .. '_' .. str
      end
   end
   
   return str
end


-- Computercraft `os.loadAPI` compatibility
if _CC_VERSION then
   if tonumber(_CC_VERSION) < 1.75 then
      error("Knox's BigInteger library compatibility for ComputerCraft requires CC " ..
         "version 1.75 or later")
   end
   _ENV.biginteger = biginteger
   return
end

return bi--{biginteger = biginteger}
