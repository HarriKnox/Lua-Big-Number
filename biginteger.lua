local bi = {} -- Sandbox for testing purposes.
setmetatable(bi, {__index = _G})
_ENV = bi

--[[ Definitions:
 * Integer: A Lua value of type 'number' that is an integer (x % 1 == 0).
 
 * 32-bit Integer: An integer that is non-negative and less than 2 ^ 32.
   
 * Byte: A 32-bit integer represented as a Two's complement number, used in a
   byte-array. Most languages define bytes as being 8-bit integers, not
   32-bits. However, since 'byte' is the name of the elements in a byte-array
   in the Java implementation, the name of the elements of the number-arrays
   in this library is 'byte'.
   
 * Byte-Array: A sequence (table/array) of numbers that follows these rules
   a) All numbers in the array are valid 32-bit integers.
      
   b) A zero-length array or array of all zeros is logically equivalent to 0.
      
   c) The array is one-indexed (indices start at 1 not 0) and big-endian. If
      the array has a byte 0 (array[0]), it will not be read. Byte 1 is the
      most significant byte.
      
   d) The array is interpreted as a Two's complement number: the sign of the
      byte-array is determined by the sign the most significant byte. If the
      first byte is a negative Two's complement number, then the byte-array
      will be considered negative: leading zeros will prevent the byte-array
      from being interpreted as negative. Likewise, if the first element is
      not negative, the byte-array will be considered positive: leading sign
      bits [0xffffffff] will prevent the byte-array from being interpreted as
      positive.
       * {   0xffff0000} = -65'536 (negative)
       * {0, 0xffff0000} = 4'294'901'760 (positive)
         
       * {            0x0000ffff} = 65'535 (positive)
       * {0xffffffff, 0x0000ffff} = -4'294'901'761 (negative)
      
   e) Note: For testing and iterating through byte-arrays the default length
      operator (#) is used. This means that the byte-array must have a
      sequence of numbers for all indices between 1 and #array (that is to
      say for all 1 <= i <= #array, t[i] ~= nil). If #array == 0 then the
      byte-array is still valid: it has a zero-length sequence and is thus
      equal to 0 (zero).
      
   f) Note: Since a byte-array is a table, it may have keys and values that
      are not in the sequence (such as t.name = 'Harri'). It is possible for
      someone to pass in any table/prototype/object and it will be
      interpreted as a byte-array. Because of this, the only tables that
      would otherwise pass the byte-array test will fail if they pass the
      biginteger test (byte-array iff array of bytes and not biginteger): this
      is so tables that could be interpreted as bigintegers would be interpreted
      as bigintegers where they may have been interpreted as bytearrays.
   
 * Magnitude: A type of byte-array with the following exceptions:
   a) All numbers are treated as unsigned (ignores negatives in
      Two's complement form).
       * {            0x0000ffff} = 65'535 (positive)
       * {0xffffffff, 0x0000ffff} = 18'446'744'069'414'649'855 (positive)
      
   b) Leading zeros are not allowed, and thus a magnitude of only zeros is
      not allowed. A zero-length magnitude is the only magnitude equal to 0.
      This ensures every magnitude is unique.
   
 * Sign (different than the sign bit for a Two's complement number):
   Either -1, 0, or +1; determines whether the value is negative, zero, or
   positive, respectively.
    * A sign of +1 or -1 cannot be assigned to a value that is logically
      equivalent to 0 (zero). This is to avoid ambiguity in +0 and -0 and makes
      all zeros equivalent.
    * A sign of 0 cannot be assigned to a value that is not logically equivalent
      to 0 (zero). A non-zero magnitude with no sign is an illegal number.
   
 * Biginteger: A table with (at minimum) two fields (`sign` and `magnitude`)
   that are a valid sign and magnitude, such that every integer has a unique
   representation in the combination of sign and magnitude.
]]

--[[ To-do list:
 * GCD
 * modulus
 * quick increment and decrement
 * prime number stuff
 * serializable magnitude/bytearray string
 * string reading ("Harrison is cool" -> {0x48617272, 0x69736f6e, 0x20697320, 0x636f6f6c})
 * metatable
 * ratio module
 * proper encapsulation (surprisingly, not all functions are supposed to be public)
 * make fast (functional overhead for bitwise operations is high, but Lua 5.2 doesn't support bitwise sigils)
]]

--[[ Local fields/constants ]]
local bitand = (bit32 or bit).band
local bitor  = (bit32 or bit).bor
local bitnot = (bit32 or bit).bnot
local bitxor = (bit32 or bit).bxor
local bitleftshift  = (bit32 and bit32.lshift) or (bit and bit.blshift)
local bitrightshift = (bit32 and bit32.rshift) or (bit and bit.blogic_rshift)
local bitandnot = function(x, y) return bitand(x, bitnot(y)) end

local floor  = floor  or math.floor
local ceil   = ceil   or math.ceil
local max    = max    or math.max
local min    = min    or math.min
local abs    = abs    or math.abs
local log    = log    or math.log

local stringchar    = string.char
local stringbyte    = string.byte
local stringsub     = string.sub
local stringmatch   = string.match
local stringrep     = string.rep
local stringreverse = string.reverse
local tableconcat   = table.concat
local tableinsert   = table.insert
-- Because of functional overhead, use table.insert only to insert in the
-- middle/beginning of an array. Use `t[#t + 1] = _` when appending.

--[[ Constants ]]
local maxinteger         = 0x7ffffffffffff -- 2^51 - 1; largest number bit32 can work with reliably (despite being a 32-bit library)
local maxmagnitudelength =  0x3fffffffffff -- 2^51 / 32 - 1; largest magnitude allowable because of 32 bits per byte (allows for up to 2^51 bits)
local negativemask       =      0x80000000 -- mask used for 32-bit integers to get sign

local log2 = log(2)

--[[ Threshold values ]]
local karatsubasquarethreshold = 128
local karatsubamultiplythreshold = 80

local toomcooksquarethreshold = 216
local toomcookmultiplythreshold = 240

local burnikelzieglerthreshold = 80
local burnikelziegleroffset = 40

local schoenhagebaseconversionthreshold = 20

--[[ Tables and Caches ]]
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

-- The list of ASCII characters used for each digit value, with the index as the
-- value. Lowercase is used to increase variety in the heights of numbers.
--              123abckz92gpqbn8 vs 123ABCKZ92GPQBN8
--                        varied    a large rectangle
local characters = {
   '1', '2', '3', '4', '5', '6', '7',
   '8', '9', 'a', 'b', 'c', 'd', 'e',
   'f', 'g', 'h', 'i', 'j', 'k', 'l',
   'm', 'n', 'o', 'p', 'q', 'r', 's',
   't', 'u', 'v', 'w', 'x', 'y', 'z',
   [0] = '0'}

-- The table of values `log(2) / log(i)`, used for large string base conversion.
local radixlogs = {
             nil ,             1 , log2 / log( 3), log2 / log( 4),
   log2 / log( 5), log2 / log( 6), log2 / log( 7), log2 / log( 8),
   log2 / log( 9), log2 / log(10), log2 / log(11), log2 / log(12),
   log2 / log(13), log2 / log(14), log2 / log(15), log2 / log(16),
   log2 / log(17), log2 / log(18), log2 / log(19), log2 / log(20),
   log2 / log(21), log2 / log(22), log2 / log(23), log2 / log(24),
   log2 / log(25), log2 / log(26), log2 / log(27), log2 / log(28),
   log2 / log(29), log2 / log(30), log2 / log(31), log2 / log(32),
   log2 / log(33), log2 / log(34), log2 / log(35), log2 / log(36)}

-- The cache of powers r^2^n for each radix r, for large string base conversion.
-- There are three layers of tables: this is an array of lists of magnitudes.
--  * `powercache` is an array with radix indices
--  * `powercache[radix]` is a list with exponent indices
--  * `powercache[radix][n]` is an integer or a magnitude equal to radix^2^n
local powercache = {
       nil , { 2 ^ 2}, { 3 ^ 2}, { 4 ^ 2}, { 5 ^ 2}, { 6 ^ 2},
   { 7 ^ 2}, { 8 ^ 2}, { 9 ^ 2}, {10 ^ 2}, {11 ^ 2}, {12 ^ 2},
   {13 ^ 2}, {14 ^ 2}, {15 ^ 2}, {16 ^ 2}, {17 ^ 2}, {18 ^ 2},
   {19 ^ 2}, {20 ^ 2}, {21 ^ 2}, {22 ^ 2}, {23 ^ 2}, {24 ^ 2},
   {25 ^ 2}, {26 ^ 2}, {27 ^ 2}, {28 ^ 2}, {29 ^ 2}, {30 ^ 2},
   {31 ^ 2}, {32 ^ 2}, {33 ^ 2}, {34 ^ 2}, {35 ^ 2}, {36 ^ 2}}


--[[ Testing functions ]]
function isvalidinteger(int)
   local r = "not a valid integer: "
   if type(int) ~= 'number' then
      return false, r .. "it's a " .. type(int)
   elseif int > maxinteger or int < -maxinteger then
      return false, r .. "outside allowable range"
   elseif int % 1 ~= 0 then
      return false, r .. "it's a float"
   end
   return true
end

function isvalid32bitinteger(int)
   local r = "not a valid 32-bit integer: "
   if type(int) ~= 'number' then
      return false, r .. "it's a " .. type(int)
   elseif int > 0xffffffff then
      return false, r .. "outside 32 bits"
   elseif int < 0 then
      return false, r .. "negative"
   elseif int % 1 ~= 0 then
      return false, r .. "it's a float"
   end
   
   return true
end

function isvalidabsolute32bitinteger(int)
   local ok, reason
   local r = "not a valid absolute 32-bit integer: "
   
   if type(int) ~= 'number' then
      return false, r .. "it's a " .. type(int)
   end
   
   ok, reason = isvalid32bitinteger(abs(int))
   
   return ok, r .. reason
end

function isvalidbytearray(array)
   local ok, reason
   local r = "not a valid byte-array: "
   
   if type(array) ~= 'table' then
      return false, r .. "not an array (table): it's a " .. type(array)
   end
   
   if isvalidbiginteger(array) then
      return false, r .. "it's a biginteger and will not be treated as a byte-array"
   end
   
   for i = 1, #array do
      ok, reason = isvalid32bitinteger(array[i])
      if not ok then
         return false, r .. "element " .. i .. " " .. reason
      end
   end
   
   return true
end

function isvalidmagnitude(mag)
   local ok, reason = isvalidbytearray(mag)
   local r = "not a valid magnitude: "
   
   if not ok then
      return false, r .. reason
   end
   
   if #mag >= maxmagnitudelength then
      return false, r .. "too large (overflow)"
   end
   
   if mag[1] == 0 then
      return false, r .. "has leading zeros"
   end
   
   return true
end

function isvalidsign(sign)
   local r = "not a valid sign: "
   
   if type(sign) ~= 'number' then
      return false, r .. "not a number: it's a " .. type(sign)
   elseif sign ~= -1 and sign ~= 0 and sign ~= 1 then
      return false, r .. "not in {-1, 0, 1}"
   end
   
   return true
end

function isvalidsignmagnitudecombination(sign, mag)
   local r = "not a valid sign-magnitude pair: "
   
   if sign == 0 and #mag ~= 0 then
      -- a value with that is neither positive nor negative nor zero
      return false, r .. "non-zero magnitude with zero sign"
   elseif sign ~= 0 and #mag == 0 then
      -- positive or negative zero (not allowed so there is one unique
      -- representation of zero (0), and that is sign = 0, #mag = 0
      return false, r .. "non-zero sign with zero magnitude"
   end
   return true
end

function isvalidbiginteger(bigint)
   local ok, reason
   local r = "not a valid biginteger: "
   
   if type(bigint) ~= 'table' then
      return false, r .. "not a table: it's a " .. type(bigint)
   end
   
   ok, reason = isvalidsign(bigint.sign)
   if not ok then
      return false, r .. reason
   end
   
   ok, reason = isvalidmagnitude(bigint.magnitude)
   if not ok then
      return false, r .. reason
   end
   
   ok, reason = isvalidsignmagnitudecombination(bigint.sign, bigint.magnitude)
   if not ok then
      return false, r .. reason
   end
   
   return true
end

function isvalidradix(radix)
   local ok, reason = isvalidinteger(radix)
   local r = "not a valid radix: "
   
   if not ok then
      return false, r .. reason
   elseif radix < 2 or radix > 36 then
      return false, r .. "outside allowable range"
   end
   
   return true
end

function isvalidstringnumber(str, radix)
   local pattern
   local highest = radix - 1
   
   if radix <= 10 then
      pattern = '^[-+]?[0-' .. highest .. ']+$'
   else
      pattern = '^[-+]?[0-9A-' .. stringchar(highest + 55) .. 'a-' .. stringchar(highest + 87) .. ']+$'
   end
   
   if stringmatch(str, pattern) then
      return true
   end
   
   return false, "not a valid string number: contains non-digit character"
end

function isvalidoperablevalue(value)
   if isvalidinteger(value) or isvalidbytearray(value) or isvalidbiginteger(value) then
      return true
   end
   
   return false, "not a valid operable value: it's a " .. type(value)
end

function arebothvalidoperablevalues(thisvalue, thatvalue, operation)
   if isvalidoperablevalue(thisvalue) and isvalidoperablevalue(thatvalue) then
      return true
   end
   
   return false, "attempt to perform " .. operation .. " on " .. gettype(thisvalue) .. " and " .. gettype(thatvalue)
end

function arevalidbigintegerandoperablevalue(bigint, value, operation)
   local ok, reason = isvalidbiginteger(bigint)
   
   if not ok then
      return false, reason
   end
   
   if not isvalidoperablevalue(thatvalue) then
      return false, "attempt to perform " .. operation .. " on biginteger and " .. gettype(value)
   end
   
   return true
end


--[[ Helper Bitwise Functions ]]
function make32bitinteger(number)
   -- bitand(number, 0xffffffff)
   return number % 0x100000000
end

function long32bitrightshift(number)
   local x = number / 0x100000000
   return x - (x % 1)
end

function long16bitrightshift(number)
   local x = number / 0x10000
   return x - (x % 1)
end

function long32bitleftshift(number)
   return number * 0x100000000
end

function long16bitleftshift(number)
   return number * 0x10000
end

function isnegative32bitinteger(number)
   return number >= negativemask
end

function getsignint(number)
   return isnegative32bitinteger(number) and 0xffffffff or 0
end


--[[ Helper Integer and Long Functions ]]
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
--[[
   Speed boost for Lua 5.3 using bitwise operators instead of function calls:
   bitand -> &, bitor  -> |, bitnot -> ~, etc. Unfortunately, those sigils are
   incompatible with Lua 5.2. The alternative is to use strings and the `load`
   function. For example:
   
      function somearbitraryoperation(a, b, c)
         return bitand(a, bitleftshift(bitnot(b), bitor(c, 3)))
      end
   
   becomes
   
      load("function somearbitraryoperation(a, b, c) \
         return a & (~b << (c | 3)) \
      end")()
   
   or
   
      somearbitraryoperation = load("return function(a, b, c) \
         return a & (~b << (c | 3)) \
      end")()
   
   The string keeps the 5.2 interpreter from erroring and the `load` allows the
   5.3 interpreter to understand and compile it. Because the `load` function
   returns an executable chunk without executing it you need to call it
   afterward. Also, quotes don't carry across newlines so I escaped the newlines
   with the backslashes. Also also, I prefer the first option because it
   produces a named chunk and not an anonymous chunk assigned to a variable.
   
   
   The entire function needs to be wrapped in the load string. Simply doing
   
      function somearbitraryoperation(a, b, c)
         return load("return function(a, b) return a & b end")()(a, load("return function(a, b) return a << b end")()(load("return function(b) return ~b end")()(b), load("return function(c, d) return c | d end")()(c, 3)))
      end
   
   will cause massive functional and loading overhead for each call.
   
   
   Also, redefining `bitand`, `bitor`, and the other functions with `load` like
   
      bitand = load("return function(a, b) return a & b end")()
      bitor = load("return function(a, b) return a | b end")()
      bitor = load("return function(a) return ~a end")()
   
   will, again, cause functional overhead slowdowns.
--]]

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

function divide64bitsby32bits(ah, al, b)
-- This function wouldn't hurt from a 5.3 speed boost either (especially since 5.3 supports 64-bit integers anyway)
   local ahhl = ah * 0x10000 + floor(al / 0x10000)
   local q1 = floor(ahhl / b)
   local r1 = ahhl % b
   local r1al = r1 * 0x10000 + (al % 0x10000)
   local q2 = floor(r1al / b)
   local r2 = r1al % b
   local ql = ((q1 % 0x10000) * 0x10000) + (q2 % 0x100000000)
   local qh = floor(q1 / 0x10000) + floor(q2 / 0x100000000)
   if ql >= 0x100000000 then
      qh = qh + 1
      ql = ql - 0x100000000
   end
   return qh, ql, r2
end

function splitlongtobytesandbits(number)
   return floor(number / 32), bitand(number, 0x1f)
end


--[[ Array Functions ]]
function copyarray(source)
   local destination = {}
   
   for i = 1, #source do
      destination[i] = source[i]
   end
   
   return destination
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

function swaparrays(thisarray, thatarray)
   for i = 1, max(#thisarray, #thatarray) do
      thisarray[i], thatarray[i] = thatarray[i], thisarray[i]
   end
end

function allocatearray(length)
   local array = {}
   
   for i = 1, length do
      array[i] = 0
   end
   
   return array
end

function splitmagnitudeintoblocks(mag, blocklength)
   local maglength, numberofblocks
   local blocks, index
   
   maglength = #mag
   numberofblocks = ceil(maglength / blocklength)
   blocks = {}
   for i = 1, numberofblocks do
      blocks[i] = {}
   end
   
   index = maglength
   
   -- copy the full blocks into the block array
   for block = numberofblocks, 2, -1 do
      for blockindex = blocklength, 1, -1 do
         blocks[block][blockindex], index = mag[index], index - 1
      end
   end
   
   --copy the most significant, possibly not full, block
   for blockindex = index, 1, -1 do
      blocks[1][blockindex], index = mag[index], index - 1
   end
   
   return blocks
end


--[[ Byte Array Functions ]]
function splitarrayatbytefromend(mag, pivot)
   -- Will split an array into two smaller arrays, upper and lower such that
   --  * upper will contain all elements from 1 to #mag - pivot
   --  * lower will contain all elements from (#mag - pivot + 1) to #mag
   --
   -- `pivot` indexes from end of magnitude (0 is last element)
   --     (in other words, lower will contain `pivot` elements)
   -- It will always return two new arrays, even if the array isn't split
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
   
   for i = 1, upperlength do
      upper[i] = mag[i]
   end
   
   for i = upperlength + 1, maglength do
      lower[i - upperlength] = mag[i]
   end
   
   return upper, lower
end

function gettoomcookslices(mag, fullsize)
   -- fullsize is used when multiplying two magnitudes of different sizes
   local lowersize, middlesize, uppersize, size, maglength, offset
   local lowerslice, middleslice, upperslice
   
   maglength = #mag
   size = floor((fullsize + 2) / 3)
   lowersize = min(size, maglength)
   middlesize = min(size, maglength - lowersize)
   uppersize = min(size, maglength - lowersize - middlesize)
   
   lowerslice = {}
   middleslice = {}
   upperslice = {}
   
   for i = 0, lowersize - 1 do
      lowerslice[lowersize - i] = mag[maglength - i]
   end
   
   for i = 0, middlesize - 1 do
      middleslice[middlesize - i] = mag[maglength - lowersize - i]
   end
   
   for i = 0, uppersize - 1 do
      upperslice[uppersize - i] = mag[maglength - lowersize - middlesize - i]
   end
   
   return destructivestripleadingzeros(upperslice),
          destructivestripleadingzeros(middleslice),
          destructivestripleadingzeros(lowerslice), size * 32
end


function signextendbytearrayto(source, destination, newlength)
   local length = #source
   local signbytes = newlength - length
   local signint = length > 0 and getsignint(source[1])
   
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
   --[[
      This function is correct, even though it seems it should do something with
      `addend` after the loop. The only number that would cause an overflow when
      added to 1 is 0b1111111111111111 (-1). The bitnot of that is 0. Thus the
      only number that would cause `addend` to still be 1 after the loop is 0,
      and the negation of 0 is 0.
   --]]
   local length = #source
   local addend = 1
   
   for i = length, 1, -1 do
      addend, destination[i] = splitlong(bitnot(source[i]) + addend)
   end
   
   destructivestripleadingzeros(destination)
   
   return destination
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


function convertsignmagnitudetobytearrayto(sign, source, destination)
   if sign == -1 then
      negatebytearrayto(source, destination)
      if getbytearraysign(destination) == 1 then
         tableinsert(destination, 1, 0xffffffff)
      end
   else
      clearandcopyintoarray(destination, source)
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


--[[ Private Getter functions ]]
function gettype(thing)
   return (isvalidinteger(thing) and 'integer') or
          (isvalidbiginteger(thing) and 'biginteger') or
          (isvalidbytearray(thing) and 'byte-array') or
          type(thing)
end

function getcharacternumericalvalue(character)
   local bytevalue = stringbyte(character)
   
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
   if isnegative32bitinteger(array[1]) then
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
      
      if not isnegative32bitinteger(mag[1]) then
         tableinsert(mag, 1, 0xffffffff)
      end
   elseif sign == 1 then
      if isnegative32bitinteger(mag[1]) then
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
   signint = getsignint(bytearray[1])
   
   if bytearray[1] == signint then
      for i = 1, balen - 1 do
         if bytearray[i] == signint and bytearray[i + 1] ~= signint then
            if signint == 0 then
               if isnegative32bitinteger(bytearray[i + 1]) then
                  removals = i - 1
               else
                  removals = i
               end
            else
               if isnegative32bitinteger(bytearray[i + 1]) then
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


function gethighestsetbit(array)
   -- Will return the little-endian index of the highest set bit,
   -- or -1 if array is equal to zero
   local arraylength = #array
   local highest
   local number, mask, index
   
   for byte = arraylength - 1, 0, -1 do
      for bit = 31, 0, -1 do
         number = array[arraylength - byte]
         mask = bitleftshift(1, bit)
         index = byte * 32 + bit
         if bitand(number, mask) ~= 0 then
            return index
         end
      end
   end
   
   return -1
end

function getlowestsetbit(array)
   -- Will return the little-endian index of the lowset set bit,
   -- or -1 if array is equal to zero
   local arraylength = #array
   local number, mask, index
   
   for byte = 0, arraylength - 1 do
      for bit = 0, 31 do
         number = array[arraylength - byte]
         mask = bitleftshift(1, bit)
         index = byte * 32 + bit
         if bitand(number, mask) ~= 0 then
            return index
         end
      end
   end
   
   return -1
end

function getleadingzeros(int)
   -- Returns the number of leading zeros in the 32-bit integer.
   -- Uses Hacker's Delight method used by Java Integer
   local n = 1
   
   if int == 0 then
      return 32
   end
   
   if bitrightshift(int, 16) == 0 then
      n = n + 16
      int = bitleftshift(int, 16)
   end
   
   if bitrightshift(int, 24) == 0 then
      n = n + 8
      int = bitleftshift(int, 8)
   end
   
   if bitrightshift(int, 28) == 0 then
      n = n + 4
      int = bitleftshift(int, 4)
   end
   
   if bitrightshift(int, 30) == 0 then
      n = n + 2
      int = bitleftshift(int, 2)
   end
   
   return n - bitrightshift(int, 31)
end

function getleadingzeroslong(long)
   local high, low
   local leadingzeros
   
   high, low = splitlong(long)
   leadingzeros = getleadingzeros(high)
   
   if leadingzeros == 32 then
      leadingzeros = leadingzeros + getleadingzeros(low)
   end
   
   return leadingzeros
end


--[[ Byte-Array Mappers ]]
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


--[[ Constructors ]]
function createbiginteger(sign, mag)
   return {sign = sign, magnitude = mag}
end

function constructorinteger(int)
   assert(isvalidinteger(int))
   
   return createbiginteger(getnumbersignandmagnitude(int))
end

function constructorsignmagnitudetrusted(sign, mag)
   assert(isvalidsign(sign))
   assert(isvalidmagnitude(mag))
   assert(isvalidsignmagnitudecombination(sign, mag))
   
   return createbiginteger(sign, mag)
end

function constructorsignmagnitude(sign, mag)
   assert(isvalidbytearray(mag))
   
   return constructorsignmagnitudetrusted(sign, copyandstripleadingzeros(mag))
end

function constructorbitsrng(bitlength, randomnumbergenerator)
   local mag = {}
   local numberofwords, excessbytes
   
   assert(bitlength >= 0 and bitlength % 1 == 0, "bit length not valid: must be a non-negative integer")
   assert(type(randomnumbergenerator()) == "number", "RNG function not valid: must return a number in the range [0, 1)")
   
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
   
   assert(isvalidbytearray(array))
   
   sign = getbytearraysign(array)
   
   if sign == -1 then
      destructivenegatebytearray(array)
   end
   
   return constructorsignmagnitudetrusted(sign, array)
end

function constructorbytearray(array)
   return constructorbytearraytrusted(getbytearray(array))
end

function constructorstringradix(str, radix)
   local mag
   local strlength = #str
   local sign, strsign, numberofdigits, digitsperintegerradix
   local numberofbits, numberofwords
   local firstgrouplength, superradix, group, groupvalue, cursor, ncursor
   
   -- Some edits and changes occurred here
   assert(isvalidradix(radix))
   assert(isvalidstringnumber(str, radix))
   
   strsign = stringmatch(str, '^[-+]')
   
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
   
   assert(numberofbits + 31 <= 0xffffffff, "biginteger would overflow supported range")
   
   numberofwords = bitrightshift(numberofbits + 31, 5)
   mag = allocatearray(numberofwords)
   
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
   
   mag[numberofwords] = groupvalue
   
   -- Process remaining groups
   superradix = intradix[radix]
   while cursor <= strlength do
      ncursor = cursor + digitsperintegerradix
      group = stringsub(str, cursor, ncursor - 1)
      cursor = ncursor
      groupvalue = tonumber(group, radix)
      
      destructivemultiplyandadd(mag, superradix, groupvalue)
   end
   
   destructivestripleadingzeros(mag)
   
   return constructorsignmagnitudetrusted(sign, mag)
end

function clone(bigint)
   assert(isvalidbiginteger(bigint))
   
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
   elseif typea == 'biginteger' and typeb == 'nil' then
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


--[[ Comparison Functions ]]
function comparemagnitudes(thismag, thatmag)
   local thislength = #thismag
   local thatlength = #thatmag
   
   if thislength ~= thatlength then
      -- If the magnitudes are different sizes, then they cannot be equal
      -- The function assumes magnitudes, so leading zeros aren't allowed
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
   
   assert(arebothvalidoperablevalues(thisvalue, thatvalue, "comparison"))
   
   thissign, thismag = getsignandmagnitude(thisvalue)
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thissign ~= thatsign then
      -- If the signs differ, then they cannot be equal
      return thissign > thatsign and 1 or -1
   end
   
   return comparemagnitudes(thismag, thatmag)
end

function equalmagnitudes(thismag, thatmag)
   return comparemagnitudes(thismag, thatmag) == 0
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


--[[ Bitwise functions ]]
function bitwisenot(value)
   assert(isvalidoperablevalue(value))
   
   return constructorbytearraytrusted(destructivemapbytearray(getbytearray(value), bitnot))
end

function mutablebitwisenot(bigint)
   local sign, bytearray, _
   assert(isvalidbiginteger(bigint))
   
   destructiveconvertsignmagnitudetobytearray(bigint.sign, bigint.magnitude)
   destructivemapbytearray(bigint.magnitude, bitnot)
   
   bigint.sign, _ = destructiveconvertbytearraytosignmagnitude(bigint.magnitude)
   
   return bigint
end


function binarybitwise(thisvalue, thatvalue, bitwisefunction, opname)
   assert(arebothvalidoperablevalues(thisvalue, thatvalue, "bitwise " .. opname))
   
   return constructorbytearraytrusted(destructivemergebytearrays(getbytearray(thisvalue),
                                                                 getbytearray(thatvalue),
                                                                 bitwisefunction))
end

function mutablebinarybitwise(thisbigint, thatvalue, bitwisefunction, opname)
   local thatbytearray, _
   
   assert(arevalidbigintegerandoperablevalue(thisbigint, thatvalue, "bitwise " .. opname))
   
   thatbytearray = getbytearray(thatvalue)
   
   destructiveconvertsignmagnitudetobytearray(thisbigint.sign, thisbigint.magnitude)
   destructivemergebytearrays(thisbigint.magnitude, thatbytearray, bitwisefunction)
   
   thisbigint.sign, _ = destructiveconvertbytearraytosignmagnitude(thisbigint.magnitude)
   
   return thisbigint
end


function bitwiseand(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitand, "and")
end

function mutablebitwiseand(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitand, "and")
end


function bitwiseandnot(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitandnot, "and-not")
end

function mutablebitwiseandnot(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitandnot, "and-not")
end


function bitwiseor(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitor, "or")
end

function mutablebitwiseor(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitor, "or")
end


function bitwisexor(thisvalue, thatbigint)
   return binarybitwise(thisvalue, thatvalue, bitxor, "xor")
end

function mutablebitwisexor(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitxor, "xor")
end


function destructiveleftshift(mag, displacement)
   local maglength
   local numberofbits, numberofbytes
   local shiftmultiplier, carry
   
   if displacement == 0 then
      return mag
   end
   
   maglength = #mag
   
   numberofbytes, numberofbits = splitlongtobytesandbits(displacement)
   
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
   numberofbytes, numberofbits = splitlongtobytesandbits(displacement)
   
   if numberofbytes >= maglength then
      -- when right-shifting more bits than there are in the array, the result
      -- is -1 for negative values and 0 for non-negative values
      cleararray(mag)
      
      return mag
   end
   
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
   
   destructivestripleadingzeros(mag)
   
   return mag
end

function copyandleftshift(mag, displacement)
   return destructiveleftshift(copyarray(mag), displacement)
end

function copyandrightshift(mag, displacement)
   return destructiverightshift(copyarray(mag), displacement)
end


function destructivebitwiseshift(mag, displacement, right)
   if displacement < 0 then
      displacement = -displacement
      right = not right
   end
   
   if right then
      destructiverightshift(mag, displacement)
   else
      destructiveleftshift(mag, displacement)
   end
   
   return mag
end

function bitwiseshift(value, displacement, right)
   local sign, mag
   
   assert(isvalidoperablevalue(value))
   assert(isvalidabsolute32bitinteger(displacement))
   
   sign, mag = getsignandmagnitude(value)
   destructivebitwiseshift(mag, displacement, right)
   
   if #mag == 0 then
      if sign == -1 then
         mag[1] = 0x01
      else
         sign = 0
      end
   end
   
   return constructorsignmagnitudetrusted(sign, mag)
end

function mutablebitwiseshift(bigint, displacement, right)
   assert(isvalidbiginteger(bigint))
   assert(isvalidabsolute32bitinteger(displacement))
   
   destructivebitwiseshift(bigint.magnitude, displacement, right)
   
   if #bigint.magnitude == 0 then
      if bigint.sign == -1 then
         bigint.magnitude[1] = 0x01
      else
         bigint.sign = 0
      end
   end
   
   return bigint
end


function bitwiseleftshift(value, displacement)
   return bitwiseshift(value, displacement, false)
end

function mutablebitwiseleftshift(bigint, displacement)
   return mutablebitwiseshift(bigint, displacement, false)
end


function bitwiserightshift(value, displacement)
   return bitwiseshift(value, displacement, true)
end

function mutablebitwiserightshift(bigint, displacement)
   return mutablebitwiseshift(bigint, displacement, true)
end


function destructivebitwiseatbit(bytearray, bitfromend, bitwisefunction)
   local byte, bit, length
   
   byte, bit = splitlongtobytesandbits(bitfromend)
   
   length = max(#bytearray, byte + 1)
   
   destructivesignextendbytearray(bytearray, length)
   bytearray[length - byte] = bitwisefunction(bytearray[length - byte], bitleftshift(1, bit))
   
   return bytearray
end

function bitwiseatbit(value, bitfromend, bitwisefunction)
   local bytearray
   
   assert(isvalidoperablevalue(value))
   assert(isvalidinteger(bitfromend))
   assert(bitfromend >= 0, "not valid integer: negative")
   
   bytearray = getbytearray(value)
   destructivebitwiseatbit(bytearray, bitfromend, bitwisefunction)
   
   return constructorbytearraytrusted(bytearray)
end

function mutablebitwiseatbit(bigint, bitfromend, bitwisefunction)
   assert(isvalidbiginteger(bigint))
   assert(isvalidinteger(bitfromend))
   assert(bitfromend >= 0, "not valid integer: negative")
   
   destructiveconvertsignmagnitudetobytearray(bigint.sign, bigint.magnitude)
   destructivebitwiseatbit(bigint.magnitude, bitfromend, bitwisefunction)
   destructiveconvertbytearraytosignmagnitude(bigint.magnitude)
   
   return bigint
end


function clearbit(value, bitfromend)
   return bitwiseatbit(value, bitfromend, bitandnot)
end

function mutableclearbit(bigint, bitfromend)
   return mutablebitwiseatbit(bigint, bitfromend, bitandnot)
end

function setbit(value, bitfromend)
   return bitwiseatbit(value, bitfromend, bitor)
end

function mutablesetbit(bigint, bitfromend)
   return mutablebitwiseatbit(bigint, bitfromend, bitor)
end

function flipbit(value, bitfromend)
   return bitwiseatbit(value, bitfromend, bitxor)
end

function mutableflipbit(bigint, bitfromend)
   return mutablebitwiseatbit(bigint, bitfromend, bitxor)
end


function testbit(value, bitfromend)
   local bytearray, length
   local byte, bit
   
   assert(isvalidoperablevalue(value))
   assert(isvalidinteger(bitfromend))
   assert(bitfromend >= 0, "not valid integer: negative")
   
   byte, bit = splitlongtobytesandbits(bitfromend)
   bytearray = getbytearray(value)
   length = #bytearray
   
   if byte >= length then
      return getbytearraysign(bytearray) == -1
   end
   
   return bitand(bytearray[length - byte], bitleftshift(1, bit)) ~= 0
end


--[[ Private Magnitude Functions ]]
function destructiveaddmagnitudes(thismag, thatmag)
   local thislength, thatlength, longerlength
   local carry
   
   thislength = #thismag
   thatlength = #thatmag
   
   longerlength = max(thislength, thatlength)
   carry = 0
   
   for i = 0, longerlength - 1 do
      carry, thismag[longerlength - i] = splitlong((thismag[thislength - i] or 0) +
                                                   (thatmag[thatlength - i] or 0) +
                                                   carry)
   end
   
   if carry ~= 0 then
      -- If the carry amount exceeds the size of both magnitudes, then insert
      -- the value of the carry in front of everything.
      tableinsert(thismag, 1, carry)
   end
   
   destructivestripleadingzeros(thismag)
   
   return thismag
end

function copyandaddmagnitudes(thismag, thatmag)
   return destructiveaddmagnitudes(copyarray(thismag), thatmag)
end

function destructivesubtractmagnitudes(minuend, subtrahend)
   -- Will calculate the absolute difference between the magnitudes
   -- Will destructively write value into minuend
   local borrow, difference
   local larger, largerlen, smaller
   
   if comparemagnitudes(minuend, subtrahend) < 0 then
      -- minuend < subtrahend
      smaller = copyarray(minuend)
      larger = subtrahend
   else
      -- minuend >= subtrahend
      smaller = subtrahend
      larger = minuend
   end
   
   largerlen = #larger
   
   borrow = 0
   difference = 0
   
   for i = 0, largerlen - 1 do
      difference = getbytefromend(larger, i) -
                   getbytefromend(smaller, i) -
                   borrow
      
      if difference < 0 then
         borrow = 1
      else
         borrow = 0
      end
      
      minuend[largerlen - i] = make32bitinteger(difference)
   end
   
   destructivestripleadingzeros(minuend)
   
   return minuend
end

function copyandsubtractmagnitudes(minuend, subtrahend)
   return destructivesubtractmagnitudes(copyarray(minuend), subtrahend)
end


--[[ Public Math Functions ]]
-- Negation
function negate(bigint)
   assert(isvalidbiginteger(bigint))
   
   return constructorsignmagnitudetrusted(-bigint.sign, copyarray(bigint))
end

function mutablenegate(bigint)
   assert(isvalidbiginteger(bigint))
   
   bigint.sign = -bigint.sign
   
   return bigint
end


-- Absolution
function absolutevalue(bigint)
   assert(isvalidbiginteger(bigint))
   
   return bigint.sign < 0 and negate(bigint) or bigint
end

function mutableabsolutevalue(bigint)
   assert(isvalidbiginteger(bigint))
   
   if bigint.sign == -1 then
      bigint.sign = 1
   end
   
   return bigint
end


-- Addition
function add(thisvalue, thatvalue)
   local sign, mag
   local thissign, thismag
   local thatsign, thatmag
   local comparison
   
   assert(arebothvalidoperablevalues(thisvalue, thatvalue, "addition"))
   
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
   
   if #mag == 0 then
      sign = 0
   end
   
   return constructorsignmagnitudetrusted(sign, mag)
end

function mutableadd(thisbigint, thatvalue)
   local thatsign, thatmag
   
   assert(arevalidbigintegerandoperablevalue(thisbigint, thatvalue, "addition"))
   
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thisbigint.sign == 0 then
      if thatsign ~= 0 then
         thisbigint.sign = thatsign
         clearandcopyintoarray(thisbigint.magnitude, thatmag)
      end
      return thisbigint
   elseif thatsign == 0 then
      return thisbigint
   end
   
   if thisbigint.sign == thatsign then
      destructiveaddmagnitudes(thisbigint.magnitude, thatmag)
   else
      comparison = comparemagnitudes(thisbigint.magnitude, thatmag)
      if comparison == 1 then
         destructivesubtractmagnitudes(thisbigint.magnitude, thatmag)
      elseif comparison == -1 then
         thisbigint.sign = -thisbigint.sign
         swaparrays(thisbigint.magnitude, thatmag)
         destructivesubtractmagnitudes(thisbigint.magnitude, thatmag)
      else
         thisbigint.sign = 0
         cleararray(thisbigint.magnitude)
      end
   end
   
   if #thisbigint.magnitude == 0 then
      thisbigint.sign = 0
   end
   
   return thisbigint
end


-- Subtraction
function subtract(thisvalue, thatvalue)
   local sign, mag
   local thissign, thatsign
   local thismag, thatmag
   local comparison
   
   assert(arebothvalidoperablevalues(thisvalue, thatvalue, "subtraction"))
   
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
         sign = -thissign
         mag = destructivesubtractmagnitudes(thatmag, thismag)
      else
         return constructorinteger(0)
      end
   end
   
   if #mag == 0 then
      sign = 0
   end
   
   return constructorsignmagnitudetrusted(sign, mag)
end

function mutablesubtract(thisbigint, thatvalue)
   local thatsign, thatmag
   
   assert(arevalidbigintegerandoperablevalue(thisbigint, thatvalue, "subtraction"))
   
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thisbigint.sign == 0 then
      if thatsign ~= 0 then
         thisbigint.sign = -thatsign
         clearandcopyintoarray(thisbigint.magnitude, thatmag)
      end
      return thisbigint
   elseif thatsign == 0 then
      return thisbigint
   end
   
   if thisbigint.sign ~= thatsign then
      destructiveaddmagnitudes(thisbigint.magnitude, thatmag)
   else
      comparison = comparemagnitudes(thisbigint.magnitude, thatmag)
      if comparison == 1 then
         destructivesubtractmagnitudes(thisbigint.magnitude, thatmag)
      elseif comparison == -1 then
         thisbigint.sign = -thisbigint.sign
         swaparrays(thisbigint.magnitude, thatmag)
         destructivesubtractmagnitudes(thisbigint.magnitude, thatmag)
      else
         thisbigint.sign = 0
         cleararray(thisbigint.magnitude)
      end
   end
   
   if #thisbigint.magnitude == 0 then
      thisbigint.sign = 0
   end
   
   return thisbigint
end


-- Squarition
function squarecolinplumb(mag)
--[[
               a  b  c  d  e
            *  a  b  c  d  e
            ==================
               ae be ce de EE
            ad bd cd DD de
         ac bc CC cd ce
      ab BB bc bd be
   AA ab ac ad ae
   
   There is the diagonal:
                           EE
                     DD
               CC
         BB
   AA
   
   And two triangles of the same set of products
               ae be ce de
            ad bd cd
         ac bc
      ab                de
                  cd ce
            bc bd be
      ab ac ad ae
   
   So diagonal + 2 * triangles
--]]
   local maglength
   local resultlengh, index
   local diagonal, triangle
   local carry, piece
   local producthigh, productlow, extraint
   
   maglength = #mag
   resultlength = maglength * 2
   
   diagonal = allocatearray(resultlength)
   
   for i = 0, maglength - 1 do
      -- Multiply all squares on the diagonal and put them into diagonal
      piece = mag[#mag - i]
      index = resultlength - i - i
      diagonal[index - 1], diagonal[index] = integermultiplyandaddtosplitlong(piece, piece, 0)
   end
   
   triangle = allocatearray(resultlength)
   
   for i = 1, maglength - 1 do
      for j = 0, i - 1 do
         index = resultlength - i - j
         producthigh, productlow = integermultiplyandaddtosplitlong(mag[#mag - j],
                                                                    mag[#mag - i],
                                                                    0)
         
         -- Add productlow to the corresponding triangle byte and continue the
         -- carry up to extraint
         carry, triangle[index] = splitlong(triangle[index] + productlow * 2)
         extraint, producthigh = splitlong(producthigh * 2 + carry)
         
         -- Add producthigh to the next corresponding triangle byte and continue
         -- the carry to extraint
         index = index - 1
         carry, triangle[index] = splitlong(triangle[index] + producthigh)
         --extraint = extraint + carry
         --carry = extraint
         carry = extraint + carry
         
         -- propagate carry (extraint) through the resulting triangle array
         while carry ~= 0 do
            index = index - 1
            carry, triangle[index] = splitlong(triangle[index] + carry)
         end
      end
   end
   
   destructiveaddmagnitudes(triangle, diagonal)
   destructivestripleadingzeros(triangle)
   
   return triangle
end

function squarekaratsuba(mag)
--[[
   let B be the arbitrary base and Xx be the number we're squaring where
      Xx = X*B + x
   
   Xx = X*B + x, so
   Xx * Xx = (X*B + x)(X*B + x)
           = X*X*B*B + X*B*x + x*X*B + x*x
           = X^2*B^2 + 2*X*B*x + x^2
           = ((X^2)*B + 2*X*x)*B + x^2
   
   Since in this case B is a power of 2, multiplying by B is a leftshift
--]]
   local halfway, shiftup
   local upper, lower
   local uppersquared, lowersquared, innersquared
   local result
   
   halfway = floor((#mag + 1) / 2)
   shiftup = halfway * 32
   
   upper, lower = splitarrayatbytefromend(mag, halfway)
   
   uppersquared = squaremagnitude(upper)
   lowersquared = squaremagnitude(lower)
   innersquared = destructiveleftshift(multiplymagnitudes(upper, lower), 1)
   
   destructiveleftshift(uppersquared, shiftup)
   destructiveaddmagnitudes(uppersquared, innersquared)
   destructiveleftshift(uppersquared, shiftup)
   destructiveaddmagnitudes(uppersquared, lowersquared)
   
   return uppersquared
end

function destructiveexactdividebythree(mag)
   local maglength
   local borrow, x, w, _, productlow
   
   maglength = #mag
   
   borrow = 0
   
   for i = 0, maglength - 1 do
      x = mag[maglength - i]
      w = x - borrow
      
      if x < borrow then
         borrow = 1
      else
         borrow = 0
      end
      
      _, productlow = integermultiplyandaddtosplitlong(w, 0xaaaaaaab, 0)
      mag[maglength - i] = productlow
      
      if productlow >= 0xaaaaaaab then
         borrow = borrow + 2
      elseif productlow >= 0x55555556 then
         borrow = borrow + 1
      end
   end
   
   destructivestripleadingzeros(mag)
   
   return mag
end

function squaretoomcook(mag)
   local a2, a1, a0, ss
   local v0, v1, v2, vm1, vinf, t1, t2, tm1, da1
   
   a2, a1, a0, ss = gettoomcookslices(mag, #mag)
   
   
   -- v0 = a0.square();
   v0 = squaremagnitude(a0)
   
   -- da1 = a2.add(a0);
   da1 = copyandaddmagnitudes(a2, a0)
   
   -- vm1 = da1.subtract(a1).square(); square produces copy
   vm1 = squaremagnitude(copyandsubtractmagnitudes(da1, a1))
   
   -- da1 = da1.add(a1); mutable, last instance of a1
   destructiveaddmagnitudes(da1, a1)
   
   -- v1 = da1.square(); square makes copy
   v1 = squaremagnitude(da1)
   
   -- vinf = a2.square(); square makes copy
   vinf = squaremagnitude(a2)
   
   -- v2 = da1.add(a2).shiftLeft(1).subtract(a0).square(); last instance of da1, mutate; square makes copy
   destructiveaddmagnitudes(da1, a2)
   destructiveleftshift(da1, 1)
   destructivesubtractmagnitudes(da1, a0)
   v2 = squaremagnitude(da1)
   
   
   
   -- t2 = v2.subtract(vm1).exactDivideBy3(); last instance of v2, so t2 = v2
   destructivesubtractmagnitudes(v2, vm1)
   destructiveexactdividebythree(v2)
   t2 = v2
   
   -- tm1 = v1.subtract(vm1).shiftRight(1);
   tm1 = copyandsubtractmagnitudes(v1, vm1)
   destructiverightshift(tm1, 1)
   
   -- t1 = v1.subtract(v0); last instance of v1, so t1 = v1
   destructivesubtractmagnitudes(v1, v0)
   t1 = v1
   
   -- t2 = t2.subtract(t1).shiftRight(1); mutable
   destructivesubtractmagnitudes(t2, t1)
   destructiverightshift(t2, 1)
   
   -- t1 = t1.subtract(tm1).subtract(vinf); mutable
   destructivesubtractmagnitudes(t1, tm1)
   destructivesubtractmagnitudes(t1, vinf)
   
   -- t2 = t2.subtract(vinf.shiftLeft(1)); mutable
   destructivesubtractmagnitudes(t2, copyandleftshift(vinf, 1))
   
   -- tm1 = tm1.subtract(t2); mutable
   destructivesubtractmagnitudes(tm1, t2)
   
   
   --return vinf.shiftLeft(ss).add(t2).shiftLeft(ss).add(t1).shiftLeft(ss).add(tm1).shiftLeft(ss).add(v0);
   destructiveleftshift(vinf, ss)
   destructiveaddmagnitudes(vinf, t2)
   destructiveleftshift(vinf, ss)
   destructiveaddmagnitudes(vinf, t1)
   destructiveleftshift(vinf, ss)
   destructiveaddmagnitudes(vinf, tm1)
   destructiveleftshift(vinf, ss)
   destructiveaddmagnitudes(vinf, v0)
   
   return vinf
end

function squaremagnitude(mag)
   if #mag >= toomcooksquarethreshold then
      return squaretoomcook(mag)
   elseif #mag >= karatsubasquarethreshold then
      return squarekaratsuba(mag)
   end
   return squarecolinplumb(mag)
end

function square(value)
   local sign, mag
   
   assert(isvalidoperablevalue(value))
   
   sign, mag = getsignandmagnitude(value)
   
   if sign == 0 then
      return value
   end
   
   return constructorsignmagnitude(1, squaremagnitude(mag))
end

function mutablesquare(bigint)
   local mag
   
   assert(isvalidbiginteger(bigint))
   
   if bigint.sign == 0 then
      return bigint
   end
   
   mag = squaremagnitude(bigint.magnitude)
   
   clearandcopyintoarray(bigint.magnitude, mag)
   bigint.sign = 1
   
   return bigint
end


-- Multiplication
function multiplycolinplumb(thismag, thatmag)
   local thislength, thatlength
   local resultlength, result
   local producthigh, productlow, carry
   local index
   
   thislength = #thismag
   thatlength = #thatmag
   resultlength = thislength + thatlength
   
   result = allocatearray(resultlength)
   
   for i = 0, thislength - 1 do
      for j = 0, thatlength - 1 do
         index = resultlength - i - j
         producthigh, productlow = integermultiplyandaddtosplitlong(getbytefromend(thismag, i),
                                                                    getbytefromend(thatmag, j),
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
   
   destructivestripleadingzeros(result)
   
   return result
end

function multiplykaratsuba(thismag, thatmag)
   local halfway, shiftup
   local thisupper, thislower
   local thatupper, thatlower
   local uppers, lowers, inners
   local result
   
   halfway = floor((max(#thismag, #thatmag) + 1) / 2)
   shiftup = halfway * 32
   
   thisupper, thislower = splitarrayatbytefromend(thismag, halfway)
   thatupper, thatlower = splitarrayatbytefromend(thatmag, halfway)
   
   uppers = multiplymagnitudes(thisupper, thatupper)
   lowers = multiplymagnitudes(thislower, thatlower)
   inners = destructiveaddmagnitudes(multiplymagnitudes(thisupper, thatlower),
                                     multiplymagnitudes(thislower, thatupper))
   
   destructiveleftshift(uppers, shiftup)
   destructiveaddmagnitudes(uppers, inners)
   destructiveleftshift(uppers, shiftup)
   destructiveaddmagnitudes(uppers, lowers)
   
   return uppers
end

function multiplytoomcook(thismag, thatmag)
   local a2, a1, a0, b2, b1, b0, ss, _
   local v0, v1, v2, vm1, vinf, t1, t2, tm1, da1, db1
   local vm1sign
   -- This algorithm takes advantage of magnitude destruction to avoid making
   -- extra unnecessary arrays and biginteger objects. Only one number
   -- calculated has the potential to be negative (all others are non-negative),
   -- thus its sign is handled separately
   
   local longerlength = max(#thismag, #thatmag)
   
   -- All slices here are non-negative values
   a2, a1, a0, ss = gettoomcookslices(thismag, longerlength)
   b2, b1, b0, _  = gettoomcookslices(thatmag, longerlength)
   
   -- v0 = a0.multiply(b0);
   v0 = multiplymagnitudes(a0, b0)
   
   -- da1 = a2.add(a0);
   da1 = copyandaddmagnitudes(a2, a0)
   
   -- db1 = b2.add(b0);
   db1 = copyandaddmagnitudes(b2, b0)
   
   
   -- vm1 = da1.subtract(a1).multiply(db1.subtract(b1));
   vm1sign = comparemagnitudes(da1, a1) * comparemagnitudes(db1, b1)
   vm1 = multiplymagnitudes(copyandsubtractmagnitudes(da1, a1),
                            copyandsubtractmagnitudes(db1, b1))
   
   
   -- da1 = da1.add(a1);
   destructiveaddmagnitudes(da1, a1)
   
   -- db1 = db1.add(b1);
   destructiveaddmagnitudes(db1, b1)
   
   -- v1 = da1.multiply(db1);
   v1 = multiplymagnitudes(da1, db1)
   
   -- v2 = da1.add(a2).shiftLeft(1).subtract(a0).multiply(
   --      db1.add(b2).shiftLeft(1).subtract(b0)); last instances of da1 and db1, so mutate
   destructiveaddmagnitudes(da1, a2)
   destructiveleftshift(da1, 1)
   
   destructivesubtractmagnitudes(da1, a0)
   
   destructiveaddmagnitudes(db1, b2)
   destructiveleftshift(db1, 1)
   
   destructivesubtractmagnitudes(db1, b0)
   
   v2 = multiplymagnitudes(da1, db1)
   
   -- vinf = a2.multiply(b2);
   vinf = multiplymagnitudes(a2, b2)
   
   -- t2 = v2.subtract(vm1).exactDivideBy3(); last instance of v2, so t2 = v2
   if v2sign ~= vm1sign then
      destructiveaddmagnitudes(v2, vm1)
   else
      destructivesubtractmagnitudes(v2, vm1)
   end
   
   destructiveexactdividebythree(v2)
   t2 = v2
   
   -- tm1 = v1.subtract(vm1).shiftRight(1); last instance of vm1, so tm1 = vm1
   if vm1sign < 0 then
      destructiveaddmagnitudes(vm1, v1) -- v1 - -vm1 = v1 + vm1
   else
      -- this function returns the difference regardless of the order
      -- in this algorithm, tm1 will never be negative
      destructivesubtractmagnitudes(vm1, v1)
   end
   destructiverightshift(vm1, 1)
   tm1 = vm1
   
   -- t1 = v1.subtract(v0); last instance of v1, so t1 = v1
   destructivesubtractmagnitudes(v1, v0)
   t1 = v1
   
   -- t2 = t2.subtract(t1).shiftRight(1);
   destructivesubtractmagnitudes(t2, t1)
   destructiverightshift(t2, 1)
   
   -- t1 = t1.subtract(tm1).subtract(vinf);
   destructivesubtractmagnitudes(t1, tm1)
   destructivesubtractmagnitudes(t1, vinf)
   
   -- t2 = t2.subtract(vinf.shiftLeft(1));
   destructivesubtractmagnitudes(t2, copyandleftshift(vinf, 1))
   
   -- tm1 = tm1.subtract(t2);
   destructivesubtractmagnitudes(tm1, t2)
   
   -- return vinf.shiftLeft(ss).add(t2).shiftLeft(ss).add(t1).shiftLeft(ss).add(tm1).shiftLeft(ss).add(v0);
   destructiveleftshift(vinf, ss)
   destructiveaddmagnitudes(vinf, t2)
   destructiveleftshift(vinf, ss)
   destructiveaddmagnitudes(vinf, t1)
   destructiveleftshift(vinf, ss)
   destructiveaddmagnitudes(vinf, tm1)
   destructiveleftshift(vinf, ss)
   destructiveaddmagnitudes(vinf, v0)
   
   return vinf
end

function multiplymagnitudes(thismag, thatmag)
   local thismaglen, thatmaglen
   
   thismaglen = #thismag
   thatmaglen = #thatmag
   
   if min(thismaglen, thatmaglen) < karatsubamultiplythreshold then
      -- if either are less than the Karatsuba threshold then do
      -- Colin Plumb multiplication
      -- Note: multiplying a large number (suppose it has 8'675'309-bytes) by a
      -- small number (say at most 79-bytes) will use this method of muliplying
      return multiplycolinplumb(thismag, thatmag)
   elseif max(thismaglen, thatmaglen) > toomcookmultiplythreshold then
      -- if either are greater than the Toom Cook threshold then do
      -- Toom Cook multiplication
      -- Note: multiplying a large number (suppose it has 8'675'309 bytes) by a
      -- small number (say at least 80 bytes) will use this method of muliplying
      return multiplytoomcook(thismag, thatmag)
   end
   -- otherwise, do the Karatsuba multiplication
   -- done when both lengths are
   --  * greater than the Karatsuba threshold
   --  * less than the Toom Cook threshold
   return multiplykaratsuba(thismag, thatmag)
end

function multiply(thisvalue, thatvalue)
   local sign, mag
   local thissign, thismag
   local thatsign, thatmag
   
   assert(arebothvalidoperablevalues(thisvalue, thatvalue, "multiplication"))
   
   thissign, thismag = getsignandmagnitude(thisvalue)
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thissign == 0 then
      return thisvalue
   elseif thatsign == 0 then
      return thatvalue
   end
   
   if thissign ~= thatsign then
      sign = -1
   else
      sign = 1
   end
   
   if equalmagnitudes(thismag, thatmag) then
      -- If magnitudes are equal, regardless of sign, the magnitude is squared
      -- so use optimizations in the squaring code
      mag = squaremagnitude(thatmag)
   else
      mag = multiplymagnitudes(thismag, thatmag)
   end
   
   return constructorsignmagnitude(sign, mag)
end

function mutablemultiply(thisbigint, thatvalue)
   local mag
   local thatsign, thatmag
   
   assert(arevalidbigintegerandoperablevalue(thisbigint, thatvalue, "multiplication"))
   
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   if thisbigint.sign == 0 then
      return thisbigint
   elseif thatsign == 0 then
      thisbigint.sign = 0
      cleararray(thisbigint.magnitude)
      return thisbigint
   end
   
   if thisbigint.sign ~= thatsign then
      thisbigint.sign = -1
   else
      thisbigint.sign = 1
   end
   
   if equalmagnitudes(thisbigint.magnitude, thatmag) then
      mag = squaremagnitude(thisbigint.magnitude)
   else
      mag = multiplymagnitudes(thisbigint.magnitude, thatmag)
   end
   
   clearandcopyintoarray(thisbigint.magnitude, mag)
   
   return thisbigint
end


-- Exponentiation
function raisemagnitude(mag, exponent)
   local highest, lowest
   local highexponent, _
   local result, parttosquare
   
   highest = gethighestsetbit(mag)
   lowest = getlowestsetbit(mag)
   
   if highest == 0 then
      -- if highest == 0 then lowest == 0 and value == 1
      -- value is 1, and 1^e := 1
      return mag
   end
   
   --[[ Still in testing
   if highest == lowest then
      -- Otherwise the value is a power of 2 and can be easily exponentiated by
      -- left-shifting. 
      
      shifts = lowest * (exponent - 1)
      ok, reason = isvalidinteger(shifts)
      
      if not ok then
         error("value too large to be exponentiated")
      end
      
      destructiveleftshift(mag, shifts)
      
      if bitand(exponent, 1) == 0 then
         -- exponent is even
         sign = 1
      end
      
      return constructorsignmagnitude(sign, mag)
   end
   --]]
   
   parttosquare = mag
   result = {1}
   highexponent = gethighestsetbit({exponent})
   
   for bitfromend = 0, highexponent - 1 do
      if bitand(exponent, bitleftshift(1, bitfromend)) ~= 0 then
         result = multiplymagnitudes(result, parttosquare)
      end
      
      parttosquare = squaremagnitude(parttosquare)
   end
   
   -- executes when bitfromend == highexponent
   result = multiplymagnitudes(result, parttosquare)
   
   return result
end

function pow(value, exponent)
   local sign, mag
   local highest, lowest
   local result
   
   assert(isvalidoperablevalue(value))
   assert(isvalid32bitinteger(exponent))
   
   
   -- Test for special, easy math cases (e == 0, e == 1, x == 0, and x == 2^n)
   if exponent == 0 then
      -- x^0 := 1 for any real x (defines 0^0 := 1)
      return constructornumber(1)
   end
   
   if exponent == 1 then
      -- x^1 := x for any real x
      return value
   end
   
   sign, mag = getsignandmagnitude(value)
   
   if sign == 0 then
      -- 0^n == 0 for n is an integer and n > 0
      -- Note, 0^0 := 1, but if exponent == 0, it will return in the block above
      return 0
   end
   
   result = raisemagnitude(mag, exponent)
   
   if sign == -1 and exponent % 2 == 0 then
      -- negative number and an even sign is the only instance of sign-changing
      -- if sign == 1 then x^e > 0 always
      -- if sign == -1 then
      --    x^e > 0 if exponent is even
      --    x^e < 0 if exponent is odd
      sign = 1
   end
   
   return constructorsignmagnitude(sign, result)
end

function mutablepow(bigint, exponent)
   local highest, lowest
   local parttosquare, result
   
   assert(isvalidbiginteger(bigint))
   assert(isvalid32bitinteger(exponent))
   
   -- Test for special, easy math cases (e == 0, e == 1, x == 0, and x == 2^n)
   if exponent == 0 then
      -- x^0 := 1 for any real x (defines 0^0 := 1)
      sign = 1
      cleararray(bigint.magnitude)
      bigint.magnitude[1] = 1
      return bigint
   end
   
   if exponent == 1 then
      -- x^1 := x for any real x
      return bigint
   end
   
   if bigint.sign == 0 then
      -- 0^n == 0 for n is an integer and n > 0
      -- Note, 0^0 := 1, but if exponent == 0, it will return in the block above
      return bigint
   end
   
   result = raisemagnitude(bigint.magnitude, exponent)
   
   if bigint.sign == -1 and bitand(exponent, 1) == 0 then
      -- negative number and an even sign is the only instance of sign-changing
      -- if x > 0 then x^e > 0 always
      -- otherwise, if exponent is odd then x^e < 0
      -- otherwise x^e > 0 (exponent is even)
      bigint.sign = 1
   end
   
   clearandcopyintoarray(bigint.magnitude, result)
   
   return bigint
end


-- Division
function divideoneword(dividend, divisor)
   -- ensure dividend is magnitude and divisor is 32-bit integer
   -- returns quotient and remainder, both magnitudes
   local shift, qhat, qrem, _
   local quotient, remainder
   local dividendlength, dividendestimate
   
   shift = getleadingzeros(divisor)
   
   dividendlength = #dividend
   quotient = {}
   
   qrem = dividend[1]
   if qrem < divisor then
      quotient[1] = 0
   else
      quotient[1] = floor(qrem / divisor)
      qrem = qrem - (quotient[1] * divisor)
   end
   
   for i = 2, dividendlength do
      _, qhat, qrem = divide64bitsby32bits(qrem, dividend[i], divisor)
      
      quotient[i] = qhat
   end
   
   if shift > 0 then
      qrem = qrem % divisor
   end
   
   destructivestripleadingzeros(quotient)
   
   return quotient, qrem
end

function multiplythensubtract(remainder, div, qhat, offset)
   local carry, producthigh, productlow, signint
   local differencehigh, differencelow, _
   local divlength = #div
   
   carry = 0
   remainder[offset] = 0
   offset = offset + divlength
   
   for i = divlength, 1, -1 do
      signint = getsignint(remainder[offset])
      producthigh, productlow = integermultiplyandaddtosplitlong(div[i], qhat, carry)
      differencehigh, differencelow = splitlong(remainder[offset] + (bitnot(productlow) + 1))
      differencehigh = make32bitinteger(bitnot(producthigh) + differencehigh + signint)
      
      remainder[offset] = differencelow
      offset = offset - 1
      carry = producthigh + ((differencelow > bitnot(productlow)) and 1 or 0)
   end
   
   return carry
end

function divisoradd(divisor, remainder, offset)
   local carry = 0
   
   for i = #divisor, 1, -1 do
      carry, remainder[i + offset] = splitlong(divisor[i] + remainder[i + offset] + carry)
   end
end

function destructivedivideknuth(dividend, divisor)
   local shift, div
   local quotient, remainder
   local divisorlength, quotientlength
   local divhigh, divlow
   local qhat, qrem, nh, nh2, nm, nl, rs, temp, _
   local skipcorrection, estproducthigh, estproductlow, borrow
   
   divisorlength = #divisor
   
   shift = getleadingzeros(divisor[1])
   div = copyandleftshift(divisor, shift) -- if shift == 0, it returns a copy
   
   remainder = copyandleftshift(dividend, shift)
   
   quotientlength = #remainder - divisorlength + 1
   quotient = {}
   
   tableinsert(remainder, 1, 0)
   
   divhigh = div[1]
   divlow = div[2]
   
   for i = 1, quotientlength do
      qhat = 0
      qrem = 0
      skipcorrection = false
      
      nh = remainder[i]
      nh2 = bitxor(nh, negativemask)
      nm = remainder[i + 1]
      
      if nh == divhigh then
         qhat = 0xffffffff
         qrem = make32bitinteger(nh + nm)
         skipcorrection = bitxor(qrem, negativemask) < nh2
      else
         --[[
            long nChunk = (((long)nh) << 32) | (nm & LONG_MASK);
            if (nChunk >= 0) {
               qhat = (int) (nChunk / dhLong);
               qrem = (int) (nChunk - (qhat * dhLong));
            } else {
               long tmp = divWord(nChunk, dh);
               qhat = (int) (tmp & LONG_MASK);
               qrem = (int) (tmp >>> 32);
            }
         --]]
         _, qhat, qrem = divide64bitsby32bits(nh, nm, divhigh)
      end
      
      --[[
         if (qhat == 0)
            continue
         
         well, there's no continue in Lua
      --]]
      
      if qhat ~= 0 then
         --[[
            if (!skipCorrection) { // Correct qhat
               long nl = rem.value[j+2+rem.offset] & LONG_MASK;
               long rs = ((qrem & LONG_MASK) << 32) | nl;
               long estProduct = (dl & LONG_MASK) * (qhat & LONG_MASK);

               if (unsignedLongCompare(estProduct, rs)) {
                  qhat--;
                  qrem = (int)((qrem & LONG_MASK) + dhLong);
                  if ((qrem & LONG_MASK) >=  dhLong) {
                     estProduct -= (dl & LONG_MASK);
                     rs = ((qrem & LONG_MASK) << 32) | nl;
                     if (unsignedLongCompare(estProduct, rs))
                        qhat--;
                  }
               }
            }
         --]]
         
         if not skipcorrection then
            nl = remainder[i + 2]
            estproducthigh, estproductlow = integermultiplyandaddtosplitlong(divlow, qhat, 0)
            
            if estproducthigh > qrem or (estproducthigh == qrem and estproductlow > nl) then
               qhat = qhat - 1
               qrem = make32bitinteger(qrem + divhigh)
               
               if qrem >= divhigh then
                  if divlow > estproductlow then
                     estproducthigh = estproducthigh - 1
                     estproductlow = estproductlow + 0x100000000
                  end
                  
                  estproductlow = make32bitinteger(estproductlow - divlow)
                  
                  if estproducthigh > qrem or (estproducthigh == qrem and estproductlow > nl) then
                     qhat = qhat - 1
                  end
               end
            end
         end
         
         borrow = multiplythensubtract(remainder, div, qhat, i)
         
         if bitxor(borrow, negativemask) > nh2 then
            divisoradd(divisor, remainder, i)
            qhat = qhat - 1
         end
      end
      
      quotient[i] = qhat
   end
   
   destructiverightshift(remainder, shift)
   
   destructivestripleadingzeros(quotient)
   destructivestripleadingzeros(remainder)
   
   return quotient, remainder
end

function destructiveadddisjoint(mag, add, blocklength)
   local addlength = #add
   local maglength = #mag
   local difference = blocklength - maglength
   local shiftamount = addlength + difference
   
   for i = maglength, 1, -1 do
      -- shift mag up
      mag[i + shiftamount] = mag[i]
   end
   
   for i = shiftamount, addlength + 1, -1 do
      -- insert zeros if necessary
      mag[i] = 0
   end
   
   for i = min(addlength, shiftamount), 1, -1 do
      -- add the remaining values from add
      mag[i] = add[i]
   end
   
   destructivestripleadingzeros(mag)
   
   return mag
end

function divide2n1n(a, b)
   local a123, a4, q1, r, s
   local n, halfn
   
   n = #b
   
   -- step 1: base case
   -- if n is odd or small, do school division
   if bitand(n, 1) == 1 or n < burnikelzieglerthreshold then
      return destructivedivideknuth(a, b)
   end
   halfn = n / 2
   
   -- step 2: split A and B
   -- A = [a1,a2,a3,a4], a123 = [a1,a2,a3], each ai has up to n/2 bytes
   -- B = [b1,b2], but they're kept together in all calculations, so don't split
   a123, a4 = splitarrayatbytefromend(a, halfn)
   
   -- step 3:   q1 = a123 / b,   R = [r1,r2] = a123 % b
   q1, r = divide3n2n(a123, b, halfn)
   
   -- step 4:   a4 = [r1,r2,a4],   q2 = a4 / b,   S = a4 % b
   destructiveadddisjoint(a4, r, halfn)
   quotient, s = divide3n2n(a4, b, halfn)
   
   -- step 5:   Q = [q1,q2]
   destructiveadddisjoint(quotient, q1, halfn)
   
   destructivestripleadingzeros(quotient)
   destructivestripleadingzeros(s)
   
   return quotient, s
end

function divide3n2n(a, b, halfn)
   local a12, a1, a3, b1, b2, d, _
   local quotient, remainder
   
   local one = {1} -- used for decrementing
   
   -- step 1: A = [a1,a2,a3], let a12 = [a1,a2]
   a12, a3 = splitarrayatbytefromend(a, halfn)
   a1, _ = splitarrayatbytefromend(a12, halfn)
   
   -- step 2: B = [b1,b2]
   b1, b2 = splitarrayatbytefromend(b, halfn)
   
   if comparemagnitudes(a1, b1) < 0 then
      -- step 3a: a1<b1,   Q = a12 / b1,   R = a12 % b1
      quotient, remainder = divide2n1n(a12, b1)
      
      -- step 4: d = Q * b2
      d = multiplymagnitudes(quotient, b2)
   else
      -- step 3b: Q = (beta^n) - 1,   R = a12 + b1 - b1*2^halfn
      destructiveaddmagnitudes(a12, b1)
      destructiveleftshift(b1, 32 * halfn)
      destructivesubtractmagnitudes(a12, b1)
      remainder = a12
      
      -- Q = beta^halfn - 1 = a halfn-int array of all ones
      quotient = {}
      for i = 1, halfn do
         quotient[i] = 0xffffffff
      end
      
      -- step 4: d = Q * b2 = (beta^halfn - 1) * b2 = b2 * beta^halfn - b2
      d = copyandleftshift(b2, 32 * halfn)
      destructivesubtractmagnitudes(d, b2)
   end
   
   -- step 5: rh = R*beta^halfn + a3 - d (paper erroneously has a4 instead of a3)
   -- wait until after the loop to subtract d to keep R from going negative
   -- R = rh
   destructiveleftshift(remainder, 32 * halfn)
   destructiveaddmagnitudes(remainder, a3)
   
   -- step 6: adjust until R is positive
   -- rh < 0   ->   R*beta^halfn + a3 - d < 0   ->   R*beta^halfn + a3 < d
   while comparemagnitudes(remainder, d) < 0 do
      destructiveaddmagnitudes(remainder, b)
      destructivesubtractmagnitudes(quotient, one)
      -- TODO write efficient increment and decrement functions
   end
   
   destructivesubtractmagnitudes(remainder, d)
   
   return quotient, remainder
end

function destructivedivideburnikelziegler(dividend, divisor)
   local dividendlength, divisorlength, divisorbitlength
   local m, j, n, n32, sigma, t
   local blocks, blocklength
   local a1, z, qi, ri
   local quotient
   
   dividendlength = #dividend
   divisorlength = #divisor
   divisorbitlength = gethighestsetbit(divisor) + 1
   
   m = 2 ^ (64 - getleadingzeroslong(floor(divisorlength / burnikelzieglerthreshold)))
   j = ceil(divisorlength / m)
   n = j * m
   n32 = n * 32
   sigma = max(n32 - divisorbitlength, 0)
   
   destructiveleftshift(dividend, sigma)
   destructiveleftshift(divisor, sigma)
   t = max(floor((gethighestsetbit(dividend) + 1 + n32) / n32), 2)
   
   blocks = splitmagnitudeintoblocks(dividend, n)
   blocklength = #blocks
   
   a1 = blocks[1]
   z = blocks[2]
   destructiveadddisjoint(z, a1, n)
   
   quotient = {}
   
   for i = 3, blocklength do
      qi, ri = divide2n1n(z, divisor)
      
      z = blocks[i]
      
      destructiveadddisjoint(z, ri, n)
      
      -- does MutableBigInteger.addShifted without a separate function
      -- perhaps I will build an optimized procedure for this, but for now: here
      destructiveaddmagnitudes(quotient, copyandleftshift(qi, (blocklength + 1 - i) * n * 32))
   end
   
   qi, ri = divide2n1n(z, divisor)
   destructiveaddmagnitudes(quotient, qi)
   
   destructiverightshift(ri, sigma)
   
   return quotient, ri
end

function dividemagnitudes(dividend, divisor)
   -- Will divide the two numbers and return the quotient and remainder
   local comparison
   local quotient, remainder
   local dividendlength, divisorlength
   
   dividendlength = #dividend
   divisorlength = #divisor
   
   assert(divisorlength > 0, "division by zero")
   
   if dividendlength == 0 then
      -- 0 / x = 0
      return dividend, {}
   end
   
   comparison = comparemagnitudes(dividend, divisor)
   
   if comparison == 0 then
      -- numbers are equal: x / x = 1, so returns 1, 0
      return {1}, {}
   elseif comparison < 0 then
      -- dividend < divisor: x / y = 0 + x/y, so returns 0, x
      return {}, dividend
   end
   
   -- dividend > divisor, so x / y = q, r
   
   if dividendlength == 1 then
      -- dividend > divisor > 0, so dividendlengh >= divisorlength > 0
      -- if dividendlength == 1, then divisorlength == 1 as well
      -- do direct math
      return {floor(dividend[1] / divisor[1])}, {dividend[1] % divisor[1]}
   elseif divisorlength == 1 then
      quotient, remainder = divideoneword(dividend, divisor[1])
      return quotient, {remainder}
   end
   
   if divisorlength >= burnikelzieglerthreshold and dividendlength - divisorlength >= burnikelziegleroffset then
      return destructivedivideburnikelziegler(dividend, divisor)
   end
   
   return destructivedivideknuth(dividend, divisor)
end

function division(thisvalue, thatvalue)
   local thissign, thismag
   local thatsign, thatmag
   local sign, quotient, remainder
   
   assert(arebothvalidoperablevalues(thisvalue, thatvalue, "division"))
   
   thissign, thismag = getsignandmagnitude(thisvalue)
   thatsign, thatmag = getsignandmagnitude(thatvalue)
   
   quotient, remainder = dividemagnitudes(thismag, thatmag)
   sign = thissign * thatsign
   
   return constructorsignmagnitudetrusted(#quotient == 0 and 0 or sign, quotient), constructorsignmagnitudetrusted(#remainder == 0 and 0 or thissign, remainder)
end

function divideandremainder(thisvalue, thatvalue)
   return division(thisvalue, thatvalue)
end

function divide(thisvalue, thatvalue)
   local q, _ = division(thisvalue, thatvalue)
   return q
end

function remainder(thisvalue, thatvalue)
   local _, r = division(thisvalue, thatvalue)
   return r
end


--[[ String Functions ]]
function makestring(thisval, radix)
   local thissign, thismag
   local str
   
   assert(isvalidoperablevalue(thisval))
   
   if radix then
      assert(isvalidradix(radix))
   else
      radix = 10
   end
   
   thissign, thismag = getsignandmagnitude(thisval)
   
   if thissign == 0 then
      return "0"
   end
   
   str = stringbuildrecursive(thismag, radix, 0)
   
   return (thissign == -1 and '-' or '') .. str
end

function intstringofradix(i, radix)
    local t = {}
    
    repeat
        t[#t + 1] = characters[i % radix]
        i = floor(i / radix)
    until i == 0
    
    return stringreverse(tableconcat(t))
end

function smalltostring(thismag, radix)
   local q, r
   local numstr
   local stringarray
   local d = intradix[radix]
   local numgroups = 0
   local digitsperint = digitsperinteger[radix]
   local numstrarray = {}
   
   q = thismag
   while #q > 0 do
      q, r = divideoneword(q, d)
      
      numstr = intstringofradix(floor(r), radix)
      numstrarray[#numstrarray + 1] = numstr
   end
   
   if #numstrarray == 0 then
      return ''
   end
   
   stringarray = {numstrarray[#numstrarray]}
   
   for i = #numstrarray - 1, 1, -1 do
      numstr = numstrarray[i]
      stringarray[#stringarray + 1] = stringrep('0', digitsperint - #numstr)
      stringarray[#stringarray + 1] = numstr
   end
   
   return tableconcat(stringarray)
end

function getpowercache(radix, exponent)
   local sq
   local radixcache = powercache[radix]
   local pc
   
   for i = #radixcache + 1, exponent do
      if type(radixcache[i - 1]) == 'number' then
         sq = radixcache[i - 1] ^ 2
         
         if sq > maxinteger then
            -- If using an int is possible, then use an int.
            -- Use bigintegers only when number is too big for an int.
            sq = squaremagnitude(getnumbermagnitude(radixcache[i - 1]))
         end
      else
         sq = squaremagnitude(radixcache[i - 1])
      end
      radixcache[i] = sq
      
      --printarray(getmagnitude(sq))
   end
   
   pc = radixcache[exponent]
   
   if type(pc) == 'number' then
      return getnumbermagnitude(pc)
   end
   
   return copyarray(pc)
end

function stringbuildrecursive(thismag, radix, digits)
   local str, b, n, v, q, r, x
   if #thismag < schoenhagebaseconversionthreshold then
      str = smalltostring(thismag, radix)
      return stringrep('0', digits - #str) .. str
   end
   
   b = gethighestsetbit(thismag) + 1
   n = floor(log(b * radixlogs[radix]) / log2 + 0.5) - 1
   x = 2^n
   
   v = getpowercache(radix, n)
   
   q, r = dividemagnitudes(thismag, v)
   
   return stringbuildrecursive(q, radix, digits - x) ..
          stringbuildrecursive(r, radix, x)
end


do -- Temp stuff, wrapped for organization
   -- temporary functions to print the number in hexadecimal or binary
   function getintegerstringhexadecimal(number)
      return string.format('%08x', number)
      --[[local str, index = {}, 1
      
      for i = 28, 0, -4 do
         str[index], index = characters[bitand(bitrightshift(number, i), 0xf)], index + 1
      end
      
      return table.concat(str)]]
   end

   function getintegerstringbinary(number)
      local str, index = {}, 1
      
      for i = 31, 0, -1 do
         str[index], index = characters[bitand(bitrightshift(number, i), 0x1)], index + 1
      end
      
      return table.concat(str)
   end

   function printhex(number)
      print(getintegerstringhexadecimal(number))
   end

   function printhexlong(high, low)
      print(getintegerstringhexadecimal(high) .. getintegerstringhexadecimal(low))
   end

   function printarray(arr)
      print(stringofbytearray(arr))
   end

   function stringofbytearray(bigint, dobinary)
      local bytearray, balen, str
      
      assert(isvalidoperablevalue(bigint))
      
      bytearray = getmagnitude(bigint)
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
         local str = {'{'}
         
         if #bytearray > 0 then
            table.insert(str, '0x')
            table.insert(str, getintegerstringhexadecimal(bytearray[1]))
         end
      
         for i = 2, balen do
            table.insert(str, ', 0x')
            table.insert(str, getintegerstringhexadecimal(bytearray[i]))
         end
         
         table.insert(str, '}')
         return table.concat(str)
      end
      
      return str
   end
end

function reload()
   _G.package.loaded.biginteger = nil
   _G.biginteger = require('biginteger')
end

-- Computercraft `os.loadAPI` compatibility
if _CC_VERSION then
      -- CC 1.75 fixed a bug with the bit32 library that would break this module
   assert(tonumber(_CC_VERSION) >= 1.75, "Harri's BigInteger library compatibility for ComputerCraft requires CC version 1.75 or later")
   --_ENV.biginteger = biginteger
   return
end

return bi--{biginteger = biginteger}
