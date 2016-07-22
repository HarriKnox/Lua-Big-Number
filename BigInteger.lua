local bi = {} -- Sandbox for testing purposes. That's why all the 'local's are commented out.
setmetatable(bi, {__index = _G})
_ENV = bi

--[[
Since I would inevitably need to write this, I'll just write it now to get it
taken care of right away. Here are some definitions:
   *  valid 32-bit integer: a value of type 'number' that is non-negative, less
      than 2 ^ 32, and an integer (no decimal)
      
   *  byte: a 32-bit integer used in an array and has a sign (in two's
      compliment form). Most languages define bytes as being 8-bit integers, not
      32-bits. However, since 'byte' is the name of the elements in a byte-array
      in the Java implementation, the name of the elements of the number-arrays
      in this library is 'byte'.
      
   *  byte-array: a sequence (table) of numbers that follows these rules
      a) all numbers are valid 32 bit integers
      b) the array is one-indexed (indices start at 1 not 0)
      c) a zero-length array is logically equivalent to 0 (zero)
      d) if the first element is negative (in two's-compliment form) then the
         byte-array will be considered negative (leading zeros will prevent the
         first non-zero element from being interpreted as negative). Likewise,
         if the first element is not negative the byte-array will not be
         considered negative (leading sign bits [0xffffffff] will prevent the
         byte-array from being interpreted as negative)
         
      e) Note: For testing and iterating through byte-arrays the default length
         operator (#) is used. This means that the byte-array must have a
         sequence of numbers for all indices between 1 and #array (that is to
         say for all 1 <= i <= #array, t[i] ~= nil). If #array == 0 then the
         byte-array is still valid: it has a zero-length sequence.
         
      f) Note: Since a byte-array is a table, it may have keys and values that
         are not in the sequence (such as t.name = 'Bob'). It is possible for
         someone to pass in any table/prototype/object and it will be
         interpreted as a byte-array. Because of this, the only tables that will
         fail the byte-array test are those that pass the biginteger test: this
         is so tables can be interpreted as bigintegers where they could have
         been interpreted as bytearrays
      
   *  magnitude: inherently unsigned; a type of byte-array with exceptions:
      a) all numbers are treated as unsigned (ignores negatives in
         two's-compliment form)
      b) leading zeros are not allowed, and thus a magnitude of only zeros is
         not allowed
      
   *  sign: Either -1, 0, or 1; determines whether the value is negative, zero,
      or positive, respectively. A sign of 0 cannot be assigned to a value that
      is not logically equivalent to 0 (zero)
      
   *  biginteger: a table with (at minimum) two values (sign and magnitude) such
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
maxinteger = 0x7ffffffffffff -- 2 ^ 51 - 1; largest number bit32 can work with reliably
--local
maxmagnitudelength = 0x4000000 -- Integer.MAX_VALUE / Integer.SIZE  + 1 = 1 << 26
--local
negativemask = 0x80000000

--local
stringsub = string.sub
--local
stringmatch = string.match
--local
tableinsert = table.insert

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
   elseif int > 0xffffffff then
      return false, "number is outside 32 bits"
   elseif int < 0 then
      return false, "number is negative"
   elseif int % 1 ~= 0 then
      return false, "number is not an integer"
   end
   
   return true
end

--local
function isvalidbytearray(array)
   local ok, reason
   if type(array) ~= 'table' then
      return false, "value is not an array"
   end
   
   if isvalidbiginteger(array) then
      return false, "value is a biginteger, not a byte-array"
   end
   
   for i = 1, #array do
      ok, reason = isvalid32bitinteger(array[i])
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
function isvalidoperablevalue(value)
   if isvalidinteger(value) or isvalidbytearray(value) or isvalidbiginteger(value) then
      return true
   end
   
   return false, "value is not an operable number but type " .. type(value)
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
function copyarrayto(source, destination)
   if source ~= destination then
      for i = 1, #source do
         destination[i] = source[i]
      end
   end
   
   return destination
end

--local
function copyarray(array)
   return copyarrayto(array, {})
end

--local
function destructivecleararray(array)
   for i = 1, #array do
      array[i] = nil
   end
   
   return array
end



--local
function signextendbytearrayto(source, destination, newlength)
   local length = #source
   local signbytes = newlength - length
   local signint = length > 0 and source[1] >= negativemask and 0xffffffff or 0
   
   if signbytes <= 0 then
      if source ~= destination then
         -- if no sign bytes are being added and the source and destination are
         -- different, then copy the values from source to destination and
         -- return. If the source and destination are the same table, then do
         -- nothing and return.
         for i = 1, length do
            destination[i] = source[i]
         end
      end
      return destination
   end
   
   for i = newlength, signbytes + 1, -1 do
      destination[i] = source[i - signbytes]
   end
   
   for i = 1, signbytes do
      destination[i] = signint
   end
   
   return destination
end

--local
function copyandsignextendbytearray(array, newlength)
   return signextendbytearrayto(array, {}, newlength)
end

--local
function destructivesignextendbytearray(array, newlength)
   return signextendbytearrayto(array, array, newlength)
end


--local
function stripleadingzerosto(source, destination)
   local length = #source
   local difference = length
   local endpoint
   
   for i = 1, length do
      if source[i] ~= 0 then
         difference = i - 1
         break
      end
   end
   
   if difference == 0 then
      if source ~= destination then
         -- if no zeros are being stripped and the source and destination are
         -- different, then copy the values from source to destination and
         -- return. If the source and destination are the same table, then do
         -- nothing and return.
         for i = 1, length do
            destination[i] = source[i]
         end
      end
      return destination
   end
   
   endpoint = length - difference
   
   for i = 1, endpoint do
      destination[i] = source[i + difference]
   end
   
   if destination == source then
      for i = endpoint + 1, length do
         destination[i] = nil
      end
   end
   
   return destination
end

--local
function copyandstripleadingzeros(array)
   return stripleadingzerosto(array, {})
end

--local
function destructivestripleadingzeros(array)
   return stripleadingzerosto(array, array)
end


--local
function negatebytearrayto(source, destination)
   local length = #source
   local addend = 1
   
   for i = length, 1, -1 do
      addend, destination[i] = splitlong(bitnot(source[i]) + addend)
   end
   
   return destructivestripleadingzeros(destination)
end

--local
function copyandnegatebytearray(array)
   return negatebytearrayto(array, {})
end

--local
function destructivenegatebytearray(array)
   return negatebytearrayto(array, array)
end


--local
function destructivemultiplyandadd(mag, factor, addend)
   local maglength = #mag
   local product = 0
   local carry = 0
   local index = maglength
   
   for i = maglength, 1, -1 do
      carry, mag[i] = integermultiplyandaddtolong(factor, mag[i], carry)
   end
   
   carry = addend
   
   for i = maglength, 1, -1 do
      carry, mag[i] = splitlong(mag[i] + carry)
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
function getcharacternumericalvalue(character)
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


--local
function getbytearraysign(array)
   if #array == 0 then
      return 0
   end
   if array[1] >= negativemask then
      return -1
   end
   for i = 1, #array do
      if array[i] ~= 0 then
         return 1
      end
   end
   return 0
end

--local
function getbytearraymagnitude(array)
   if getbytearraysign(array) == -1 then
      return copyandnegatebytearray(array)
   end
   return copyandstripleadingzeros(array)
end

--local
function getbytearraysignandmagnitude(array)
   local sign = getbytearraysign(array)
   if sign == -1 then
      return sign, copyandnegatebytearray(array)
   end
   return sign, copyandstripleadingzeros(array)
end


--local
function getnumbersign(int)
   return (int < 0 and -1) or (int > 0 and 1) or 0
end

--local
function getnumbermagnitude(int)
   return splitlongandstripleadingzeros(int < 0 and -int or int)
end

--local
function getnumbersignandmagnitude(int)
   return getnumbersign(int), getnumbermagnitude(int)
end


--local
function getsign(value)
   if isvalidbiginteger(value) then
      return value.sign
      
   elseif isvalidbytearray(value) then
      return getbytearraysign(value)
      
   elseif isvalidinteger(value) then
      return getnumbersign(value)
   end
   error("cannot obtain sign")
end

--local
function getmagnitude(value)
   if isvalidbiginteger(value) then
      return copyarray(value.magnitude)
      
   elseif isvalidbytearray(value) then
      return getbytearraymagnitude(value)
      
   elseif isvalidinteger(value) then
      return getnumbermagnitude(value)
   end
   error("cannot obtain magnitude")
end

--local
function getsignandmagnitude(value)
   if isvalidbiginteger(value) then
      return value.sign, copyarray(value.magnitude)
      
   elseif isvalidbytearray(value) then
      return getbytearraysignandmagnitude(value)
      
   elseif isvalidinteger(value) then
      return getnumbersignandmagnitude(value)
   end
   error("cannot obtain sign and magnitude")
end


--local
function getbytearray(array)
   local sign, mag
   
   if isvalidbytearray(array) then
      return copyarray(array)
   end
   
   sign, mag = getsignandmagnitude(array)
   
   if sign == -1 then
      destructivenegatebytearray(mag)
      
      if mag[1] < negativemask then
         tableinsert(mag, 1, 0xffffffff)
      end
   elseif sign == 1 then
      if mag[1] >= negativemask then
         tableinsert(mag, 1, 0)
      end
   end
   
   return mag
end

--local
function getminimizedbytearray(array)
   local bytearray, balen
   local sign, signint
   local removals, endpoint
   
   sign = getsign(array)
   
   if sign == 0 then
      return {}
   end
   
   bytearray = getbytearray(array)
   balen = #bytearray
   
   removals = balen - 1
   signint = bytearray[1] >= negativemask and 0xffffffff or 0
   
   if bytearray[1] == signint then
      for i = 1, balen - 1 do
         if bytearray[i] == signint and bytearray[i + 1] ~= signint then
            if signint == 0 then
               if bytearray[i + 1] >= negativemask then
                  removals = i - 1
               else
                  removals = i
               end
            else
               if bytearray[i + 1] >= negativemask then
                  removals = i
               else
                  removals = i - 1
               end
            end
            break
         end
      end
   else
      removals = 0
   end
   
   endpoint = balen - removals
   
   for i = 1, endpoint do
      bytearray[i] = bytearray[i + removals]
   end
   
   for i = endpoint + 1, balen do
      bytearray[i] = nil
   end
   
   return bytearray
end

--local
function getbytefromend(array, displacement)
   local arraylength = #array
   
   if displacement < 0 or displacement >= arraylength then
      return 0
   end
   return array[arraylength - displacement]
end


--local
function convertsignmagnitudetobytearrayto(sign, source, destination)
   if sign == -1 then
      negatebytearrayto(source, destination)
      if getbytearraysign(destination) == 1 then
         tableinsert(destination, 1, 0xffffffff)
      end
   else
      copyarrayto(source, destination)
      if getbytearraysign(destination) == -1 then
         tableinsert(destination, 1, 0)
      end
   end
   
   return destination
end

--local
function copyandconvertsignmagnitudetobytearray(sign, mag)
   return convertsignmagnitudetobytearrayto(sign, mag, {})
end

--local
function destructiveconvertsignmagnitudetobytearray(sign, mag)
   return convertsignmagnitudetobytearrayto(sign, mag, mag)
end


--local
function convertbytearraytosignmagnitudeto(source, destination)
   local sign = getbytearraysign(source)
   if sign == 0 then
      return 0, destructivecleararray(destination)
   end
   
   if sign == -1 then
      negatebytearrayto(source, destination)
      return -1, destination
   end
   
   return 1, destructivestripleadingzeros(destination)
end

--local
function copyandconvertbytearraytosignmagnitude(bytearray)
   return convertbytearraytosignmagnitudeto(bytearray, {})
end

--local
function destructiveconvertbytearraytosignmagnitude(bytearray)
   return convertbytearraytosignmagnitudeto(bytearray, bytearray)
end


-- Byte-Array Mappers
--local
function destructivemapbytearray(bytearray, mapfunction)
   for i = 1, #bytearray do
      bytearray[i] = mapfunction(bytearray[i])
   end
   
   return bytearray
end

--local
function destructivemergebytearrays(thisbytearray, thatbytearray, mergefunction)
   local longerlength
   
   longerlength = max(#thisbytearray, #thatbytearray)
   
   destructivesignextendbytearray(thisbytearray, longerlength)
   destructivesignextendbytearray(thatbytearray, longerlength)
   
   for i = 0, longerlength - 1 do
      thisbytearray[longerlen - i] = mergefunction(getbytefromend(thisbytearray, i),
                                                   getbytefromend(thatbytearray, i))
   end
   
   return thisbytearray
end


-- Constructors
--local
function createbiginteger(sign, mag)
   return {sign = sign, magnitude = mag}
end

--local
function constructorinteger(int)
   local ok, reason = isvalidinteger(int)
   if not ok then
      error(reason, 3)
   end
   
   return createbiginteger(getnumbersignandmagnitude(int))
end

--local
function constructorsignmagnitudetrusted(sign, mag)
   local ok, reason
   
   ok, reason = isvalidsign(sign)
   if not ok then
      error(reason, 3)
   end
   
   ok, reason = isvalidmagnitude(mag)
   if not ok then
      error(reason, 3)
   end
   
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
function constructorsignmagnitude(sign, mag)
   local magnitude
   local ok, reason
   
   ok, reason = isvalidbytearray(mag)
   if not ok then
      error(reason, 3)
   end
   
   return constructorsignmagnitudetrusted(sign, copyandstripleadingzeros(mag))
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
function constructorbytearraytrusted(array)
   local sign, mag
   local ok, reason
   
   ok, reason = isvalidbytearray(array)
   if not ok then
      error(reason, 3)
   end
   
   sign = getbytearraysign(array)
   
   if sign == -1 then
      destructivenegatebytearray(array)
   end
   
   if #array >= maxmagnitudelength then
      error("biginteger would overflow supported range", 3)
   end
   
   return createbiginteger(sign, array)
end

--local
function constructorbytearray(array)
   return constructorbytearraytrusted(getbytearray(array))
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
      if getcharacternumericalvalue(stringsub(str, i, i)) >= radix then
         -- if a character is not a proper digit, getcharacternumericalvalue will return 36,
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
   local ok, reason = isvalidbiginteger(bigint)
   if not ok then
      error(reason, 2)
   end
   
   return constructorsignmangitude(bigint.sign, bigint.magnitude)
end

-- Main Constructor
-- will interpret passed arguments to call appropriate constructor
--local
function biginteger(a, b)
   local typea = gettype(a)
   local typeb = gettype(b)
   
   if typea == 'integer' then
      if typeb == 'nil' then
         return constructorinteger(a)
      elseif typeb == 'byte-array' then
         return constructorsignmagnitude(a, b)
      elseif typeb == 'function'then
         return constructorbitsrng(a, b)
      end
   elseif typea == 'biginteger' then
      return clone(a)
   elseif typea == 'byte-array' and typeb == 'nil' then
      return constructorbytearray(a)
   elseif typea == 'string' then
      if typeb == 'nil' then
         return constructorstringradix(a, 10)
      elseif typeb == 'integer' then
         return constructorstringradix(a, b)
      end
   end
   
   error("could not understand passed parameters: " ..
      typea .. " and " .. typeb, 2)
end


-- Comparison Functions
--local
function comparemagnitudes(thismag, thatmag)
   local thislength = #thismag
   local thatlength = #thatmag
   if thislength ~= thatlength then
      -- If the magnitudes are different sizes, then they cannot be equal
      return thislength > thatlength and 1 or -1
   end
   
   for i = 1, thislength do
      if thismag[i] ~= thatmag[i] then
         return thismag[i] > thatmag[i] and 1 or -1
      end
   end
   
   return 0
end

--local
function compare(thisvalue, thatvalue)
   local thissign, thismag
   local thatsign, thatmag
   
   if rawequal(thisvalue, thatvalue) then
      return 0
   end
   
   if not isvalidoperablevalue(thisvalue) or not isvalidoperablevalue(thatvalue) then
      error("attempt to perform comparison on "
         .. gettype(thisvalue) .. " and " .. gettype(thatvalue), 2)
   end
   
   thissign, thismag = getsignandmagnitude(thisvalue)
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thissign ~= thatsign then
      -- If the signs differ, then they cannot be equal
      return thissign > thatsign and 1 or -1
   end
   
   return comparemagnitudes(thismag, thatmag)
end

--local
function equals(thisbigint, thatbigint)
   if not isvalidoperablevalue(thisbigint) or not isvalidoperablevalue(thatbigint) then
      -- if I can't operate on it, then it's probably not equal to what I can operate on
      return false
   end
   
   return compare(thisbigint, thatbigint) == 0
end

--local
function minimum(...)
   local list = {...}
   local smallest = list[1]
   
   for i = 2, #list do
      if compare(list[i], smallest) < 0 then
         smallest = list[i]
      end
   end
   
   return smallest
end

--local
function maximum(...)
   local list = {...}
   local largest = list[1]
   
   for i = 2, #list do
      if compare(list[i], largest) > 0 then
         largest = list[i]
      end
   end
   
   return list[1]
end


-- Bitwise functions
--local
function bitwisenot(value)
   local ok, reason = isvalidoperablevalue(value)
   if not ok then
      error(reason, 2)
   end
   
   return constructorbytearraytrusted(destructivemapbytearray(getbytearray(value), bitnot))
end

--local
function mutablebitwisenot(bigint)
   local sign, bytearray
   local ok, reason = isvalidbiginteger(bigint)
   if not ok then
      error(reason, 2)
   end
   
   destructiveconvertsignmagnitudetobytearray(bigint.sign, bigint.magnitude)
   destructivemapbytearray(bigint.magnitude, bitnot)
   
   bigint.sign, bigint.magnitude = destructiveconvertbytearraytosignmagnitude(bigint.magnitude)
   
   return bigint
end


--local
function binarybitwise(thisvalue, thatvalue, bitwisefunction)
   if not isvalidoperablevalue(thisvalue) or not isvalidoperablevalue(thatvalue) then
      error("attempt to perform bitwise operation on "
         .. gettype(thisvalue) .. " and " .. gettype(thatvalue), 3)
   end
   
   return constructorbytearraytrusted(destructivemergebytearrays(getbytearray(thisvalue),
                                                                 getbytearray(thatvalue),
                                                                 bitwisefunction))
end

--local
function mutablebinarybitwise(thisbigint, thatvalue, bitwisefunction)
   local thatbytearray
   local ok, reason = isvalidbiginteger(thisbigint)
   if not ok then
      error(reason, 3)
   end
   
   if not isvalidoperablevalue(thatvalue) then
      error("attempt to perform bitwiseoperation on bigint and "
         .. gettype(thatvalue), 3)
   end
   
   thatbytearray = getbytearray(thatvalue)
   
   destructiveconvertsignmagnitudetobytearray(thisbigint.sign, thisbigint.magnitude)
   destructivemergebytearrays(thisbigint.magnitude, thatbytearray, bitwisefunction)
   
   thisbigint.sign, thisbigint.magnitude = destructiveconvertbytearraytosignmagnitude(thisbigint.magnitude)
   
   return thisbigint
end


--local
function bitwiseand(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitand)
end

--local
function mutablebitwiseand(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitand)
end


--local
function bitwiseandnot(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitandnot)
end

--local
function mutablebitwiseandnot(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitandnot)
end


--local
function bitwiseor(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitor)
end

--local
function mutablebitwiseor(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitor)
end


--local
function bitwisexor(thisvalue, thatbigint)
   return binarybitwise(thisvalue, thatvalue, bitxor)
end

--local
function mutablebitwisexor(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitxor)
end


--local
function bitwiseleftshift(value, displacement)
   local numberofbytes, numberofbits
   local sign, mag, maglength
   local carry, shiftmultiplier
   local ok, reason
   
   ok, reason = isvalidoperablevalue(value)
   if not ok then
      error(reason, 2)
   end
   
   ok, reason = isvalidinteger(displacement)
   if not ok then
      error(reason, 2)
   end
   
   if displacement < 0 then
      -- precautionary error (will be removed soon)
      error("negative displacement not supported yet", 2)
   end
   
   if displacement == 0 then
      return value
   end
   
   sign, mag = getsignandmagnitude(value)
   maglength = #mag
   
   if sign == 0 then
      return constructorinteger(0)
   end
   
   numberofbytes = bitrightshift(displacement, 5)
   numberofbits = bitand(displacement, 0x1f)
   
   shiftmultiplier = bitleftshift(1, numberofbits)
   carry = 0
   
   if numberofbits ~= 0 then
      for i = maglength, 1, -1 do
         carry, mag[i] = splitlong(mag[i] * shiftmultiplier + carry)
      end
   end
   
   for i = 1, numberofbytes do
      mag[maglength + i] = 0
   end
   
   if carry ~= 0 then
      tableinsert(mag, 1, carry)
   end
   
   return constructorsignmagnitudetrusted(sign, mag)
end


-- Private Magnitude Functions
--local
function destructiveaddmagnitudes(thismag, thatmag)
   local thislength, thatlength, longerlength
   local carry
   
   thislength = #thismag
   thatlength = #thatmag
   
   longerlength = max(thislength, thatlengh)
   carry = 0
   
   for i = 0, longerlength - 1 do
      carry, thismag[longerlength - i] = splitlong(getbytefromend(thismag, i) +
                                                   getbytefromend(thatmag, i) +
                                                   carry)
   end
   
   if carry ~= 0 then
      -- If the carry amount exceeds the size of both magnitudes, then insert
      -- the value of the carry in front of everything.
      tableinsert(thismag, 1, carry)
   end
   
   return thismag
end

--local
function destructivesubtractmagnitudes(minuend, subtrahend)
   local borrow, difference
   local longerlen
   
   borrow = 0
   difference = 0
   longerlen = #minuend
   
   for i = 0, longerlen - 1 do
      difference = getbytefromend(minuend, i) -
                   getbytefromend(subtrahend, i) -
                   borrow
      
      if difference < 0 then
         borrow = 1
         --difference = -difference
      else
         borrow = 0
      end
      minuend[longerlen - i] = make32bitinteger(difference)
   end
   
   return destructivestripleadingzeros(minuend)
end


-- Public Math Functions
--local
function negate(bigint)
   local ok, reason = isvalidbiginteger(bigint)
   
   if not ok then
      error(reason, 2)
   end
   
   return constructorsignmagnitudetrusted(-bigint.sign, copyarray(bigint))
end

--local
function mutablenegate(bigint)
   local ok, reason = isvalidbiginteger(bigint)
   
   if not ok then
      error(reason, 2)
   end
   
   bigint.sign = -bigint.sign
   
   return bigint
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
function mutableabsolutevalue(bigint)
   local ok, reason = isvalidbiginteger(bigint)
   
   if not ok then
      error(reason, 2)
   end
   
   bigint.sign = bigint.sign == 0 and 0 or 1
   return bigint
end


--local
function add(thisvalue, thatvalue)
   local sign, mag
   local thissign, thismag
   local thatsign, thatmag
   local comparison
   
   if not isvalidoperablevalue(thisvalue) or not isvalidoperablevalue(thatvalue) then
      error("attempt to perform addition on "
         .. gettype(thisvalue) .. " and " .. gettype(thatvalue), 2)
   end
   
   thissign, thismag = getsignandmagnitude(thisvalue)
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thissign == 0 then
      return thatvalue
   elseif thatsign == 0 then
      return thisvalue
   end
   
   if thissign == thatsign then
      sign = thissign
      mag = destructiveaddmagnitudes(thismag, thatmag)
   else
      comparison = comparemagnitudes(thismag, thatmag)
      if comparison == 1 then
         sign = thissign
         mag = destructivesubtractmagnitudes(thismag, thatmag)
      elseif comparison == -1 then
         sign = thatsign
         mag = destructivesubtractmagnitudes(thatmag, thismag)
      else
         return constructorinteger(0)
      end
   end
   
   return constructorsignmagnitudetrusted(sign, mag)
end

--local
function mutableadd(thisbigint, thatvalue)
   local thissign, thismag
   local thatsign, thatmag
   local ok, reason
   
   ok, reason = isvalidbiginteger(thisbigint)
   if not ok then
      error(reason, 2)
   end
   
   if not isvalidoperablevalue(thatvalue) then
      error("attempt to perform addition on biginteger and "
         .. gettype(thatvalue), 2)
   end
   
   thissign, thismag = thisbigint.sign, thisbigint.magnitude
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thissign == 0 then
      if thatsign ~= 0 then
         thisbigint.sign = thatsign
         thisbigint.magnitude = thatmag
      end
      return
   elseif thatsign == 0 then
      return
   end
   
   if thissign == thatsign then
      thisbigint.magnitude = destructiveaddmagnitudes(thismag, thatmag)
   else
      comparison = comparemagnitudes(thismag, thatmag)
      if comparison == 1 then
         thisbigint.magnitude = destructivesubtractmagnitudes(thismag, thatmag)
      elseif comparison == -1 then
         thisbigint.sign = -thissign
         thisbigint.magnitude = destructivesubtractmagnitudes(thatmag, thismag)
      else
         thisbigint.sign = 0
         thisbigint.magnitude = {}
      end
   end
   
   return thisbigint
end


--local
function subtract(thisvalue, thatvalue)
   local sign, mag
   local thissign, thatsign
   local thismag, thatmag
   local comparison
   
   if not isvalidoperablevalue(thisvalue) or not isvalidoperablevalue(thatvalue) then
      error("attempt to perform subtraction on "
         .. gettype(thisvalue) .. " and " .. gettype(thatvalue), 2)
   end
   
   thissign, thismag = getsignandmagnitude(thisvalue)
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thissign == 0 then
      return negate(thatvalue)
   elseif thatsign == 0 then
      return thisvalue
   end
   
   if thissign ~= thatsign then
      sign = thissign
      mag = destructiveaddmagnitudes(thismag, thatmag)
   else
      comparison = comparemagnitudes(thismag, thatmag)
      if comparison == 1 then
         sign = thissign
         mag = destructivesubtractmagnitudes(thismag, thatmag)
      elseif comparison == -1 then
         sign = thatsign
         mag = destructivesubtractmagnitudes(thatmag, thismag)
      else
         return constructorinteger(0)
      end
   end
   
   return constructorsignmagnitudetrusted(sign, mag)
end

--local
function mutablesubtract(thisbigint, thatvalue)
   local thissign, thismag
   local thatsign, thatmag
   local ok, reason
   
   ok, reason = isvalidbiginteger(thisbigint)
   if not ok then
      error(reason, 2)
   end
   
   if not isvalidoperablevalue(thatvalue) then
      error("attempt to perform addition on biginteger and "
         .. gettype(thatvalue), 2)
   end
   
   thissign, thismag = thisbigint.sign, thisbigint.magnitude
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thissign == 0 then
      if thatsign ~= 0 then
         thisbigint.sign = -thatsign
         thisbigint.magnitude = thatmag
      end
      return
   elseif thatsign == 0 then
      return
   end
   
   if thissign ~= thatsign then
      thisbigint.sign = thissign
      thisbigint.magnitude = destructiveaddmagnitudes(thismag, thatmag)
   else
      comparison = comparemagnitudes(thismag, thatmag)
      if comparison == 1 then
         thisbigint.sign = thissign
         thisbigint.magnitude = destructivesubtractmagnitudes(thismag, thatmag)
      elseif comparison == -1 then
         thisbigint.sign = thatsign
         thisbigint.magnitude = destructivesubtractmagnitudes(thatmag, thismag)
      else
         thisbigint.sign = 0
         thisbigint.magnitude = {}
      end
   end
   
   return thisbigint
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
function stringofbytearray(bigint, dobinary)
   local bytearray, balen, str
   local ok, reason = isvalidoperablevalue(bigint)
   if not ok then
      error(reason, 2)
   end
   
   bytearray = getbytearray(bigint)
   balen = #bytearray
   
   if dobinary then
      if balen == 0 then
         return string.rep('0', 32)
      end
      
      str = getintegerstringbinary(getbytefromend(bytearray, 0))
   
      for i = 1, balen - 1 do
         str = getintegerstringbinary(getbytefromend(bytearray, i)) .. '_' .. str
      end
   else
      if balen == 0 then
         return string.rep('0', 8)
      end
      
      str = getintegerstringhexadecimal(getbytefromend(bytearray, 0))
   
      for i = 1, balen - 1 do
         str = getintegerstringhexadecimal(getbytefromend(bytearray, i)) .. '_' .. str
      end
   end
   
   return str
end

function reload()
   _G.package.loaded.biginteger = nil
   _G.biginteger = require('biginteger')
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
