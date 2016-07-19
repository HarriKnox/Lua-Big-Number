local bi = {} -- Sandbox for testing purposes. That's why all the 'local's are commented out.
setmetatable(bi, {__index = _G})
_ENV = bi

--[[
Since I would inevitably need to write this, I'll just write it now to get it
taken care of right away. Here are some definitions:
   1) valid 32 bit integer: a value of type 'number' that is non-negative, less
      than 2 ^ 32, and an integer (no decimal)
   2) byte-array: a table of numbers that follow these rules
      a) all numbers are valid 32 bit integers
      b) the array is one-indexed (indices start at 1 not 0)
      c) a zero-length array is logically equivalent to 0 (zero)
      d) if the first element is negative (in two's-compliment form) then the
         byte-array is considered negative (leading zeros will prevent the first
         non-zero element from being interpreted as negative)
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


-- Testing functions
--local
function isvalidinteger(int)
   return type(int) == 'number' and
          int <= maxinteger and
          int >= -maxinteger and
          int % 1 == 0
end

--local
function is32bitinteger(int)
   return type(int) == 'number' and
          int <= 0xffffffff and
          int >= 0 and
          int % 1 == 0
   end

--local
function isvalidbytearray(val)
   if type(val) ~= 'table' then
      return false
   end
   for i = 1, #val do
      if not is32bitinteger(val[i]) then
         return false
      end
   end
   return true
end

--local
function isvalidmagnitude(mag)
   if not isvalidbytearray(mag) then
      return false
   end
   if #mag == 0 then
      return true
   end
   if mag[1] == 0 then
      return false
   end
   return true
end

--local
function isvalidsign(sign)
   return type(sign) == 'number' and
          sign == -1 or
          sign == 0 or
          sign == 1
end

--local
function isvalidsignmagnitudecombination(sign, mag)
   if sign == 0 then
      -- logically equal to 0 (zero)
      return #mag == 0
   end
   -- logically cannot equal 0 (zero)
   return #mag ~= 0
end

--local
function isbiginteger(bigint)
   return type(bigint) == 'table' and
          isvalidsign(bigint.sign) and
          isvalidmagnitude(bigint.magnitude) and
          isvalidsignmagnitudecombination(bigint.sign, bigint.magnitude)
end

--local
function isoperablenumber(thing)
   return isbiginteger(thing) or
          isvalidinteger(thing) or
          isvalidbytearray(thing)
end

--local
function gettype(thing)
   return (isbiginteger(thing) and 'biginteger') or
          (isvalidbytearray(thing) and 'byte-array') or
          (isvalidinteger(thing) and 'integer') or
          type(thing)
end

--local
function isvalidradix(radix)
   return isvalidinteger(radix) and
          radix >= 2 and
          radix <= 36 and
          radix % 1 == 0
end

--local
function isvalidstringnumber(str)
   return not not stringmatch(str, '^[%-+]?[0-9A-Za-z]+$')
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
function copyofrange(val, start, fin)
   local copy = {}
   local vallength = #val
   
   if start < 0 then
      -- adjust for negative index (index from end of val)
      start = vallength + start + 1
   end
   if fin < 0 then
      fin = vallength + fin + 1
   end
   
   for index = start, fin do
      copy[index - start + 1] = val[index]
   end
   
   return copy
end

--local
function stripleadingzeros(val)
   local vallength = #val
   local keep = 1
   
   while keep <= vallength and val[keep] == 0 do
      keep = keep + 1
   end
   
   return copyofrange(val, keep, vallength)
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
end

--local
function negatebytearray(bytearray)
   local mag = {}
   local balen = #bytearray
   
   for i = 1, balen do
      mag[i] = bitnot(bytearray[i])
   end
   
   destructiveaddonetobytearray(mag)
   return stripleadingzeros(mag)
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
end


-- Private Getter functions
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
   return stripleadingzeros(thing)
end

--local
function getbytearraysignandmagnitude(thing)
   local sign = getbytearraysign(thing)
   if sign == -1 then
      return sign, negatebytearray(thing)
   end
   return sign, stripleadingzeros(thing)
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
   if isbiginteger(thing) then
      return thing.sign
      
   elseif isvalidbytearray(thing) then
      return getbytearraysign(thing)
      
   elseif isvalidinteger(thing) then
      return getnumbersign(thing)
   end
   error("Cannot obtain sign")
end

--local
function getmagnitude(thing)
   if isbiginteger(thing) then
      return thing.magnitude
      
   elseif isvalidbytearray(thing) then
      return getbytearraymagnitude(thing)
      
   elseif isvalidinteger(thing) then
      return getnumbermagnitude(thing)
   end
   error("Cannot obtain magnitude")
end

--local
function getsignandmagnitude(thing)
   if isbiginteger(thing) then
      return thing.sign, thing.magnitude
      
   elseif isvalidbytearray(thing) then
      return getbytearraysignandmagnitude(thing)
      
   elseif isvalidinteger(thing) then
      return getnumbersignandmagnitude(thing)
   end
   error("Cannot obtain sign and magnitude")
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
   local magint, signint, bimag, bilen
   
   bimag = getmagnitude(bigint)
   bilen = #bimag
   signint = getsign(bigint) == -1 and -1 or 0
   
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
end


-- Constructors
--local
function createbiginteger(sign, mag)
   if not isvalidsign(sign) then
      error("Sign not in {-1, 0, 1}", 4)
   elseif not isvalidmagnitude(mag) then
      error("Magnitude not valid", 4)
   elseif not isvalidsignmagnitudecombination(sign, mag) then
      error("Sign-magnitude mismatch", 4)
   end
   return {sign = sign, magnitude = mag}
end

--local
function constructornumber(num)
   if not isvalidinteger(num) then
      error("Number not a valid integer", 3)
   end
   
   return createbiginteger(getnumbersignandmagnitude(num))
end

--local
function constructorsignmagnitude(sign, val)
   local mag
   if not isvalidsign(sign) then
      error("Invalid sign value: " .. sign, 3)
   end
   
   if not isvalidbytearray(val) then
      error("Invalid byte array", 3)
   end
   
   mag = stripleadingzeros(val)
   
   if not isvalidsignmagnitudecombination(sign, mag) then
      error("Sign-magnitude mismatch", 3)
   end
   
   if #mag >= maxmagnitudelength then
      error("BigInteger would overflow supported range", 3)
   end
   
   return createbiginteger(sign, mag)
end

--local
function constructorbitsrng(bitlength, randomnumbergenerator)
   local tempmagnitude = {}
   local numberofwords, excessbytes
   
   if bitlength < 0 or bitlength % 1 ~= 0 then
      error("Bit length must be a non-negative integer", 3)
   end
   
   if type(randomnumbergenerator()) ~= "number" then
      error("RNG function must return a number in the range [0, 1)", 3)
   end
   
   numberofwords = floor((bitlength + 31) / 32)
   for i = 1, numberofwords do
      -- This weird multiplication-addition is necessary since the default
      -- math.random would not operate on all 32 bits
      tempmagnitude[i] = make32bitinteger(floor(randomnumbergenerator() * 0x10000) * 0x10000 +
                                          floor(randomnumbergenerator() * 0x10000))
   end
   
   excessbytes = 32 * numberofwords - bitlength
   tempmagnitude[1] = bitand(tempmagnitude[1], 2 ^ (32 - excessbytes) - 1)
   
   return createbiginteger(1, stripleadingzeros(tempmagnitude))
end

--local
function constructormagnitude(val)
   local sign, mag
   if #val == 0 then
      error("Zero length BigInteger", 3)
   end
   if not isvalidbytearray(val) then
      error("Invalid byte array", 3)
   end
   
   sign, mag = getbytearraysignandmagnitude(val)
   
   if #mag >= maxmagnitudelength then
      error("BigInteger would overflow supported range", 3)
   end
   
   return createbiginteger(sign, mag)
end

--local
function constructorstringradix(str, radix)
   local mag
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
--[[local function equals(thisbigint, thatbigint)
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
   
   if not isoperablenumber(thisbigint) or not isoperablenumber(thatbigint) then
      error("Attempt to perform comparison on "
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
   if not isoperablenumber(thisbigint) or not isoperablenumber(thatbigint) then
      error("Attempt to perform equals on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   return compare(thisbigint, thatbigint) == 0
end


-- Bitwise functions
--local
function bitwisenot(bigint)
   if not isoperablenumber(bigint) then
      error("Number is not operable", 2)
   end
   
   return constructormagnitude(mapmagnitude(bigint, bitnot))
end

--local
function bitwiseand(thisbigint, thatbigint)
   if not isoperablenumber(thisbigint) or not isoperablenumber(thatbigint) then
      error("Attempt to perform equals on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   return constructormagnitude(mergemagnitudes(thisbigint,
                                               thatbigint,
                                               bitand))
end

--local
function bitwiseandnot(thisbigint, thatbigint)
   if not isoperablenumber(thisbigint) or not isoperablenumber(thatbigint) then
      error("Attempt to perform equals on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   return constructormagnitude(mergemagnitudes(thisbigint,
                                               thatbigint,
                                               bitandnot))
end

--local
function bitwiseor(thisbigint, thatbigint)
   if not isoperablenumber(thisbigint) or not isoperablenumber(thatbigint) then
      error("Attempt to perform equals on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   return constructormagnitude(mergemagnitudes(thisbigint,
                                               thatbigint,
                                               bitor))
end

--local
function bitwisexor(thisbigint, thatbigint)
   if not isoperablenumber(thisbigint) or not isoperablenumber(thatbigint) then
      error("Attempt to perform equals on "
         .. gettype(thisbigint) .. " and " .. gettype(thatbigint), 2)
   end
   
   return constructormagnitude(mergemagnitudes(thisbigint,
                                               thatbigint,
                                               bitxor))
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
   
   return stripleadingzeros(mag)
end

-- Public Math Functions
--local
function negate(bigint)
   if not isbiginteger(bigint) then
      error("Number is not biginteger", 2)
   end
   return constructorsignmagnitude(-bigint.sign, bigint.magnitude)
end

--local
function absolutevalue(bigint)
   if not isbiginteger(bigint) then
      error("Number is not biginteger", 2)
   end
   return bigint.sign < 0 and negate(bigint) or bigint
end

--local
function add(thisbigint, thatbigint)
   local sign, mag
   local thissign, thatsign
   local thismag, thatmag
   local comparison
   
   if not isoperablenumber(thisbigint) or not isoperablenumber(thatbigint) then
      error("Attempt to perform addition on "
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
      comparison = comparemagnitudes(thisbigint, thatbigint)
      if comparison > 0 then
         sign = 1
         mag = subtractmagnitudes(thismag, thatmag)
      elseif comparison < 0 then
         sign = -1
         mag = subtractmagnitudes(thatmag, thismag)
      else
         sign = 0
         mag = {}
      end
   end
   
   return constructorsignmagnitude(sign, mag)
end


-- Computercraft `os.loadAPI` compatibility
if _CC_VERSION then
   if tonumber(_CC_VERSION) < 1.75 then
      error("BigInteger library compatibility for ComputerCraft requires CC " ..
         "version 1.75 or later")
   end
   _ENV.biginteger = biginteger
   return
end

return bi--{biginteger = biginteger}
