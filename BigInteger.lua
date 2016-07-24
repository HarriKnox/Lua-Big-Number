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
local bitand = (bit32 or bit).band
local bitor = (bit32 or bit).bor
local bitnot = (bit32 or bit).bnot
local bitxor = (bit32 or bit).bxor
local bitleftshift = (bit32 and bit32.lshift) or (bit and bit.blshift)
local bitrightshift = (bit32 and bit32.rshift) or (bit and bit.blogit_rshift)
local bitarithmaticrightshift = (bit32 and bit32.arshift) or (bit and bit.brshift)
local bitandnot = function(x, y) return bitand(x, bitnot(y)) end

local floor = floor or math.floor
local max = max or math.max
local min = min or math.min
local random = random or math.random

local maxinteger = 0x7ffffffffffff -- 2 ^ 51 - 1; largest number bit32 can work with reliably
local maxmagnitudelength = 0x4000000 -- Integer.MAX_VALUE / Integer.SIZE  + 1 = 1 << 26
local negativemask = 0x80000000

local stringsub = string.sub
local stringmatch = string.match
local tableinsert = table.insert

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
local intradix = {
   0x00000000, 0x40000000, 0x4546b3db, 0x40000000, 0x48c27395, 0x159fd800,
   0x75db9c97, 0x40000000, 0x17179149, 0x3b9aca00, 0x0cc6db61, 0x19a10000,
   0x309f1021, 0x57f6c100, 0x0a2f1b6f, 0x10000000, 0x18754571, 0x247dbc80,
   0x3547667b, 0x4c4b4000, 0x6b5a6e1d, 0x06c20a40, 0x08d2d931, 0x0b640000,
   0x0e8d4a51, 0x1269ae40, 0x17179149, 0x1cb91000, 0x23744899, 0x2b73a840,
   0x34e63b41, 0x40000000, 0x4cfa3cc1, 0x5c13d840, 0x6d91b519, 0x039aa400}


local characters = {
   '1', '2', '3', '4', '5', '6', '7',
   '8', '9', 'A', 'B', 'C', 'D', 'E',
   'F', 'G', 'H', 'I', 'J', 'K', 'L',
   'M', 'N', 'O', 'P', 'Q', 'R', 'S',
   'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
   [0] = '0'}


-- Testing functions
function isvalidinteger(int)
   if type(int) ~= 'number' then
      return false, "not a number: it's a " .. type(int)
   elseif int > maxinteger or int < -maxinteger then
      return false, "outside allowable range"
   elseif int % 1 ~= 0 then
      return false, "not an integer"
   end
   return true
end

function isvalid32bitinteger(int)
   if type(int) ~= 'number' then
      return false, "not a number: it's a " .. type(int)
   elseif int > 0xffffffff then
      return false, "outside 32 bits"
   elseif int < 0 then
      return false, "negative"
   elseif int % 1 ~= 0 then
      return false, "not an integer"
   end
   
   return true
end

function isvalidbytearray(array)
   local ok, reason
   if type(array) ~= 'table' then
      return false, "not an array (table): it's a " .. type(array)
   end
   
   if isvalidbiginteger(array) then
      return false, "it's a biginteger and will not be treated as a byte-array"
   end
   
   for i = 1, #array do
      ok, reason = isvalid32bitinteger(array[i])
      if not ok then
         return false, "element " .. i .. " not a valid 32-bit number: " .. reason
      end
   end
   return true
end

function isvalidmagnitude(mag)
   local ok, reason
   ok, reason = isvalidbytearray(mag)
   
   if not ok then
      return false, reason
   end
   
   if #mag == 0 then
      return true
   end
   
   if mag[1] == 0 then
      return false, "has leading zeros"
   end
   
   return true
end

function isvalidsign(sign)
   if type(sign) ~= 'number' then
      return false, "not a number: it's a " .. type(sign)
   elseif sign ~= -1 and sign ~= 0 and sign ~= 1 then
      return false, "not in {-1, 0, 1}"
   end
   return true
end

function isvalidsignmagnitudecombination(sign, mag)
   if sign == 0 and #mag ~= 0 then
      -- a value with that is neither positive nor negative
      return false, "non-zero magnitude with zero sign"
   elseif sign ~= 0 and #mag == 0 then
      -- positive or negative zero (not allowed so there is one unique
      -- representation of zero (0), and that is sign = 0, #mag = 0
      return false, "non-zero sign with zero magnitude"
   end
   return true
end

function isvalidbiginteger(bigint)
   local ok, reason
   if type(bigint) ~= 'table' then
      return false, "not a table: it's a " .. type(bigint)
   end
   
   ok, reason = isvalidsign(bigint.sign)
   if not ok then
      return false, "bigint.sign not valid: " .. reason
   end
   
   ok, reason = isvalidmagnitude(bigint.magnitude)
   if not ok then
      return false, "bigint.magnitude not valid: " .. reason
   end
   
   ok, reason = isvalidsignmagnitudecombination(bigint.sign, bigint.magnitude)
   if not ok then
      return false, "bigint sign-magnitude mismatch: " .. reason
   end
   
   return true
end

function isvalidoperablevalue(value)
   if isvalidinteger(value) or isvalidbytearray(value) or isvalidbiginteger(value) then
      return true
   end
   
   return false, "it's a " .. type(value)
end

function isvalidradix(radix)
   local ok, reason
   
   ok, reason = isvalidinteger(radix)
   if not ok then
      return false, reason
   elseif radix < 2 or radix > 36 then
      return false, "outside allowable range"
   end
   
   return true
end

function isvalidstringnumber(str)
   if stringmatch(str, '^[%-+]?[0-9A-Za-z]+$') then
      return true
   end
   
   return false, "contains non-digit character"
end


-- Helper Bitwise Functions
function make32bitinteger(number)
   return bitand(number, 0xffffffff)
end

function long32bitrightshift(number)
   return floor(number / 0x100000000)
end

function long16bitrightshift(number)
   return floor(number / 0x10000)
end

function long32bitleftshift(number)
   return number * 0x100000000
end

function long16bitleftshift(number)
   return number * 0x10000
end


-- Helper Integer and Long Functions
function splitlong(number)
   return long32bitrightshift(number), make32bitinteger(number)
end

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

function integermultiplyandaddtosplitlong(x, ab, c)
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
function copyarrayto(source, destination)
   if source ~= destination then
      for i = 1, #source do
         destination[i] = source[i]
      end
   end
   
   return destination
end

function copyarray(array)
   return copyarrayto(array, {})
end

function cleararray(array)
   for i = 1, #array do
      array[i] = nil
   end
   
   return array
end

function clearandcopyintoarray(array, newvalues)
   local arraylength = #array
   local newvalueslength = #newvalues
   
   for i = 1, newvalueslength do
      array[i] = newvalues[i]
   end
   
   for i = newvalueslength + 1, arraylength do
      array[i] = nil
   end
   
   return array
end

function splitarrayatbytefromend(mag, pivot)
   -- Will split an array into two smaller arrays, upper and lower such that
   --  * upper will contain all elements from 1 to #mag - pivot
   --  * lower will contain all elements from (#mag - pivot + 1) to #mag
   -- pivot indexes from end of magnitude (0 is last element)
   -- will always return new arrays, even if pivot extends either end of the array
   local maglength = #mag
   local upper, lower
   local upperlength
   
   if pivot <= 0 then
      -- if the pivot extends to the right of the array (is negative pivot)
      -- or includes the last element (zero pivot) for upper
      return copyarray(mag), {}
   end
   
   if pivot >= maglength then
      -- if the pivot extends to the left of the array
      -- pivot == #mag means upper is from 1 to 0, so empty array
      return {}, copyarray(mag)
   end
   
   upperlength = maglength - pivot
   upper = {}
   lower = {}
   
   for i = 1, pivot do
      upper[i] = mag[i]
   end
   
   for i = pivot + 1, maglength do
      lower[i - pivot] = mag[i]
   end
   
   return upper, lower
end


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

function copyandsignextendbytearray(array, newlength)
   return signextendbytearrayto(array, {}, newlength)
end

function destructivesignextendbytearray(array, newlength)
   return signextendbytearrayto(array, array, newlength)
end


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

function copyandstripleadingzeros(array)
   return stripleadingzerosto(array, {})
end

function destructivestripleadingzeros(array)
   return stripleadingzerosto(array, array)
end


function negatebytearrayto(source, destination)
   local length = #source
   local addend = 1
   
   for i = length, 1, -1 do
      addend, destination[i] = splitlong(bitnot(source[i]) + addend)
   end
   
   return destructivestripleadingzeros(destination)
end

function copyandnegatebytearray(array)
   return negatebytearrayto(array, {})
end

function destructivenegatebytearray(array)
   return negatebytearrayto(array, array)
end


function destructivemultiplyandadd(mag, factor, addend)
   local maglength = #mag
   local product = 0
   local carry = 0
   local index = maglength
   
   for i = maglength, 1, -1 do
      carry, mag[i] = integermultiplyandaddtosplitlong(factor, mag[i], carry)
   end
   
   carry = addend
   
   for i = maglength, 1, -1 do
      carry, mag[i] = splitlong(mag[i] + carry)
   end
   
   return mag
end


-- Private Getter functions
function gettype(thing)
   return (isvalidinteger(thing) and 'integer') or
          (isvalidbiginteger(thing) and 'biginteger') or
          (isvalidbytearray(thing) and 'byte-array') or
          type(thing)
end

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

function getbytearraymagnitude(array)
   if getbytearraysign(array) == -1 then
      return copyandnegatebytearray(array)
   end
   return copyandstripleadingzeros(array)
end

function getbytearraysignandmagnitude(array)
   local sign = getbytearraysign(array)
   if sign == -1 then
      return sign, copyandnegatebytearray(array)
   end
   return sign, copyandstripleadingzeros(array)
end


function getnumbersign(int)
   return (int < 0 and -1) or (int > 0 and 1) or 0
end

function getnumbermagnitude(int)
   return splitlongandstripleadingzeros(int < 0 and -int or int)
end

function getnumbersignandmagnitude(int)
   return getnumbersign(int), getnumbermagnitude(int)
end


function getsign(value)
   if isvalidbiginteger(value) then
      return value.sign
      
   elseif isvalidbytearray(value) then
      return getbytearraysign(value)
      
   elseif isvalidinteger(value) then
      return getnumbersign(value)
   end
   
   -- precautionary error that should not run unless I missed a check somewhere
   error("cannot obtain sign of " .. gettype(value))
end

function getmagnitude(value)
   if isvalidbiginteger(value) then
      return copyarray(value.magnitude)
      
   elseif isvalidbytearray(value) then
      return getbytearraymagnitude(value)
      
   elseif isvalidinteger(value) then
      return getnumbermagnitude(value)
   end
   
   -- precautionary error that should not run unless I missed a check somewhere
   error("cannot obtain magnitude of " .. gettype(value))
end

function getsignandmagnitude(value)
   if isvalidbiginteger(value) then
      return value.sign, copyarray(value.magnitude)
      
   elseif isvalidbytearray(value) then
      return getbytearraysignandmagnitude(value)
      
   elseif isvalidinteger(value) then
      return getnumbersignandmagnitude(value)
   end
   
   -- precautionary error that should not run unless I missed a check somewhere
   error("cannot obtain sign and magnitude of " .. gettype(value))
end


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

function getbytefromend(array, displacement)
   local arraylength = #array
   
   if displacement < 0 or displacement >= arraylength then
      return 0
   end
   return array[arraylength - displacement]
end


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

function copyandconvertsignmagnitudetobytearray(sign, mag)
   return convertsignmagnitudetobytearrayto(sign, mag, {})
end

function destructiveconvertsignmagnitudetobytearray(sign, mag)
   return convertsignmagnitudetobytearrayto(sign, mag, mag)
end


function convertbytearraytosignmagnitudeto(source, destination)
   local sign = getbytearraysign(source)
   if sign == 0 then
      return 0, cleararray(destination)
   end
   
   if sign == -1 then
      negatebytearrayto(source, destination)
      return -1, destination
   end
   
   return 1, destructivestripleadingzeros(destination)
end

function copyandconvertbytearraytosignmagnitude(bytearray)
   return convertbytearraytosignmagnitudeto(bytearray, {})
end

function destructiveconvertbytearraytosignmagnitude(bytearray)
   return convertbytearraytosignmagnitudeto(bytearray, bytearray)
end


-- Byte-Array Mappers
function destructivemapbytearray(bytearray, mapfunction)
   for i = 1, #bytearray do
      bytearray[i] = mapfunction(bytearray[i])
   end
   
   return bytearray
end

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
function createbiginteger(sign, mag)
   return {sign = sign, magnitude = mag}
end

function constructorinteger(int)
   local ok, reason = isvalidinteger(int)
   if not ok then
      error("int not valid integer: " .. reason)
   end
   
   return createbiginteger(getnumbersignandmagnitude(int))
end

function constructorsignmagnitudetrusted(sign, mag)
   local ok, reason
   
   ok, reason = isvalidsign(sign)
   if not ok then
      error("sign not valid sign: " .. reason)
   end
   
   ok, reason = isvalidmagnitude(mag)
   if not ok then
      error("mag not valid magnitude: " .. reason)
   end
   
   ok, reason = isvalidsignmagnitudecombination(sign, mag)
   if not ok then
      error("sign-magnitude mismatch: " .. reason)
   end
   
   if #mag >= maxmagnitudelength then
      error("biginteger would overflow supported range")
   end
   
   return createbiginteger(sign, mag)
end

function constructorsignmagnitude(sign, mag)
   local magnitude
   local ok, reason
   
   ok, reason = isvalidbytearray(mag)
   if not ok then
      error("mag not valid magnitude: " .. reason)
   end
   
   return constructorsignmagnitudetrusted(sign, copyandstripleadingzeros(mag))
end

function constructorbitsrng(bitlength, randomnumbergenerator)
   local mag = {}
   local numberofwords, excessbytes
   
   if bitlength < 0 or bitlength % 1 ~= 0 then
      error("bit length not valid: must be a non-negative integer")
   end
   
   if type(randomnumbergenerator()) ~= "number" then
      error("RNG function not valid: must return a number in the range [0, 1)")
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

function constructorbytearraytrusted(array)
   local sign, mag
   local ok, reason
   
   ok, reason = isvalidbytearray(array)
   if not ok then
      error("array not valid byte-array: " .. reason)
   end
   
   sign = getbytearraysign(array)
   
   if sign == -1 then
      destructivenegatebytearray(array)
   end
   
   if #array >= maxmagnitudelength then
      error("biginteger would overflow supported range")
   end
   
   return createbiginteger(sign, array)
end

function constructorbytearray(array)
   return constructorbytearraytrusted(getbytearray(array))
end

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
      error("radix not valid radix: " .. reason)
   end
   
   ok, reason = isvalidstringnumber(str)
   if not ok then
      error("str not valid: " .. reason)
   end
   
   strsign = stringmatch(str, '[-+]')
   
   sign = strsign == '-' and -1 or 1
   cursor = strsign and 2 or 1
   
   for i = cursor, strlength do
      if getcharacternumericalvalue(stringsub(str, i, i)) >= radix then
         -- if a character is not a proper digit, getcharacternumericalvalue will return 36,
         -- which will always be >= radix
         error("illegal digit: " .. stringsub(str, i, i))
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
      error("biginteger would overflow supported range")
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
      error("illegal digit: " .. group)
   end
   mag[numberofwords] = groupvalue
   
   -- Process remaining groups
   superradix = intradix[radix]
   while cursor <= strlength do
      group = stringsub(str, cursor, cursor + digitsperintegerradix - 1)
      cursor = cursor + digitsperintegerradix
      groupvalue = tonumber(group, radix)
      if not groupvalue then
         error("illegal digit: " .. group)
      end
      destructivemultiplyandadd(mag, superradix, groupvalue)
   end
   
   destructivestripleadingzeros(mag)
   if #mag >= maxmagnitudelength then
      error("biginteger would overflow supported range")
   end
   
   return createbiginteger(sign, mag)
end

function clone(bigint)
   local ok, reason = isvalidbiginteger(bigint)
   if not ok then
      error("bigint not valid biginteger: " .. reason)
   end
   
   return constructorsignmangitude(bigint.sign, bigint.magnitude)
end

-- Main Constructor
-- will interpret passed arguments to call appropriate constructor
function biginteger(a, b)
   local typea = gettype(a)
   local typeb = gettype(b)
   
   if typea == 'integer' then
      if typeb == 'nil' then
         return constructorinteger(a)
      elseif typeb == 'byte-array' then
         return constructorsignmagnitude(a, b)
      elseif typeb == 'function' then
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
      typea .. " and " .. typeb)
end


-- Comparison Functions
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

function compare(thisvalue, thatvalue)
   local thissign, thismag
   local thatsign, thatmag
   
   if rawequal(thisvalue, thatvalue) then
      return 0
   end
   
   if not isvalidoperablevalue(thisvalue) or not isvalidoperablevalue(thatvalue) then
      error("attempt to perform comparison on "
         .. gettype(thisvalue) .. " and " .. gettype(thatvalue))
   end
   
   thissign, thismag = getsignandmagnitude(thisvalue)
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thissign ~= thatsign then
      -- If the signs differ, then they cannot be equal
      return thissign > thatsign and 1 or -1
   end
   
   return comparemagnitudes(thismag, thatmag)
end

function equals(thisbigint, thatbigint)
   if not isvalidoperablevalue(thisbigint) or not isvalidoperablevalue(thatbigint) then
      -- if I can't operate on it, then it's probably not equal to what I can operate on
      return false
   end
   
   return compare(thisbigint, thatbigint) == 0
end

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
function bitwisenot(value)
   local ok, reason = isvalidoperablevalue(value)
   if not ok then
      error("value not operable: " .. reason)
   end
   
   return constructorbytearraytrusted(destructivemapbytearray(getbytearray(value), bitnot))
end

function mutablebitwisenot(bigint)
   local sign, bytearray
   local ok, reason = isvalidbiginteger(bigint)
   if not ok then
      error("bigint not valid biginteger: " .. reason)
   end
   
   destructiveconvertsignmagnitudetobytearray(bigint.sign, bigint.magnitude)
   destructivemapbytearray(bigint.magnitude, bitnot)
   
   bigint.sign, bigint.magnitude = destructiveconvertbytearraytosignmagnitude(bigint.magnitude)
   
   return bigint
end


function binarybitwise(thisvalue, thatvalue, bitwisefunction)
   if not isvalidoperablevalue(thisvalue) or not isvalidoperablevalue(thatvalue) then
      error("attempt to perform bitwise operation on "
         .. gettype(thisvalue) .. " and " .. gettype(thatvalue))
   end
   
   return constructorbytearraytrusted(destructivemergebytearrays(getbytearray(thisvalue),
                                                                 getbytearray(thatvalue),
                                                                 bitwisefunction))
end

function mutablebinarybitwise(thisbigint, thatvalue, bitwisefunction)
   local thatbytearray
   local ok, reason = isvalidbiginteger(thisbigint)
   if not ok then
      error("thisbigint not valid biginteger: " .. reason)
   end
   
   if not isvalidoperablevalue(thatvalue) then
      error("attempt to perform bitwiseoperation on biginteger and "
         .. gettype(thatvalue))
   end
   
   thatbytearray = getbytearray(thatvalue)
   
   destructiveconvertsignmagnitudetobytearray(thisbigint.sign, thisbigint.magnitude)
   destructivemergebytearrays(thisbigint.magnitude, thatbytearray, bitwisefunction)
   
   thisbigint.sign, thisbigint.magnitude = destructiveconvertbytearraytosignmagnitude(thisbigint.magnitude)
   
   return thisbigint
end


function bitwiseand(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitand)
end

function mutablebitwiseand(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitand)
end


function bitwiseandnot(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitandnot)
end

function mutablebitwiseandnot(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitandnot)
end


function bitwiseor(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitor)
end

function mutablebitwiseor(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitor)
end


function bitwisexor(thisvalue, thatbigint)
   return binarybitwise(thisvalue, thatvalue, bitxor)
end

function mutablebitwisexor(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitxor)
end


function destructiveleftshift(mag, displacement)
   local maglength
   local numberofbits, numberofbytes
   local shiftmultiplier, carry
   
   if displacement == 0 then
      return mag
   end
   
   maglength = #mag
   
   numberofbytes = bitrightshift(displacement, 5)
   numberofbits = bitand(displacement, 0x1f)
   
   shiftmultiplier = bitleftshift(1, numberofbits)
   carry = 0
   
   if numberofbits ~= 0 then
      for i = maglength, 1, -1 do
         carry, mag[i] = integermultiplyandaddtosplitlong(mag[i], shiftmultiplier, carry)
      end
   end
   
   for i = 1, numberofbytes do
      mag[maglength + i] = 0
   end
   
   if carry ~= 0 then
      tableinsert(mag, 1, carry)
   end
   
   return mag
end

function destructiverightshift(mag, displacement)
   local maglength
   local numberofbits, numberofbytes
   local numberofbitsadjusted
   local shiftmultiplier, lowbits, carry, oldcarry
   
   if displacement == 0 then
      return mag
   end
   
   maglength = #mag
   numberofbytes = bitrightshift(displacement, 5)
   
   if numberofbytes >= maglength then
      -- when right-shifting more bits than there are in the array, the result
      -- is -1 for negative values and 0 for non-negative values
      cleararray(mag)
      
      return mag
   end
   
   numberofbits = bitand(displacement, 0x1f)
   numberofbitsadjusted = 32 - numberofbits
   shiftmultiplier = bitleftshift(1, numberofbitsadjusted)
   carry = 0
   oldcarry = 0
   
   if numberofbits ~= 0 then
      for i = 1, maglength do
         lowbits, carry = integermultiplyandaddtosplitlong(mag[i], shiftmultiplier, 0)
         mag[i] = lowbits + oldcarry
         oldcarry = carry
      end
   end
   
   for i = 0, numberofbytes - 1 do
      mag[maglength - i] = nil
   end
   
   return mag
end


function bitwiseshift(value, displacement, right)
   local sign, mag
   local ok, reason
   
   ok, reason = isvalidoperablevalue(value)
   if not ok then
      error("value not operable: " .. reason)
   end
   
   ok, reason = isvalidinteger(displacement)
   if not ok then
      error("displacement not valid integer: " .. reason)
   end
   
   if displacement < 0 then
      displacement = -displacement
      right = not right
   end
   
   sign, mag = getsignandmagnitude(value)
   
   if right then
      destructiverightshift(mag, displacement)
      
      if #mag == 0 then
         if sign == -1 then
            mag[1] = 0xffffffff
         else
            sign = 0
         end
      end
   else
      destructiveleftshift(mag, displacement)
   end
   
   return constructorsignmagnitudetrusted(sign, destructivestripleadingzeros(mag))
end

function mutablebitwiseshift(bigint, displacement, right)
   local ok, reason = isvalidbiginteger(bigint)
   if not ok then
      error("bigint not valid biginteger: " .. reason)
   end
   
   ok, reason = isvalidinteger(displacement)
   if not ok then
      error("displacement not valid integer: " .. reason)
   end
   
   if displacement < 0 then
      displacement = -displacement
      right = not right
   end
   
   if right then
      destructiverightshift(bigint.magnitude, displacement)
      
      if #bigint.magnitude == 0 then
         if bigint.sign == -1 then
            bigint.magnitude[1] = 0xffffffff
         else
            bigint.sign = 0
         end
      end
   else
      bigint.magnitude = destructiveleftshift(bigint.magnitude, displacement)
   end
   
   destructivestripleadingzeros(bigint.magnitude)
   
   return bigint
end


function bitwiseleftshift(value, displacement)
   return bitwiseshift(value, displacement, false)
end

function mutablebitwiseleftshift(bigint, displacement)
   return mutablebitshift(bigint, displacement, false)
end


function bitwiserightshift(value, displacement)
   return bitwiseshift(value, displacement, true)
end

function mutablebitwiserightshift(bigint, displacement)
   return mutablebitshift(bigint, displacement, true)
end


-- Private Magnitude Functions
function destructiveaddmagnitudes(thismag, thatmag)
   local thislength, thatlength, longerlength
   local carry
   
   thislength = #thismag
   thatlength = #thatmag
   
   longerlength = max(thislength, thatlength)
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
function negate(bigint)
   local ok, reason = isvalidbiginteger(bigint)
   
   if not ok then
      error("bigint not valid biginteger: " .. reason)
   end
   
   return constructorsignmagnitudetrusted(-bigint.sign, copyarray(bigint))
end

function mutablenegate(bigint)
   local ok, reason = isvalidbiginteger(bigint)
   
   if not ok then
      error("bigint not valid biginteger: " .. reason)
   end
   
   bigint.sign = -bigint.sign
   
   return bigint
end


function absolutevalue(bigint)
   local ok, reason = isvalidbiginteger(bigint)
   
   if not ok then
      error("bigint not valid biginteger: " .. reason)
   end
   
   return bigint.sign < 0 and negate(bigint) or bigint
end

function mutableabsolutevalue(bigint)
   local ok, reason = isvalidbiginteger(bigint)
   
   if not ok then
      error("bigint not valid biginteger: " .. reason)
   end
   
   bigint.sign = bigint.sign == 0 and 0 or 1
   return bigint
end


function add(thisvalue, thatvalue)
   local sign, mag
   local thissign, thismag
   local thatsign, thatmag
   local comparison
   
   if not isvalidoperablevalue(thisvalue) or not isvalidoperablevalue(thatvalue) then
      error("attempt to perform addition on "
         .. gettype(thisvalue) .. " and " .. gettype(thatvalue))
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

function mutableadd(thisbigint, thatvalue)
   local thissign, thismag
   local thatsign, thatmag
   local ok, reason
   
   ok, reason = isvalidbiginteger(thisbigint)
   if not ok then
      error("thisbigint not valid biginteger: " .. reason)
   end
   
   if not isvalidoperablevalue(thatvalue) then
      error("attempt to perform addition on biginteger and "
         .. gettype(thatvalue))
   end
   
   thissign, thismag = thisbigint.sign, thisbigint.magnitude
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thissign == 0 then
      if thatsign ~= 0 then
         thisbigint.sign = thatsign
         thisbigint.magnitude = thatmag
      end
      return thisbigint
   elseif thatsign == 0 then
      return thisbigint
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


function subtract(thisvalue, thatvalue)
   local sign, mag
   local thissign, thatsign
   local thismag, thatmag
   local comparison
   
   if not isvalidoperablevalue(thisvalue) or not isvalidoperablevalue(thatvalue) then
      error("attempt to perform subtraction on "
         .. gettype(thisvalue) .. " and " .. gettype(thatvalue))
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

function mutablesubtract(thisbigint, thatvalue)
   local thissign, thismag
   local thatsign, thatmag
   local ok, reason
   
   ok, reason = isvalidbiginteger(thisbigint)
   if not ok then
      error("thisbigint not valid biginteger: " .. reason)
   end
   
   if not isvalidoperablevalue(thatvalue) then
      error("attempt to perform addition on biginteger and "
         .. gettype(thatvalue))
   end
   
   thissign, thismag = thisbigint.sign, thisbigint.magnitude
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thissign == 0 then
      if thatsign ~= 0 then
         thisbigint.sign = -thatsign
         thisbigint.magnitude = thatmag
      end
      return thisbigint
   elseif thatsign == 0 then
      return thisbigint
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


function squarecolinplumb(mag)
   local maglength
   local result, resultlengh, index
   local carry, piece
   local producthigh, productlow, extraint
   
   maglength = #mag
   resultlength = maglength * 2
   
   result = {}
   for i = 1, resultlength do
      result[i] = 0
   end
   
   for i = 0, maglength - 1 do
      -- Multiply all squares and put them to result
      piece = getbytefromend(mag, i)
      index = resultlength - i - i
      result[index - 1], result[index] =
         integermultiplyandaddtosplitlong(piece, piece, 0)
   end
   
   destructiverightshift(result, 1)
   
   for i = 1, maglength - 1 do
      for j = 0, i - 1 do
         index = resultlength - i - j
         producthigh, productlow = integermultiplyandaddtosplitlong(getbytefromend(mag, j),
                                                                    getbytefromend(mag, i),
                                                                    0)
         
         -- Add productlow to the corresponding result byte and continue the
         -- carry up to extraint
         carry, result[index] = splitlong(result[index] + productlow)
         extraint, producthigh = splitlong(producthigh + carry)
         
         -- Add producthigh to the next corresponding result byte and continue
         -- the carry to extraint
         index = index - 1
         carry, result[index] = splitlong(result[index] + producthigh)
         --extraint = extraint + carry
         --carry = extraint
         carry = extraint + carry
         
         -- set carry to extraint and propagate through the result
         while carry ~= 0 do
            index = index - 1
            carry, result[index] = splitlong(result[index] + carry)
         end
      end
   end
   
   destructiveleftshift(result, 1)
   
   if bitand(getbytefromend(mag, 0), 1) == 1 then
      result[resultlength] = result[resultlength] + 1
   end
   
   return destructivestripleadingzeros(result)
end

function squaremagnitude(mag)
   return squarecolinplumb(mag)
end

function square(value)
   local sign, mag
   local ok, reason
   
   
   ok, reason = isvalidoperablevalue(value)
   if not ok then
      error("value not operable: " .. reason)
   end
   
   sign, mag = getsignandmagnitude(value)
   
   if sign == 0 then
      return value
   end
   
   return constructorsignmagnitude(1, squaremagnitude(mag))
end



-- temporary functions to print the number in hexadecimal or binary
function getintegerstringhexadecimal(number)
   local str, index = {}, 1
   
   for i = 28, 0, -4 do
      str[index], index = characters[bitand(bitrightshift(number, i), 0xf)], index + 1
   end
   
   return table.concat(str)
end

function getintegerstringbinary(number)
   local str, index = {}, 1
   
   for i = 31, 0, -1 do
      str[index], index = characters[bitand(bitrightshift(number, i), 0x1)], index + 1
   end
   
   return table.concat(str)
end

function stringofbytearray(bigint, dobinary)
   local bytearray, balen, str
   local ok, reason = isvalidoperablevalue(bigint)
   
   if not ok then
      error("bigint not operable: " .. reason)
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
      error("Knox's BigInteger library compatibility for ComputerCraft requires CC version 1.75 or later")
   end
   _ENV.biginteger = biginteger
   return
end

return bi--{biginteger = biginteger}
