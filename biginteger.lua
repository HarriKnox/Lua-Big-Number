--[===========================================================================[
--[   _____________________________________________________________________   ]
--[  |\_                                                                 _/|  ]
--[  |  \ _____________________________________________________________ /| |  ]
--[  |   |                                                             | | |  ]
--[  |   |   ____   _         _         _                              | | |  ]
--[  |   |  |  _ \ (_)       (_)       | |                             | | |  ]
--[  |   |  | |_) | _   __ _  _  _ __  | |_   ___   __ _   ___  _ __   | | |  ]
--[  |   |  |  _ < | | / _` || || '_ \ | __| / _ \ / _` | / _ \| '__|  | | |  ]
--[  |   |  | |_) || || (_| || || | | || |_ |  __/| (_| ||  __/| |     | | |  ]
--[  |   |  |____/ |_| \__, ||_||_| |_| \__| \___| \__, | \___||_|     | | |  ]
--[  |   |              __/ |                       __/ |              | | |  ]
--[  |   |_____________|___/_______________________|___/_______________| | |  ]
--[  | _/_______________________________________________________________\| |  ]
--[  |/___________________________________________________________________\|  ]
--[                                                                           ]
--[ A big-integer library for Lua, written in pure Lua, and designed to work. ]
--[                                                        ^                  ]
--[ by Harrison Knox (HarriKnox)                 (will eventually be)         ]
--[                                                                           ]
--]===========================================================================]



--[[ Sandbox for testing purposes ]]
local bi = {}
setmetatable(bi, {__index = _G})
_ENV = bi




--[=========================================================[
--[   _____                    _                  _         ]
--[  / ____|                  | |                | |        ]
--[ | |      ___   _ __   ___ | |_   __ _  _ __  | |_  ___  ]
--[ | |     / _ \ | '_ \ / __|| __| / _` || '_ \ | __|/ __| ]
--[ | |____| (_) || | | |\__ \| |_ | (_| || | | || |_ \__ \ ]
--[  \_____|\___/ |_| |_||___/ \__| \__,_||_| |_| \__||___/ ]
--[                                    _                    ]
--[                                   | |                   ]
--[                   __ _  _ __    __| |                   ]
--[                  / _` || '_ \  / _` |                   ]
--[            _    | (_| || | | || (_| | _                 ]
--[           | |    \__,_||_| |_| \__,_|| |                ]
--[           | |      ___    ___   __ _ | | ___            ]
--[           | |     / _ \  / __| / _` || |/ __|           ]
--[           | |____| (_) || (__ | (_| || |\__ \           ]
--[           |______|\___/  \___| \__,_||_||___/           ]
--[                                                         ]
--]=========================================================]

--[===================[
--[ Bitwise Functions ]
--]===================]

local bitand        = (bit32 or bit).band
local bitor         = (bit32 or bit).bor
local bitnot        = (bit32 or bit).bnot
local bitxor        = (bit32 or bit).bxor
local bitleftshift  = (bit32 and bit32.lshift) or (bit and bit.blshift)
local bitrightshift = (bit32 and bit32.rshift) or (bit and bit.blogic_rshift)
local bitandnot     = function(x, y) return bitand(x, bitnot(y)) end



--[================[
--[ Math Functions ]
--]================]

local floor = floor or math.floor
local ceil  = ceil  or math.ceil
local max   = max   or math.max
local min   = min   or math.min
local abs   = abs   or math.abs
local log   = log   or math.log



--[==================[
--[ String Functions ]
--]==================]

local stringchar    = string.char
local stringbyte    = string.byte
local stringsub     = string.sub
local stringmatch   = string.match
local stringfind    = string.find
local stringrep     = string.rep
local stringreverse = string.reverse



--[=================[
--[ Table Functions ]
--]=================]

local tableconcat = table.concat
local tableinsert = table.insert



--[===========[
--[ Constants ]
--]===========]

--[==[
-- The largest integer you can fit in a 64-bit float
--
-- maxinteger  =  2^53 - 1
--]==]
local maxinteger = 0x1fffffffffffff



--[==[
-- The largest magnitude allowable because of 32 bits per word (allows for up
-- to `maxinteger` bits).
--
-- maxmagnitudelength  =  (2^53 / 2^5) - 1  =  2^48 - 1
--]==]
local maxmagnitudelength = 0xffffffffffff


--[==[
-- A mask used for 32-bit integers to get the sign.
--]==]
local negativemask = 0x80000000


--[==[
-- A constant for the log of 2, used primarily in radix conversion.
--]==]
local log2 = log(2)



--[==================[
--[ Threshold Values ]
--]==================]

local karatsubasquarethreshold = 128
local karatsubamultiplythreshold = 80


local toomcooksquarethreshold = 216
local toomcookmultiplythreshold = 240


local burnikelzieglerthreshold = 80
local burnikelziegleroffset = 40


local schoenhagebaseconversionthreshold = 20



--[===================[
--[ Tables and Caches ]
--]===================]

--[==[
-- A table, indexed by radix, of the number of bits contained in one digit of a
-- string representation of an integer in a given radix, multiplied by 1024 and
-- rounded up (to prevent underestimation).
--
-- bitsperdigit[r] = ceil(1024 * log(r) / log(2))
--]==]
local bitsperdigit = {
      0, 1024, 1624, 2048, 2378, 2648,
   2875, 3072, 3247, 3402, 3543, 3672,
   3790, 3899, 4001, 4096, 4186, 4271,
   4350, 4426, 4498, 4567, 4633, 4696,
   4756, 4814, 4870, 4923, 4975, 5025,
   5074, 5120, 5166, 5210, 5253, 5295}


--[==[
-- A table, indexed by radix, of the number of digits in a string-number of a
-- given radix that can fit in an int without overflowing or "going negative"
-- (in Two's complement form): that is, the largest number `n` for a radix `r`
-- such that r^n < 2^31 (or 0x80000000).
--
-- digitsperinteger[r] = floor(log(2^31) / log(r))
--]==]
local digitsperinteger = {
    0, 30, 19, 15, 13, 11,
   11, 10,  9,  9,  8,  8,
    8,  8,  7,  7,  7,  7,
    7,  7,  7,  6,  6,  6,
    6,  6,  6,  6,  6,  6,
    6,  6,  6,  6,  6,  5}
--[[
-- Note to self, I think the need for 2^31 in r^n < 2^31 is a hold-over from
-- the signedness of Java's int type. Since Lua's ints can handle more than 32
-- bits, I think I can change the 2^31 to 2^32; basically I'm checking to make
-- sure it doesn't overflow and no longer checking if it goes negative. The
-- following radices will change: 2, 3, 4, 6, 9, 11, 15, 16, 22, 23, and 36.
-- The same will go for intradix.
--]]


--[==[
-- A table, indexed by radix, of the maximum value of one digit grouping of a
-- given radix that can fit in an int without overflowing nor "going negative".
--
-- intradix[r] = r ^ digitsperinteger[r]
--]==]
local intradix = {
            0, 0x40000000, 0x4546b3db, 0x40000000, 0x48c27395, 0x159fd800,
   0x75db9c97, 0x40000000, 0x17179149, 0x3b9aca00, 0x0cc6db61, 0x19a10000,
   0x309f1021, 0x57f6c100, 0x0a2f1b6f, 0x10000000, 0x18754571, 0x247dbc80,
   0x3547667b, 0x4c4b4000, 0x6b5a6e1d, 0x06c20a40, 0x08d2d931, 0x0b640000,
   0x0e8d4a51, 0x1269ae40, 0x17179149, 0x1cb91000, 0x23744899, 0x2b73a840,
   0x34e63b41, 0x40000000, 0x4cfa3cc1, 0x5c13d840, 0x6d91b519, 0x039aa400}


--[==[
-- The list of ASCII characters used for each digit value, with the index as
-- the value.
--
-- Lowercase is used to increase variety in the heights of numbers. In the
-- following example, the number on the left has a varied and more
-- aesthetically-pleasing look, whereas the number on the right looks like a
-- big rectangle.
--
--              123abckz92gpqbn84a30b vs 123ABCKZ92GPQBN84A30B
--                varied and pretty   vs   a large rectangle
--]==]
local characters = {
   '1', '2', '3', '4', '5', '6', '7',
   '8', '9', 'a', 'b', 'c', 'd', 'e',
   'f', 'g', 'h', 'i', 'j', 'k', 'l',
   'm', 'n', 'o', 'p', 'q', 'r', 's',
   't', 'u', 'v', 'w', 'x', 'y', 'z',
   [0] = '0'}


--[==[
-- A table, indexed by radix, of base-conversion constants, used for large
-- string base conversion from the given radix to Base-2.
--
-- radixlogs[r] = log2 / log(r)
--]==]
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


--[==[
-- The cache of powers r^2^n for each radix r, for large string base
-- conversion.
--
-- There are three layers of tables: this is an array of lists of
-- integers/magnitudes.
--  * `powercache` is an array with radix indices of lists
--  * `powercache[r]` is a list with exponent indices of magnitudes
--  * `powercache[r][n]` is an integer or magnitude
--
-- powercache[r][n] = r^2^n
--
-- The magnitude in powercache[r][n] is stored as a Lua integer if it's small
-- enough (less than `maxinteger`), otherwise it's stored as a magnitude.
--]==]
local powercache = {
       nil , { 2 ^ 2}, { 3 ^ 2}, { 4 ^ 2}, { 5 ^ 2}, { 6 ^ 2},
   { 7 ^ 2}, { 8 ^ 2}, { 9 ^ 2}, {10 ^ 2}, {11 ^ 2}, {12 ^ 2},
   {13 ^ 2}, {14 ^ 2}, {15 ^ 2}, {16 ^ 2}, {17 ^ 2}, {18 ^ 2},
   {19 ^ 2}, {20 ^ 2}, {21 ^ 2}, {22 ^ 2}, {23 ^ 2}, {24 ^ 2},
   {25 ^ 2}, {26 ^ 2}, {27 ^ 2}, {28 ^ 2}, {29 ^ 2}, {30 ^ 2},
   {31 ^ 2}, {32 ^ 2}, {33 ^ 2}, {34 ^ 2}, {35 ^ 2}, {36 ^ 2}}




--[======================================================================[
--[  _______                      _______          _    _                ]
--[ |__   __|                    |__   __|        | |  (_)               ]
--[    | | _   _  _ __    ___  ____ | |  ___  ___ | |_  _  _ __    __ _  ]
--[    | || | | || '_ \  / _ \|____|| | / _ \/ __|| __|| || '_ \  / _` | ]
--[    | || |_| || |_) ||  __/      | ||  __/\__ \| |_ | || | | || (_| | ]
--[    |_| \__, || .__/  \___|      |_| \___||___/ \__||_||_| |_| \__, | ]
--[         __/ || |                                               __/ | ]
--[        |___/ |_|                                              |___/  ]
--[         ______                    _    _                             ]
--[        |  ____|                  | |  (_)                            ]
--[        | |__  _   _  _ __    ___ | |_  _   ___   _ __   ___          ]
--[        |  __|| | | || '_ \  / __|| __|| | / _ \ | '_ \ / __|         ]
--[        | |   | |_| || | | || (__ | |_ | || (_) || | | |\__ \         ]
--[        |_|    \__,_||_| |_| \___| \__||_| \___/ |_| |_||___/         ]
--[                                                                      ]
--]======================================================================]

--[==[
-- Tests whether the passed value is an integer that the library can use:
--  * A Lua number type
--  * Inside the range of [-maxinteger, maxinteger]
--  * Not a float
--]==]
function isvalidinteger(int)
   --[[ Check that the value is actually a number ]]
   if type(int) ~= 'number' then
      return false, "not a valid integer: it's a " .. type(int)
   end
   
   
   --[[ Now check that it's in range ]]
   if int > maxinteger or int < -maxinteger then
      return false, "not a valid integer: outside allowable range"
   end
   
   
   --[[ Now check that it's not a float ]]
   if int % 1 ~= 0 then
      return false, "not a valid integer: it's a float"
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is a bit-index that the library can use:
--  * A Lua number type
--  * Inside the range of [0, maxinteger]
--  * Not a float
--]==]
function isvalidbitindex(int)
   --[[ Check that the value is actually a number ]]
   if type(int) ~= 'number' then
      return false, "not a valid bit-index: it's a " .. type(int)
   end
   
   
   --[[ Now check that it's in range ]]
   if int < 0 or int > maxinteger then
      return false, "not a valid bit-index: outside allowable range"
   end
   
   
   --[[ Now check that it's not a float ]]
   if int % 1 ~= 0 then
      return false, "not a valid bit-index: it's a float"
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is an int that the library can use:
--  * A Lua number type
--  * Inside the range [0, 4294967295] (not negative nor larger than 32 bits)
--  * Not a float
--]==]
function isvalidint(int)
   --[[ First, check that it is a number ]]
   if type(int) ~= 'number' then
      return false, "not a valid int: it's a " .. type(int)
   end
   
   
   --[[ Ensure that it doesn't exceed 32 bits ]]
   if int > 0xffffffff then
      return false, "not a valid int: outside 32 bits"
   end
   
   
   --[[ Ensure that it's not negative ]]
   if int < 0 then
      return false, "not a valid int: negative"
   end
   
   
   --[[ Ensure that it's not a float ]]
   if int % 1 ~= 0 then
      return false, "not a valid int: it's a float"
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is a 32-bit integer that, when made positive,
-- the library can use:
--  * A Lua number type
--  * A 32-bit integer when made positive
--
-- Note, this is not looking at the Two's complement form of the number (that
-- would be redundant since the number would need to be a 32-bit number
-- anyway). This checks the value to ensure it is in the range
-- [-4294967295, 4294967295].
--]==]
function isvalidabsolute32bitinteger(int)
   --[[ Check if it's a number ]]
   if type(int) ~= 'number' then
      return false, "not a valid absolute 32-bit integer: it's a " .. type(int)
   end
   
   
   --[[ Now check if the absolute value is an int ]]
   local ok, reason = isvalidint(abs(int))
   
   
   return ok, "not a valid absolute 32-bit integer: " .. reason
end


--[==[
-- Tests whether the passed value is a word-array that the library can use:
--  * A Lua table type
--  * Not a biginteger (in which it won't be treated as a word-array)
--  * An array that contains only values that are ints
--
-- Note, this function (and every other array function, for that matter) uses
-- the length operator (#) in a `for i = 1, #array do` loop.
--]==]
function isvalidwordarray(array)
   --[[ First check that it's a table ]]
   if type(array) ~= 'table' then
      return false, "not a valid word-array: not an array (table): it's a " .. type(array)
   end
   
   
   --[[ Next, if it could be terated as a biginteger, then fail ]]
   if isvalidbiginteger(array) then
      return false, "not a valid word-array: it's a biginteger"
   end
   
   
   --[[ Now test every element from 1 to #array to ensure each is an int ]]
   for i = 1, #array do
      local ok, reason = isvalidint(array[i])
      
      
      if not ok then
         return false, "not a valid word-array: element " .. i .. " " .. reason
      end
   end
   
   return true
end


--[==[
-- Tests whether the passed value is a magnitude that the library can use:
--  * A valid word-array
--  * Not too large
--  * No leading zeros
--]==]
function isvalidmagnitude(mag)
   --[[ Make sure the magnitude is an actual array ]]
   local ok, reason = isvalidwordarray(mag)
   
   if not ok then
      return false, "not a valid magnitude: " .. reason
   end
   
   
   --[[ Ensure the length of the array doesn't exceed the maximum length ]]
   if #mag >= maxmagnitudelength then
      return false, "not a valid magnitude: too large"
   end
   
   
   --[[ Ensure there are no leading zeros ]]
   if mag[1] == 0 then
      return false, "not a valid magnitude: has leading zeros"
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is a sign that the library can use:
--  * A number
--  * Either -1, 0, or 1
--]==]
function isvalidsign(sign)
   --[[ Check that the value is a number ]]
   if type(sign) ~= 'number' then
      return false, "not a valid sign: not a number: it's a " .. type(sign)
   end
   
   
   --[[ Use a super-complex algorithm to see if it equals -1, 0, or +1 ]]
   if sign ~= -1 and sign ~= 0 and sign ~= 1 then
      return false, "not a valid sign: not in {-1, 0, 1}"
   end
   
   
   return true
end


--[==[
-- Tests whether the sign and magnitude given are a sign-magnitude pairing that
-- the library can use:
--  * `sign` is a sign
--  * `mag` is a magnitude
--  * A non-zero magnitude is not paired with a zero-sign (ambiguous sign)
--  * A zero-magnitude is not paired with a non-zero-sign (redundant zeros)
--
-- Note, preventing redundant zeros are just to enforce that there aren't
-- multiple notations for the same value, that is -0, 0, and +0. This isn't as
-- big of an issue as ambiguous signage, so I might remove this part of the
-- test later.
--]==]
function isvalidsignmagnitudecombination(sign, mag)
   --[[ Check that the sign is a proper sign ]]
   local ok, reason = isvalidsign(sign)
   
   if not ok then
      return false, "not a valid sign-magnitude pair: " .. reason
   end
   
   
   --[[ Now check that the magnitude is a proper magnitude ]]
   ok, reason = isvalidmagnitude(mag)
   
   if not ok then
      return false, "not a valid sign-magnitude pair: " .. reason
   end
   
   
   --[[ A value that is not positive nor negative nor zero isn't supported ]]
   if sign == 0 and #mag ~= 0 then
      return false,
            "not a valid sign-magnitude pair: non-zero mag with zero sign"
   end
   
   
   --[[ Positive and negative zeros aren't allowed to ensure uniqueness ]]
   if sign ~= 0 and #mag == 0 then
      return false,
            "not a valid sign-magnitude pair: non-zero sign with zero mag"
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is a biginteger that the library can use:
--  * A Lua table type
--  * Contains a valid sign
--  * Contains a valid magnitude
--  * Contains a valid sign-magnitude pair
--]==]
function isvalidbiginteger(bigint)
   --[[ Make sure the value is a table (Lua's object) ]]
   if type(bigint) ~= 'table' then
      return false,
            "not a valid biginteger: not a table: it's a " .. type(bigint)
   end
   
   
   --[[ Make sure there exists a bigint.sign and that it is a sign ]]
   local ok, reason = isvalidsign(bigint.sign)
   
   if not ok then
      return false, "not a valid biginteger: " .. reason
   end
   
   
   --[[ Make sure there exists a bigint.magnitude and that it is a magnitude ]]
   ok, reason = isvalidmagnitude(bigint.magnitude)
   
   if not ok then
      return false, "not a valid biginteger: " .. reason
   end
   
   
   --[[ Make sure the sign and magnitude play nice ]]
   ok, reason = isvalidsignmagnitudecombination(bigint.sign, bigint.magnitude)
   
   if not ok then
      return false, "not a valid biginteger: " .. reason
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is a radix that the library can use:
--  * An integer
--  * In the range [2, 36]
--]==]
function isvalidradix(radix)
   --[[ Make sure it's a number ]]
   local ok, reason = isvalidinteger(radix)
   
   if not ok then
      return false, "not a valid radix: " .. reason
   end
   
   
   --[[ Check that it's in the bounds of 2 <= r <= 36 ]]
   if radix < 2 or radix > 36 then
      return false, "not a valid radix: outside allowable range"
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is a string-number that the library can use:
--  * A string
--  * Contains only characters that are valid with the given radix
--]==]
function isvalidstringnumber(str, radix)
   --[[ First make sure the thing is a string ]]
   if type(str) ~= 'string' then
      return false,
            "not a valid string-number: not a string: it's a" .. type(str)
   end
   
   
   --[[ See if the string has no digits in it and fail if so ]]
   if stringmatch(str, '^[-+]?$') then
      return false, "not a valid string-number: zero-length string"
   end
   
   
   --[[
   -- Use the highest valid value of the radix to determine the upper bound to
   -- the set of characters.
   --]]
   local highest = radix - 1
   local set
   
   if highest < 10 then
      set = '0-' .. tostring(highest)
   
   elseif highest == 10 then
      set = '0-9Aa'
   
   else
      set = '0-9A-' .. stringchar(highest + 55) .. 'a-'
         .. stringchar(highest + 87)
   end
   
   
   --[[
   -- Attempt to match the string-number to the pattern of an optional sign and
   -- at least one character
   --]]
   if stringmatch(str, '^[-+]?[' .. set .. ']+$') then
      return true
   end
   
   
   --[[ Attempt to match a non-digit character ]]
   local _, index, c = stringfind(str,
         '^[-+]?[' .. set .. ']*([^' .. set .. '])')
   
   return false,
         "not a valid string-number: contains non-digit character at index "
         .. tostring(index) .. ": '" .. c .. "'"
end


--[==[
-- Returns the type of the object based on their validity using the testing
-- functions.
--]==]
function gettype(thing)
   return (isvalidinteger(thing) and 'integer') or
          (isvalidbiginteger(thing) and 'biginteger') or
          (isvalidwordarray(thing) and 'word-array') or
          type(thing)
end


--[==[
-- Returns whether the type is for an operable value.
--]==]
function istypeoperable(valuetype)
   return valuetype == 'integer'
         or valuetype == 'biginteger'
         or valuetype == 'word-array'
end


--[==[
-- Tests if the passed value is either a integer, biginteger, or word-array
-- that the library can use. Returns the type of the value if it is operable or
-- `nil` if it isn't.
--]==]
function isvalidoperablevalue(value)
   local valuetype = gettype(value)
   
   if istypeoperable(valuetype) then
      return valuetype
   end
   
   
   return nil, "not a valid operable value: it's a " .. valuetype
end


--[==[
-- Tests if the passed values are both operable values and fails if either are
-- not. Returns the types of the values if they are operable, or `nil` for both
-- if either are not.
--
-- The third return value (the reason it failed) will incorporate the
-- operation attempted, thus the `operation` parameter is a string of what the
-- operation was (such as "addition" or "multiplication").
--]==]
function arebothvalidoperablevalues(thisvalue, thatvalue, operation)
   local thistype = gettype(thisvalue)
   local thattype = gettype(thatvalue)
   
   
   --[[ Check if both values are operable values ]]
   if istypeoperable(thistype) and istypeoperable(thattype) then
      return thistype, thattype
   end
   
   
   return nil, nil, "attempt to perform " .. operation .. " on "
         .. thistype .. " and " .. thattype
end


--[==[
-- Tests if the first value is a biginteger and the second value is an operable
-- value. Returns the type of the second value if they are operable or `nil` if
-- either are not operable.
--
-- The second return value (the reason it failed) will incorporate the
-- operation attempted, thus the `operation` parameter is a string of what the
-- operation was (such as "addition" or "multiplication").
--]==]
function arevalidbigintegerandoperablevalue(bigint, value, operation)
   local biginttype = gettype(bigint)
   local valuetype = gettype(value)
   
   
   --[[ Check first value is biginteger and second is operable ]]
   if biginttype == 'biginteger' and istypeoperable(valuetype) then
      return valuetype
   end
   
   
   return nil, "attempt to perform " .. operation .. " on "
         .. biginttype .. " and " .. valuetype
end




--[=======================================================[
--[          _    _        _                              ]
--[         | |  | |      | |                             ]
--[         | |__| |  ___ | | _ __    ___  _ __           ]
--[         |  __  | / _ \| || '_ \  / _ \| '__|          ]
--[         | |  | ||  __/| || |_) ||  __/| |             ]
--[         |_|  |_| \___||_|| .__/  \___||_|             ]
--[      _____         _     | |                          ]
--[     |_   _|       | |    |_|                          ]
--[       | |   _ __  | |_   ___   __ _   ___  _ __       ]
--[       | |  | '_ \ | __| / _ \ / _` | / _ \| '__|      ]
--[      _| |_ | | | || |_ |  __/| (_| ||  __/| |         ]
--[     |_____||_| |_| \__| \___| \__, | \___||_|         ]
--[  ______                    _   __/ |                  ]
--[ |  ____|                  | | |(_)/                   ]
--[ | |__  _   _  _ __    ___ | |_  _   ___   _ __   ___  ]
--[ |  __|| | | || '_ \  / __|| __|| | / _ \ | '_ \ / __| ]
--[ | |   | |_| || | | || (__ | |_ | || (_) || | | |\__ \ ]
--[ |_|    \__,_||_| |_| \___| \__||_| \___/ |_| |_||___/ ]
--[                                                       ]
--]=======================================================]

--[==[
-- Takes a long and splits it into two ints so the lowest 32 bits of the long
-- are in the second return value and all bits higher than the 32 bits are
-- bit-shifted to the right and returned in the first value.
--]==]
function splitlong(number)
   return floor(number / 0x100000000), number % 0x100000000
end


--[==[
-- Takes a number and splits it into two integers so the second return value is
-- the lowest 5 bits (less than 32) and the first return value is the number
-- without those 5 bits.
--]==]
function splitlongtowordsandbits(number)
   return floor(number / 32), number % 32
end


--[==[
-- A helper function to do long multiplication using ints. Takes two ints (`x`
-- and `ab`) and multiplies them together, then adds a third value `c`. Returns
-- the result of `x * ab + c = r` as a split long.
--
-- All of this math is done since 64-bit floats (the default size/type of Lua
-- numbers until Lua 5.3) allow for at most 53 bits of mantissa, thus the
-- largest integer possible without losing precision is a 53-bit integer. Since
-- the use of 64 bits is rather useful, this math allows us to multiply and add
-- numbers without the fear of losing bits, at the cost of taking longer.
--
-- For more information on how the multiplication works, please read the
-- appendix document "int-multiply-int".
--]==]
function intmultiplyint(x, ab, c)
   --[[ Split `ab` into `a` and `b` ]]
   local a = bitrightshift(ab, 16)
   local b = bitand(ab, 0xffff)
   
   
   --[[ Get `xa` and `xb` ]]
   local xa = x * a
   local xb = x * b
   
   
   --[[ Split up `xa` and `xb` based on the 32-bit "midline" ]]
   local xahigh = floor(xa / 0x10000)
   local xalow = bitleftshift(xa, 16)
   
   local xbhigh = floor(xb / 0x100000000)
   local xblow = xb % 0x100000000
   
   
   --[[ Add the lower words ]]
   local carry, rlow = splitlong(xalow + xblow + c)
   
   
   --[[ Add the upper words ]]
   local rhigh = xahigh + xbhigh + carry
   
   
   return rhigh, rlow
end


--[==[
-- Another helper function to do long division using ints. Takes a split-long
-- disguised as two ints (`ah` and `al`) and pretends they're one long `a` and
-- divides that by `b`. Returns the quotient and remainder of `a / b` as a
-- split-long and int (respectively).
--
-- Like the previous function, this function is necessary to facilitate long
-- arithmetic using ints.
--]==]
function longdivideint(ah, al, b)
   --[[ Get the 32 bits of `ah` concatenated to the top 16 bits of `al` ]]
   local ahhl = ah * 0x10000 + floor(al / 0x10000)
   
   
   --[[ Get the first quotient and remainder ]]
   local q1 = floor(ahhl / b)
   local r1 = ahhl % b
   
   
   --[[ Concatenate the first remainder to the lower 16 bits of `al` ]]
   local r1al = r1 * 0x10000 + (al % 0x10000)
   
   
   --[[ Get the second quotient and remainder ]]
   local q2 = floor(r1al / b)
   local r2 = r1al % b
   
   
   --[[ Get the final quotient by splitting `q1` and `q2` along 32 bits ]]
   local ql = ((q1 % 0x10000) * 0x10000) + (q2 % 0x100000000)
   local qh = floor(q1 / 0x10000) + floor(q2 / 0x100000000)
   
   
   --[[ If the lower addition overflows, put the overflow into `qh` ]]
   if ql >= 0x100000000 then
      qh = qh + 1
      ql = ql - 0x100000000
   end
   
   
   --[[ Return the quotient as a split long and the remainder ]]
   return qh, ql, r2
end


--[==[
-- Returns the number of leading zeros in the int.
--
-- This uses one of the Hacker's Delight algorithms featured in HD Figure 5-6.
-- Some optimizing modifications were made (switching the bit-shifts to
-- multiplications) for speed.
--]==]
function numberofleadingzeros(int)
   --[[ Special case that is easy to check ]]
   if int == 0 then
      return 32
   end
   
   
   --[[ 'n' is the number of leading zeros ]]
   local n = 0
   
   
   --[[ Check if the highest 16 bits are zeros ]]
   if int <= 0x0000ffff then
      n = n + 16
      int = int * 0x10000
   end
   
   
   --[[ Check if the highest 8 bits are zeros ]]
   if int <= 0x00ffffff then
      n = n + 8
      int = int * 0x100
   end
   
   
   --[[ Check if the highest 4 bits are zeros ]]
   if int <= 0x0fffffff then
      n = n + 4
      int = int * 0x10
   end
   
   
   --[[ Check if the highest 2 bits are zeros ]]
   if int <= 0x3fffffff then
      n = n + 2
      int = int * 0x4
   end
   
   
   --[[ Check if the highest bit is a zero ]]
   if int <= 0x7fffffff then
      n = n + 1
   end
   
   
   return n
end


--[==[
-- Returns the number of trailing zeros in the int. Uses one of the Hacker's
-- Delight algorithms featured in (HD Figure 5-14).
--
-- This uses the algorithm selected by the Java Integer class and is slow
-- because of all the calls to the bit-shifting function. Unlike the function
-- for counting leading zeros, this function can't be optimized in the same
-- way (changing bit-shifts for multiplications and divisions), but that's OK
-- because this function is rarely called in comparison to its counterpart.
--]==]
function numberoftrailingzeros(int)
   --[[ Quick check for zero ]]
   if int == 0 then
      return 32
   end
   
   
   --[[ 'n' is the number of trailing zeros ]]
   local n = 32
   
   
   --[[ Check if lowest 16 bits are zeros ]]
   local y = bitleftshift(int, 16)
   
   if y ~= 0 then
      n = n - 16
      int = y
   end
   
   
   --[[ Check if lowest 8 bits are zeros ]]
   y = bitleftshift(int, 8)
   
   if y ~= 0 then
      n = n - 8
      int = y
   end
   
   
   --[[ Check if lowest 4 bits are zeros ]]
   y = bitleftshift(int, 4)
   
   if y ~= 0 then
      n = n - 4
      int = y
   end
   
   
   --[[ Check if lowest 2 bits are zeros ]]
   y = bitleftshift(int, 2)
   
   if y ~= 0 then
      n = n - 2
      int = y
   end
   
   
   --[[ Check if lowest bit is zero ]]
   if bitleftshift(int, 1) == 0 then
      n = n - 1
   end
   
   
   return n
end


--[==[
-- Returns the number of leading zeros in a long.
--
-- Because this function uses only the most significant bits, the least
-- significant aren't looked at so the full 64 bits can be used without the
-- fear of the loss of the lowest bits.
--]==]
function numberofleadingzeroslong(long)
   --[[ Split the long ]]
   local high, low = splitlong(long)
   
   
   --[[ Get the number of leading zeros in the high word ]]
   local leadingzeros = numberofleadingzeros(high)
   
   
   --[[ If the zeros extend into the low word, get the total number of zeros ]]
   if leadingzeros == 32 then
      leadingzeros = 32 + numberofleadingzeros(low)
   end
   
   
   return leadingzeros
end


--[==[
-- Returns the number of trailing zeros in a long.
--
-- Because this function uses the least significant bits, the results of it are
-- undefined if passed an integer too large for the 64-bit floating-point
-- number (a 54-bit integer or larger).
--]==]
function numberoftrailingzeroslong(long)
   --[[ Split the long ]]
   local high, low = splitlong(long)
   
   
   --[[ Get the number of trailing zeros in the low word ]]
   local trailingzeros = numberoftrailingzeros(low)
   
   
   --[[ If the zeros extend into high word, get the total number of zeros ]]
   if trailingzeros == 32 then
      trailingzeros = 32 + numberoftrailingzeros(high)
   end
   
   
   return trailingzeros
end




--[=======================================================[
--[             ___                                       ]
--[            / _ \                                      ]
--[           | |_| | _ __  _ __  __ _  _   _             ]
--[           |  _  || '__|| '__|/ _` || | | |            ]
--[           | | | || |   | |  | (_| || |_| |            ]
--[           |_| |_||_|   |_|   \__,_| \__, |            ]
--[  ______                    _    _    __/ |            ]
--[ |  ____|                  | |  (_)  |___/             ]
--[ | |__  _   _  _ __    ___ | |_  _   ___   _ __   ___  ]
--[ |  __|| | | || '_ \  / __|| __|| | / _ \ | '_ \ / __| ]
--[ | |   | |_| || | | || (__ | |_ | || (_) || | | |\__ \ ]
--[ |_|    \__,_||_| |_| \___| \__||_| \___/ |_| |_||___/ ]
--[                                                       ]
--]=======================================================]

--[==[
-- Returns a new array that is a shallow copy of the array passed in.
--]==]
function copyarray(source)
   local destination = {}
   
   
   --[[ Copy each entry individually ]]
   for i = 1, #source do
      destination[i] = source[i]
   end
   
   
   return destination
end


--[==[
-- Clears the selected array in-place by setting all entries to `nil`.
--]==]
function cleararray(array)
   --[[ One-by-one, set each entry to `nil` ]]
   for i = 1, #array do
      array[i] = nil
   end
   
   
   return array
end


--[==[
-- Clears `array` and copies into it the entries of `newvalues`.
--]==]
function clearandcopyintoarray(array, newvalues)
   --[[ Copy the values in from the start ]]
   local newvalueslength = #newvalues
   
   for i = 1, newvalueslength do
      array[i] = newvalues[i]
   end
   
   
   --[[ If `array` was longer, clear the remaining entries ]]
   local arraylength = #array
   
   for i = newvalueslength + 1, arraylength do
      array[i] = nil
   end
   
   
   return array
end


--[==[
-- Swaps the entries of both passed arrays).
--]==]
function swaparrays(thisarray, thatarray)
   for i = 1, max(#thisarray, #thatarray) do
      thisarray[i], thatarray[i] = thatarray[i], thisarray[i]
   end
end


--[==[
-- Creates a new array of the specified length filled with zeros.
--]==]
function allocatearray(length)
   local array = {}
   
   
   --[[ Make a ton of zeros ]]
   for i = 1, length do
      array[i] = 0
   end
   
   
   return array
end


--[==[
-- Splits an array into two sub-arrays, 'upper' and 'lower', such that 'lower'
-- contains `length` elements and 'upper' contains the remaining elements.
--
-- If `length` is zero/negative ('lower' is empty) or equal-to/larger-than the
-- length of the array ('upper' is empty) this will return a copy of the array
-- with an empty array in the appropriate spot. This function always returns
-- two arrays, even in the cases where the array isn't split.
--]==]
function splitarray(mag, length)
   --[[ If the length is zero/negative, 'lower' is empty ]]
   if length <= 0 then
      return copyarray(mag), {}
   end
   
   
   --[[ If the length is the entire array or more, 'upper' is empty ]]
   local maglength = #mag
   
   if length >= maglength then
      return {}, copyarray(mag)
   end
   
   
   --[[ Initialize the sub-arrays ]]
   local upper = {}
   local lower = {}
   
   
   --[[ Copy the first values into 'upper' ]]
   local upperlength = maglength - length
   
   for i = 1, upperlength do
      upper[i] = mag[i]
   end
   
   
   --[[ Copy the second set of values into 'lower' ]]
   for i = upperlength + 1, maglength do
      lower[i - upperlength] = mag[i]
   end
   
   
   return upper, lower
end


--[==[
-- Splits the array into right-justified blocks and returns an array of blocks.
--
-- A block is a sub-array. The length of the blocks (in words) are at most the
-- specified block length. The most-significant block is the only one that may
-- be shorter than the given length; all the lesser-significant blocks are
-- filled to the brim.
--
-- For example, pretend each X is a word in this 35-word long array, split with
-- blocksize 8; these would be the resulting blocks.
--       XXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX
--]==]
function splitarrayintoblocks(mag, blocklength)
   local maglength = #mag
   local numberofblocks = ceil(maglength / blocklength)
   
   local blocks
   local index
   
   
   --[[ Make room for all the blocks in a big list ]]
   blocks = {}
   for i = 1, numberofblocks do
      blocks[i] = {}
   end
   
   
   --[[ Start at the least-significant word ]]
   index = maglength
   
   
   --[[ Copy the full blocks into the block array ]]
   for block = numberofblocks, 2, -1 do
      for blockindex = blocklength, 1, -1 do
         blocks[block][blockindex], index = mag[index], index - 1
      end
   end
   
   
   --[[ Copy the most significant, possibly not full, block ]]
   for blockindex = index, 1, -1 do
      blocks[1][blockindex], index = mag[index], index - 1
   end
   
   
   return blocks
end




--[======================================================================[
--[  _       _                  _         ___                            ]
--[ | |     | |                | |       / _ \                           ]
--[ | |  _  | |  ___   _ __  __| | ____ | |_| | _ __  _ __  __ _  _   _  ]
--[ | | | | | | / _ \ | '__|/ _` ||____||  _  || '__|| '__|/ _` || | | | ]
--[ | |_| |_| || (_) || |  | (_| |      | | | || |   | |  | (_| || |_| | ]
--[  \___.___/  \___/ |_|   \__,_|      |_| |_||_|   |_|   \__,_| \__, | ]
--[          ______                    _    _                      __/ | ]
--[         |  ____|                  | |  (_)                    |___/  ]
--[         | |__  _   _  _ __    ___ | |_  _   ___   _ __   ___         ]
--[         |  __|| | | || '_ \  / __|| __|| | / _ \ | '_ \ / __|        ]
--[         | |   | |_| || | | || (__ | |_ | || (_) || | | |\__ \        ]
--[         |_|    \__,_||_| |_| \___| \__||_| \___/ |_| |_||___/        ]
--[                                                                      ]
--]======================================================================]

--[==[
-- Splits the magnitude into three blocks used for Toom-Cook multiplication.
--
-- The parameter 'size' is the max size of the slice.
--
-- This function effectively does the same thing as `splitarrayblocks` except
-- this one always returns three blocks and it strips the leading zeros off
-- each slice.
--]==]
function splitmagtoomcook(mag, size)
   local maglength = #mag
   
   
   --[[ Copy the least-significant slice ]]
   local lowerslice = {}
   local lowersize = min(size, maglength)
   
   for i = 0, lowersize - 1 do
      lowerslice[lowersize - i] = mag[maglength - i]
   end
   
   
   --[[ Copy the middle slice ]]
   local middleslice = {}
   local middlesize = min(size, maglength - lowersize)
   
   for i = 0, middlesize - 1 do
      middleslice[middlesize - i] = mag[maglength - lowersize - i]
   end
   
   
   --[[ Copy the most significant slice ]]
   local upperslice = {}
   local uppersize = min(size, maglength - lowersize - middlesize)
   
   for i = 0, uppersize - 1 do
      upperslice[uppersize - i] = mag[maglength - lowersize - middlesize - i]
   end
   
   
   --[[ Strip the leading zeros off the slices and return them ]]
   return destructivestripleadingzeros(upperslice),
          destructivestripleadingzeros(middleslice),
          destructivestripleadingzeros(lowerslice)
end


--[==[
-- Destructively sign extends the provided word-array.
--]==]
function signextendwordarray(array, newlength)
   --[[ If no extra words, then exit ]]
   local signwords = newlength - #array
   
   if signwords <= 0 then
      return array
   end
   
   
   --[[ Shift up all the existing data words ]]
   for i = newlength, signwords + 1, -1 do
      array[i] = array[i - signwords]
   end
   
   
   --[[ Prepend the sign-words at the beginning ]]
   local signint = getwordarraysignword(array[1])
   
   for i = 1, signwords do
      array[i] = signint
   end
   
   
   return array
end



--[=====================[
--[ Strip Leading Zeros ]
--]=====================]

--[==[
-- Copies the entries of `source` into `destination` without any leading zeros.
--
-- If no leading zeros are being stripped, then it reduces to a copy function.
-- This is the "work" function; it does the work for the two entry functions.
-- It isn't called directly except by the entry functions.
--]==]
function stripleadingzerosto(source, destination)
   --[[
   -- Find the number of leading zeros. If the entire array was zeros, the 'if'
   -- inside the 'for' will never run and `difference` will never be set, thus
   -- `difference` is initialized to `length` for this case where the whole
   -- array needs to be stripped.
   --]]
   local length = #source
   local difference = length
   
   for i = 1, length do
      if source[i] ~= 0 then
         difference = i - 1
         break
      end
   end
   
   
   --[[ If no zeros are being stripped then copy the array ]]
   if difference == 0 then
      --[[ If the source and destination arrays are the same, don't copy ]]
      if source ~= destination then
         for i = 1, length do
            destination[i] = source[i]
         end
      end
      
      
      return destination
   end
   
   
   --[[ Calculate the endpoint of the destination array ]]
   local endpoint = length - difference
   
   
   --[[ Copy all the non-leading-zero words shifted up ]]
   for i = 1, endpoint do
      destination[i] = source[i + difference]
   end
   
   
   --[[ If the arrays are the same then nullify the remaining entries ]]
   if destination == source then
      for i = endpoint + 1, length do
         destination[i] = nil
      end
   end
   
   
   return destination
end


--[==[
-- Strips the leading zeros of the array and puts the results in a new array.
--
-- If no zeros are to be stripped this returns a copy of the original array.
-- This is one of the entry functions.
--]==]
function copyandstripleadingzeros(array)
   return stripleadingzerosto(array, {})
end


--[==[
-- Destructively strips the leading zeros of the array.
--
-- If no zeros are to be stripped this does nothing and just returns the array.
-- This is one of the entry functions.
--]==]
function destructivestripleadingzeros(array)
   return stripleadingzerosto(array, array)
end



--[==========[
--[ Negation ]
--]==========]

--[==[
-- Performs a Two's complement negation on the word-array in `source` and puts
-- the result into `destination`.
--
-- This is the "work" function; it does the work for the two entry functions.
-- It isn't called directly except by the entry functions.
--]==]
function negatewordarrayto(source, destination)
   local length = #source
   
   
   --[[ Initialize `addend` as the 1 to add after flipping the bits ]]
   local addend = 1
   
   
   --[[ Loop through each word, flip the bits, and add 1 ]]
   for i = length, 1, -1 do
      addend, destination[i] = splitlong(bitnot(source[i]) + addend)
   end
   
   
   --[[ Clean the number up and return ]]
   return destructivestripleadingzeros(destination)
end


--[==[
-- Arithmetically negates the word-array and puts the results in a new array.
--
-- This is one of the entry functions.
--]==]
function copyandnegatewordarray(array)
   return negatewordarrayto(array, {})
end


--[==[
-- Destructively arithmetically negates the word-array.
--
-- This is one of the entry functions.
--]==]
function destructivenegatewordarray(array)
   return negatewordarrayto(array, array)
end



--[============[
--[ Left Shift ]
--]============]

--[==[
-- Performs a left shift on the magnitude in `mag` by the number of bits
-- specified in `displacement` and puts the result into `destination`.
--
-- This function assumes `displacement` is non-negative and no greater than
-- `maxinteger` (2^51).
--
-- This is the "work" function; it does the work for the two entry functions.
-- It isn't called directly except by the entry functions.
--]==]
function leftshiftmagnitudeto(mag, displacement, destination)
   --[[ If no movement necessary, don't do anything ]]
   if displacement <= 0 then
      if destination ~= mag then
         clearandcopyintoarray(destination, mag)
      end
      
      return destination
   end
   
   
   --[[ Get number of extra words and number of bits to shift every word by ]]
   local numberofwords, numberofbits = splitlongtowordsandbits(displacement)
   
   
   --[[ Shift every word left by multiplying by the shift multiplier ]]
   local maglength = #mag
   
   if numberofbits ~= 0 then
      local shiftmultiplier = bitleftshift(1, numberofbits)
      local carry = 0
      
      for i = maglength, 1, -1 do
         carry, destination[i] = intmultiplyint(mag[i], shiftmultiplier, carry)
      end
      
      
      --[[ Account for overflow ]]
      if carry ~= 0 then
         tableinsert(destination, 1, carry)
      end
   end
   
   
   --[[ Append zeros to least significant words to shift in multiples of 32 ]]
   for i = 1, numberofwords do
      destination[maglength + i] = 0
   end
   
   
   return destination
end


--[==[
-- Left shifts the magnitude by the number of bits determined by `displacement`
-- and returns the result in a new magnitude.
--
-- If the displacement is zero, this function just returns a copy of `mag`.
--]==]
function copyandleftshiftmagnitude(mag, displacement)
   return leftshiftmagnitudeto(mag, displacement, {})
end


--[==[
-- Destructively left shifts the magnitude by the number of bits determined by
-- the displacement value.
--
-- If the displacement is zero, this function doesn't do anything.
--]==]
function destructiveleftshiftmagnitude(mag, displacement)
   return leftshiftmagnitudeto(mag, displacement, mag)
end


--[=============[
--[ Right Shift ]
--]=============]

--[==[
-- Performs a right shift on the magnitude in `mag` by the number of bits
-- specified in `displacement` and puts the result into `destination`.
--
-- This function assumes `displacement` is non-negative and no greater than
-- `maxinteger` (2^51).
--
-- This is the "work" function; it does the work for the two entry functions.
-- It isn't called directly except by the entry functions.
--]==]
function rightshiftmagnitudeto(mag, displacement, destination)
   --[[ If no movement necessary, don't do anything ]]
   if displacement <= 0 then
      if destination ~= mag then
         clearandcopyintoarray(destination, mag)
      end
      
      return destination
   end
   
   
   --[[ If the shift amount exceeds the length of the magnitude, clear it ]]
   local numberofwords, numberofbits = splitlongtowordsandbits(displacement)
   local maglength = #mag
   
   if numberofwords >= maglength then
      return cleararray(destination)
   end
   
   
   --[[ Remove the number of words first ]]
   if destination == mag then
      for i = maglength, maglength - numberofwords + 1 do
         destination[i] = nil
      end
   end
   
   maglength = maglength - numberofwords
   
   
   --[[
   -- Right shift each word by left shifting to split the long and taking the
   -- highest bits
   --]]
   local shiftmultiplier = bitleftshift(1, 32 - numberofbits)
   local carry = 0
   local oldcarry = 0
   
   if numberofbits ~= 0 then
      for i = 1, maglength do
         lowbits, carry = intmultiplyint(mag[i], shiftmultiplier, 0)
         destination[i] = lowbits + oldcarry
         oldcarry = carry
      end
   end
   
   
   --[[ After this process there will be no more than one leading zero word ]]
   if destination[1] == 0 then
      tableremove(destination, 1)
   end
   
   
   return mag
end


--[==[
-- Right shifts the magnitude by the number of bits determined by
-- `displacement` and returns the result in a new magnitude.
--
-- If the displacement is zero, this function just returns a copy of `mag`.
--]==]
function copyandrightshiftmagnitude(mag, displacement)
   return rightshiftmagnitudeto(mag, displacement, {})
end


--[==[
-- Destructively right shifts the magnitude by the number of bits determined by
-- the displacement value.
--
-- If the displacement is zero, this function doesn't do anything.
--]==]
function destructiverightshiftmagnitude(mag, displacement)
   return rightshiftmagnitudeto(mag, displacement, mag)
end


--[============[
--[ Bit Bounds ]
--]============]

--[==[
-- Finds the most-significantly set bit and returns the position as a
-- zero-indexed, little-endian index (that is to say the least-significant bit
-- is bit 0), or `-1` if the array is equal to 0.
--]==]
function gethighestsetbit(mag)
   local length = #mag
   
   
   --[[ Loop through each word from the most-significant ]]
   for i = 1, length do
      --[[ If the word has set bits (is non-zero) ... ]]
      if mag[i] ~= 0 then
         --[[ ... get the highest bit and return its index (using math) ]]
         return (length - i + 1) * 32 - numberofleadingzeros(mag[i]) - 1
      end
   end
   
   
   --[[ If length is 0 or the whole array is all zero-words, return -1 ]]
   return -1
end


--[==[
-- Finds the least-significantly set bit and returns the position as a
-- zero-indexed, little-endian index (that is to say the least-significant bit
-- is bit 0), or `-1` if the array is equal to 0.
--]==]
function getlowestsetbit(array)
   local length = #array
   
   
   --[[ Loop through each word from the least-significant ]]
   for i = length, 1, -1 do
      --[[ If the word has set bits (is non-zero) ... ]]
      if array[i] ~= 0 then
         --[[ ... get the lowest bit and return its index (using math) ]]
         return (length - i) * 32 + numberoftrailingzeros(array[i])
      end
   end
   
   
   --[[ If length is 0 or the whole array is all zero-words, return -1 ]]
   return -1
end



--[=====[
--[ Add ]
--]=====]

--[==[
-- Adds the values of the two magnitudes and puts the result in `destination`.
--
-- This is the "work" function; it does the work for the two entry functions.
-- It isn't called directly except by the entry functions.
--]==]
function addmagnitudesto(thismag, thatmag, destination)
   --[[ Cache the lengths of the inputs; output will be the longest length ]]
   local thislength = #thismag
   local thatlength = #thatmag
   local longerlength = max(thislength, thatlength)
   
   
   --[[
   -- Starting at the least significant word for each input magnitude, add the
   -- corresponding words from both magnitudes with any leftover carry value
   -- and put the resulting word in `thismag` at the index with respect to the
   -- longer length.
   --]]
   local carry = 0
   
   for i = 0, longerlength - 1 do
      carry, destination[longerlength - i] = splitlong(
            --[[ Sign-extend (0) if the word is above most significant word ]]
            (thismag[thislength - i] or 0)
                  + (thatmag[thatlength - i] or 0)
                  + carry)
   end
   
   
   --[[ If the addition overflows, add the overflow ]]
   if carry ~= 0 then
      tableinsert(destination, 1, carry)
   end
   
   
   return destination
end


--[==[
-- Adds the contents of the two magnitudes and returns a new magnitude with the
-- sum.
--
-- This is one of the entry functions.
--]==]
function copyandaddmagnitudes(thismag, thatmag)
   return addmagnitudesto(thismag, thatmag, {})
end


--[==[
-- Destructively adds the contents of the two magnitudes and puts the result in
-- the first one (`thismag`).
--
-- This is one of the entry functions.
--]==]
function destructiveaddmagnitudes(thismag, thatmag)
   return addmagnitudesto(thismag, thatmag, thismag)
end


--[==[
-- Destructively increments the magnitude.
--]==]
function destructiveincrementmagnitude(mag)
   --[[ For each word, propagate the one until not adding it anymore ]]
   for i = #mag, 1, -1 do
      mag[i] = (mag[i] + 1) % 0x100000000
      
      
      --[[ If the resulting word is 0, then the addition overflowed ]]
      if mag[i] ~= 0 then
         break
      end
   end
   
   
   --[[ If mag[1] == 0 then every word overflowed ]]
   if mag[1] == 0 then
      tableinsert(mag, 1, 1)
   end
   
   
   return mag
end


--[==[
-- Increments the magnitude and returns a new magnitude with the result.
--]==]
function copyandincrementmagnitude(thismag)
   return destructiveincrementmagnitude(copyarray(thismag))
end



--[==========[
--[ Subtract ]
--]==========]

--[==[
-- Finds the absolute difference between the two magnitudes and puts the result
-- in `destination`.
--
-- This uses the Austrian Method fo calculating the difference:
-- https://en.wikipedia.org/wiki/Subtraction#Austrian_method
--
-- This is the "work" function; it does the work for the two entry functions.
-- It isn't called directly except by the entry functions.
--]==]
function subtractmagnitudesto(thismag, thatmag, destination)
   --[[ Get the larger and smaller of the two magnitudes ]]
   local cmp = comparemagnitudes(thismag, thatmag)
   
   local larger, smaller
   
   if cmp == 0 then
      --[[ Shortcut return if they equal ]]
      return cleararray(thismag)
   
   elseif cmp < 0 then
      --[[ thismag < thatmag ]]
      smaller = thismag
      larger = thatmag
   
   else
      --[[ thismag >= thatmag ]]
      smaller = thatmag
      larger = thismag
   end
   
   
   --[[ Cache the lengths ]]
   local largerlength = #larger
   local smallerlength = #smaller
   
   
   --[[
   -- Word-by-word, from the least significant, find the difference between
   -- corresponding words of the two magnitudes and put the result in thismag
   --]]
   local borrow = 0
   local difference = 0
   
   for i = 0, largerlength - 1 do
      difference = (larger[largerlength - i] or 0) -
                   (smaller[smallerlength - i] or 0) -
                   borrow
      
      
      --[[ If the subtraction requires borrowing, borrow from the next word ]]
      if difference < 0 then
         borrow = 1
      else
         borrow = 0
      end
      
      
      --[[ Store the positive, 32-bit constrained value of the difference ]]
      destination[largerlength - i] = difference % 0x100000000
   end
   
   
   --[[ Clean up and return ]]
   return destructivestripleadingzeros(destination)
end


--[==[
-- Finds the absolute difference of the two magnitudes and returns a new
-- magnitude with the difference.
--]==]
function copyandsubtractmagnitudes(thismag, thatmag)
   return subtractmagnitudesto(thismag, thatmag, {})
end


--[==[
-- Destructively finds the absolute difference between `thatmag` and
-- `thismag` and puts the result in `thismag`.
--]==]
function destructivesubtractmagnitudes(thismag, thatmag)
   return subtractmagnitudesto(thismag, thatmag, thismag)
end


--[==[
-- Destructively decrements the magnitude.
--]==]
function destructivedecrementmagnitude(mag)
   --[[ Subtracting from zero, but negatives aren't allowed, so return 1 ]]
   if #mag == 0 then
      mag[1] = 1
      
      return mag
   end
   
   
   --[[ For each word, propagate the one until not adding it anymore ]]
   for i = #mag, 1, -1 do
      --[[ If we need to borrow, keep looping ]]
      if mag[i] == 0 then
         mag[i] = 0xffffffff
      
      --[[ Otherwise, subtract 1 and break out ]]
      else
         mag[i] = mag[i] - 1
         break
      end
   end
   
   
   --[[ Clean up and return ]]
   return destructivestripleadingzeros(mag)
end


--[==[
-- Decrements the magnitude and returns a new magnitude with the result.
--]==]
function copyanddecrementmagnitude(thismag)
   return destructivedecrementmagnitude(copyarray(thismag))
end




--[===========================================[
--[   _____        _    _                     ]
--[  / ____|      | |  | |                    ]
--[ | |  __   ___ | |_ | |_   ___  _ __  ___  ]
--[ | | |_ | / _ \| __|| __| / _ \| '__|/ __| ]
--[ | |__| ||  __/| |_ | |_ |  __/| |   \__ \ ]
--[  \_____| \___| \__| \__| \___||_|   |___/ ]
--[                                           ]
--]===========================================]

--[======[
--[ Sign ]
--]======]

--[==[
-- Returns the sign of the word-array.
--]==]
function getwordarraysign(array)
   --[[ Shortcut return ]]
   if #array == 0 then
      return 0
   end
   
   
   --[[ Only the first word (the sign-word) can indicate if it's negative ]]
   if array[1] >= negativemask then
      return -1
   end
   
   
   --[[
   -- At this point, the word-array is non-negative, so if any word is non-zero
   -- then the word-array must be positive. Otherwise it's all zeros.
   --]]
   for i = 1, #array do
      if array[i] ~= 0 then
         return 1
      end
   end
   
   
   return 0
end


--[==[
-- Returns the sign of the integer.
--]==]
function getintegersign(int)
   return (int < 0 and -1) or (int > 0 and 1) or 0
end


--[==[
-- Returns the sign of any operable value.
--
-- Don't use this function if you're also getting the magnitude at the same
-- time.
--]==]
function getsign(value, valuetype)
   --[[ Figure out what type the value is and call the associated function ]]
   if valuetype == 'biginteger' then
      return value.sign
      
   elseif valuetype == 'word-array' then
      return getwordarraysign(value)
      
   elseif valuetype == 'integer' then
      return getintegersign(value)
   end
   
   
   --[[ Precautionary error that should not run ]]
   error("cannot obtain sign of " .. valuetype)
end



--[===========[
--[ Sign-Word ]
--]===========]

--[==[
-- Returns the sign-word of the word-array.
--]==]
function getwordarraysignword(array)
   --[[ If the array is negative, return the negative sign-word ]]
   if array[1] and array[1] >= negativemask then
      return 0xffffffff
   end
   
   
   --[[
   -- Otherwise, if the length is zero or the most significant word isn't
   -- negative, then return the non-negative sign-word (zero).
   --]]
   return 0
end


--[==[
-- Returns the sign-word of the integer.
--]==]
function getintegersignword(int)
   return (int < 0) and 0xffffffff or 0
end



--[===========[
--[ Magnitude ]
--]===========]

--[==[
-- Returns a copy of the magnitude of the word-array.
--
-- This returns a copy every single time it's called, so don't call it more
-- than you need to.
--]==]
function getwordarraymagnitude(array)
   if getwordarraysign(array) == -1 then
      return copyandnegatewordarray(array)
   end
   
   
   return copyandstripleadingzeros(array)
end


--[==[
-- Returns a magnitude for the integer.
--
-- This generates a magnitude on-the-fly every time it's called (no
-- memoization), so don't call it more than you need to.
--]==]
function getintegermagnitude(int)
   local highword, lowword = splitlong(abs(int))
   
   
   if highword == 0 then
      if lowword == 0 then
         --[[ int == 0 ]]
         return {}
      end
      
      
      --[[ 0 < int < 2^32 ]]
      return {lowword}
   end
   
   
   --[[ int >= 2^32 ]]
   return {highword, lowword}
end


--[==[
-- Returns a copy of the magnitude of any operable value.
--
-- This returns a copy of the magnitude every time it's run. Don't use this
-- function if you already have the magnitude or if you're also getting the
-- sign at the same time.
--]==]
function getmagnitude(value, valuetype)
   --[[ Figure out what type the value is and call the associated function ]]
   if valuetype == 'biginteger' then
      return copyarray(value.magnitude)
      
   elseif valuetype == 'word-array' then
      return getwordarraymagnitude(value)
      
   elseif valuetype == 'integer' then
      return getintegermagnitude(value)
   end
   
   
   --[[ Precautionary error that should not run ]]
   error("cannot obtain magnitude of " .. valuetype)
end



--[====================[
--[ Sign and Magnitude ]
--]====================]

--[==[
-- Returns both the sign and a copy of the magnitude of the word-array.
--]==]
function getwordarraysignandmagnitude(array)
   local sign = getwordarraysign(array)
   
   
   if sign == -1 then
      return sign, copyandnegatewordarray(array)
   end
   
   
   return sign, copyandstripleadingzeros(array)
end


--[==[
-- Returns both the sign and a magnitude for the integer.
--]==]
function getintegersignandmagnitude(int)
   return getintegersign(int), getintegermagnitude(int)
end


--[==[
-- Returns both the sign and magnitude of any operable value.
--]==]
function getsignandmagnitude(value, valuetype)
   --[[ Figure out what type the value is and call the associated function ]]
   if valuetype == 'biginteger' then
      return value.sign, copyarray(value.magnitude)
      
   elseif valuetype == 'word-array' then
      return getwordarraysignandmagnitude(value)
      
   elseif valuetype == 'integer' then
      return getintegersignandmagnitude(value)
   end
   
   
   --[[ Precautionary error that should not run ]]
   error("cannot obtain sign and magnitude of " .. valuetype)
end



--[============[
--[ Word-Array ]
--]============]

--[==[
-- Returns a word-array with the value of the magnitude and the passed sign.
--]==]
function getsignmagnitudewordarray(sign, mag)
   local wordarray
   
   
   if sign == -1 then
      --[[ Word-array needs to be negative, so negate (surprisingly) ]]
      wordarray = copyandnegatewordarray(mag)
      
      
      --[[ Ensure the word-array will be interpreted as negative ]]
      if wordarray[1] < negativemask then
         tableinsert(wordarray, 1, 0xffffffff)
      end
   
   else
      --[[ Otherwise return a copy ]]
      wordarray = copyarray(mag)
      
      
      --[[ Ensure the word-array will be interpreted as positive ]]
      if wordarray[1] and wordarray[1] >= negativemask then
         tableinsert(wordarray, 1, 0)
      end
   end
   
   
   return wordarray
end


--[==[
-- Returns a word-array that equals the value of the passed int.
--]==]
function getintegerwordarray(int)
   local mag = getintegermagnitude(int)
   
   
   if int > 0 then
      if mag[1] >= negativemask then
         tableinsert(mag, 1, 0)
      end
   
   elseif int < 0 then
      if mag[2] then
         if mag[2] == 0 then
            mag[1] = bitnot(mag[1]) + 1
         else
            mag[1] = bitnot(mag[1])
            mag[2] = bitnot(mag[2]) + 1
         end
      else
         mag[1] = bitnot(mag[1]) + 1
      end
      
      if mag[1] < negativemask then
         tableinsert(mag, 1, 0xffffffff)
      end
   end
   
   
   return mag
end


--[==[
-- Returns a word-array that equals the value of the passed value.
--
-- If the value is already a word-array then this returns a copy of it.
--]==]
function getwordarray(value, valuetype)
   --[[ Figure out what type the value is and call the associated function ]]
   if valuetype == 'biginteger' then
      return getsignmagnitudewordarray(value.sign, value.magnitude)
      
   elseif valuetype == 'word-array' then
      return copyarray(value)
      
   elseif valuetype == 'integer' then
      return getintegerwordarray(value)
   end
   
   
   --[[ Precautionary error that should not run ]]
   error("cannot obtain sign and magnitude of " .. valuetype)
end




--[===========================================================================[
--[   _____                    _                       _                      ]
--[  / ____|                  | |                     | |                     ]
--[ | |      ___   _ __   ___ | |_  _ __  _   _   ___ | |_   ___   _ __  ___  ]
--[ | |     / _ \ | '_ \ / __|| __|| '__|| | | | / __|| __| / _ \ | '__|/ __| ]
--[ | |____| (_) || | | |\__ \| |_ | |   | |_| || (__ | |_ | (_) || |   \__ \ ]
--[  \_____|\___/ |_| |_||___/ \__||_|    \__,_| \___| \__| \___/ |_|   |___/ ]
--[                                                                           ]
--]===========================================================================]

--[==[
-- The one, central function that creates a valid biginteger.
--
-- Currently this function just makes a table with a sign and magnitude, but
-- in the future it will use metatables and such in the construction of
-- bigintegers.
--]==]
function createbiginteger(sign, mag)
   return {sign = sign, magnitude = mag}
end


--[==[
-- Constructs a biginteger from a regular Lua integer.
--]==]
function constructorinteger(int)
   assert(isvalidinteger(int))
   
   return createbiginteger(getintegersignandmagnitude(int))
end


--[==[
-- Constructs a biginteger from a sign and a user-specified magnitude.
--]==]
function constructorsignmagnitude(sign, mag)
   assert(isvalidsignmagnitudecombination(sign, mag))
   
   return createbiginteger(sign, copyarray(mag))
end


--[==[
-- Constructs a biginteger of a given bitlength and RNG function.
--
-- For every 32-bit word, this function calls the RNG function twice: once for
-- the upper 16 bits, another for the lower 16 bits. This is because the
-- default `math.random()` function has a weird behavior in that it randomizes
-- only 31 bits. If you did `math.random() * 0x100000000` you would get only
-- even numbers since the least-significant bit will never be set.
--
-- If you need a randomly generated biginteger, I recommend creating your own
-- function. This function is here mainly to keep parallels to Java's
-- BigInteger constructors.
--]==]
function constructorbitsrng(bitlength, randomnumbergenerator)
   assert(isvalidbitindex(bitlength))
   
   
   local numberofwords = floor((bitlength + 31) / 32)
   local mag = {}
   
   for i = 1, numberofwords do
      --[[
      -- This weird multiplication-addition is necessary since the default
      -- math.random would not operate on all 32 bits
      --]]
      mag[i] = floor(randomnumbergenerator() * 0x10000) * 0x10000 +
               floor(randomnumbergenerator() * 0x10000)
   end
   
   
   --[[ Truncate the highest word to the number of extra bits needed ]]
   local excessbits = bitlength % 32
   
   if excessbits ~= 0 then
      mag[1] = bitand(mag[1], 2 ^ excessbits - 1)
   end
   
   
   destructivestripleadingzeros(mag)
   
   
   return createbiginteger(1, mag)
end


--[==[
-- Constructs a biginteger from a trusted word-array. Used internally only.
--]==]
function constructorwordarraytrusted(array)
   assert(isvalidwordarray(array))
   
   
   --[[ Use the word-array as the magnitude object ]]
   local sign = getwordarraysign(array)
   
   
   --[[ Negate if needed, but otherwise strip any leading zeros ]]
   if sign == -1 then
      destructivenegatewordarray(array)
   else
      destructivestripleadingzeros(array)
   end
   
   
   return createbiginteger(sign, array)
end


--[==[
-- Constructs a biginteger from a user-specified word-array.
--]==]
function constructorwordarray(array)
   return createbiginteger(getwordarraysignandmagnitude(array))
end


--[==[
-- Destructively multiplies the magnitude by the factor and adds the addend.
--
-- Used internally only for construction with strings.
--]==]
function destructivemultiplyandadd(mag, factor, addend)
   --[[ Run the multiplication on the magnitude ]]
   local maglength = #mag
   local carry = 0
   
   for i = maglength, 1, -1 do
      carry, mag[i] = intmultiplyint(factor, mag[i], carry)
   end
   
   
   --[[ If the multiplication overflows, add the overflow ]]
   if carry ~= 0 then
      tableinsert(mag, 1, carry)
   end
   
   
   --[[ Add the addend and carry until we're not carrying anything anymore ]]
   carry = addend
   
   for i = maglength, 1, -1 do
      if carry == 0 then
         break
      end
      
      carry, mag[i] = splitlong(mag[i] + carry)
   end
   
   
   --[[ If the addition overflows, add the overflow ]]
   if carry ~= 0 then
      tableinsert(mag, 1, carry)
   end
   
   
   return mag
end


--[==[
-- Constructs a biginteger from a string encoding an integer and a provided
-- radix.
--
-- This function is based on the constructor in the Java implementation of
-- BigInteger. There are some changes made in the startup logic and the
-- implementation details, but the rest of the algorithm remains the same.
--
-- The algorithm works by first dividing the string into groups of digits
-- (similar to how a magnitude or word-array is divided into words). Then, with
-- an accumulator, for each group from most to least significant, multiply the
-- value in the accumulator by the base and add the value of the group.
--]==]
function constructorstringradix(str, radix)
   assert(isvalidradix(radix))
   assert(isvalidstringnumber(str, radix))
   
   
   --[[ Shortcut return if the string is all zeros ]]
   if stringmatch(str, '^[-+]?0+$') then
      return createbiginteger({}, 0)
   end
   
   
   --[[ Get the sign of the integer in the string ]]
   local sign = stringmatch(str, '^-') and -1 or 1
   
   
   --[[ Skip all leading zeros and get the starting index of the rest ]]
   local _, cursor = stringfind(str, '^[-+]?0*')
   cursor = cursor + 1
   
   
   --[[ Calculate the number of remaining digits of the string ]]
   local strlength = #str
   local numberofdigits = strlength - cursor + 1
   
   
   --[[ Estimate whether the number would cause the biginteger to overflow ]]
   local numberofbits = floor(numberofdigits * bitsperdigit[radix] / 1024) + 1
   
   assert(numberofbits + 31 <= maxinteger,
         "biginteger would overflow supported range")
   
   
   --[[ Cache the values for quick access later ]]
   local digitsperintegerradix = digitsperinteger[radix]
   local superradix = intradix[radix]
   
   
   --[[
   -- Get the number of digits in the first group, which may be short.
   --
   -- For example, suppose the string is "mlkjihgfedcba":
   -- If the radix is 36, `digitsperinteger[36]` = 5
   --
   --     mlk jihgf edcba
   --     ^^^
   --     first group
   --
   -- If the radix is 25, `digitsperinteger[25]` = 6
   --
   --     m lkjihg fedcba
   --     ^
   --     first group
   --]]
   local firstgrouplength = numberofdigits % digitsperintegerradix
   
   
   --[[ Process first group if there's an uneven number of digits ]]
   local mag = {}
   
   if firstgrouplength ~= 0 then
      --[[ Get the end index of the group ]]
      local endcursor = cursor + firstgrouplength
      
      
      --[[ Grab the substring, get the number value, and store it ]]
      mag[1] = tonumber(stringsub(str, cursor, endcursor - 1), radix)
      
      
      --[[ Shift the cursor up ]]
      cursor = endcursor
   end
   
   
   --[[ Process remaining groups ]]
   while cursor <= strlength do
      --[[ Get the end index of the group ]]
      local endcursor = cursor + digitsperintegerradix
      
      
      --[[ Grab the substring, get the number value, and add it ]]
      destructivemultiplyandadd(mag, superradix,
            tonumber(stringsub(str, cursor, endcursor - 1), radix))
      
      
      --[[ Shift the cursor up ]]
      cursor = endcursor
   end
   
   
   --[[ Clean up the magnitude and return a newly constructed biginteger ]]
   destructivestripleadingzeros(mag)
   
   
   return createbiginteger(sign, mag)
end


--[==[
-- Creates a deep copy of the passed biginteger object, in which the magnitudes
-- are different objects in memory but have the same values.
--
-- Once immutability is implemented and a smarter metatable system is in use,
-- this function will go away as it will be useless.
--]==]
function clone(bigint)
   assert(isvalidbiginteger(bigint))
   
   return constructorsignmangitude(bigint.sign, bigint.magnitude)
end


--[==[
-- This is the Main Constructor
--
-- This will determine which constructor to call depending on the types of the
-- arguments passed in.
--
-- First Type      Second Type     Constructor
--   integer         nil             integer
--   integer         word-array      sign-magnitude
--   integer         function        bit-length and RNG
--   biginteger      nil             clone
--   word-array      nil             word-array
--   string          nil             string (radix 10)
--   string          integer         string-radix
--]==]
function biginteger(a, b)
   local typea = gettype(a)
   local typeb = gettype(b)
   
   if typea == 'integer' then
      if typeb == 'nil' then
         --[[ integer, nil ]]
         return constructorinteger(a)
      
      elseif typeb == 'word-array' then
         --[[ integer, word-array ]]
         return constructorsignmagnitude(a, b)
      
      elseif typeb == 'function' then
         --[[ integer, function ]]
         return constructorbitsrng(a, b)
      
      end
   elseif typea == 'biginteger' and typeb == 'nil' then
      --[[ biginteger, nil ]]
      return clone(a)
      
   elseif typea == 'word-array' and typeb == 'nil' then
      --[[ word-array, nil ]]
      return constructorwordarray(a)
      
   elseif typea == 'string' then
      if typeb == 'nil' then
         --[[ string, nil ]]
         return constructorstringradix(a, 10)
      
      elseif typeb == 'integer' then
         --[[ string, integer ]]
         return constructorstringradix(a, b)
      end
   end
   
   
   --[[ Anything other combination ]]
   error("could not understand passed parameters: " ..
      typea .. " and " .. typeb)
end




--[=====================================================[
--[   _____                                             ]
--[  / ____|                                            ]
--[ | |       ___   _ __ ___   _ __    __ _  _ __  ___  ]
--[ | |      / _ \ | '_ ` _ \ | '_ \  / _` || '__|/ _ \ ]
--[ | |____ | (_) || | | | | || |_) || (_| || |  |  __/ ]
--[  \_____| \___/ |_| |_| |_|| .__/  \__,_||_|   \___| ]
--[                           | |                       ]
--[                           |_|                       ]
--]=====================================================]

--[==[
-- Compares the values of `thismag` to `thatmag` and returns the sign of the
-- difference. Assumes the values are magnitudes, not word-arrays, so leading
-- sign-words will cause problems. For internal use only.
--
-- result < 0   ->   thismag < thatmag
-- result > 0   ->   thismag > thatmag
-- result = 0   ->   thismag = thatmag
--]==]
function comparemagnitudes(thismag, thatmag)
   local thislength = #thismag
   local thatlength = #thatmag
   
   
   --[[ If they're different lengths, they can't be equal ]]
   if thislength ~= thatlength then
      return thislength > thatlength and 1 or -1
   end
   
   
   --[[ They are the same size, so check word by word ]]
   for i = 1, thislength do
      --[[ If corresponding words are not equal, see if `thismag` is less ]]
      if thismag[i] ~= thatmag[i] then
         return thismag[i] > thatmag[i] and 1 or -1
      end
   end
   
   
   --[[ If they're the same length and all words equal, then they're equal ]]
   return 0
end


--[==[
-- Compares the two values represented by the sign-magnitude pairs and returns
-- the sign of the difference.
--]==]
function comparesignmagnitudes(thissign, thismag, thatsign, thatmag)
   --[[ If the signs differ, then they can't be equal ]]
   if thissign ~= thatsign then
      return thissign > thatsign and 1 or -1
   end
   
   
   --[[ Otherwise, compare the magnitudes ]]
   return comparemagnitudes(thismag, thatmag)
end


--[==[
-- Compares the two values after they have been checked by validity functions.
--]==]
function comparevalues(thisvalue, thistype, thatvalue, thattype)
   --[[
   -- Shortcut return
   --
   -- Note, we cannot use `thisvalue == thatvalue` or
   -- `equals(thisvalue, thatvalue)` because those might use this function
   -- underneath, which will cause circular recursion, which is bad. So, the
   -- two values may be equal in value and we wouldn't need to check, but this
   -- is the function to check that.
   --]]
   if rawequal(thisvalue, thatvalue) then
      return 0
   end
   
   
   --[[ Get the signs and magnitudes of each value ]]
   local thissign, thismag = getsignandmagnitude(thisvalue, thistype)
   local thatsign, thatmag = getsignandmagnitude(thatvalue, thattype)
   
   
   return comparesignmagnitudes(thissign, thismag, thatsign, thatmag)
end


--[==[
-- Compares the values of the two operable values and returns the sign of the
-- difference.
--
-- result < 0   ->   thisvalue < thatvalue
-- result > 0   ->   thisvalue > thatvalue
-- result = 0   ->   thisvalue = thatvalue
--]==]
function compare(thisvalue, thatvalue)
   local thistype, thattype, reason
         = arebothvalidoperablevalues(thisvalue, thatvalue, "comparison")
   
   assert(thistype, reason)
   
   return comparevalues(thisvalue, thistype, thatvalue, thattype)
end


--[==[
-- Compares the two magnitudes and returns whether they are equal in value. For
-- internal use only.
--]==]
function equalmagnitudes(thismag, thatmag)
   return comparemagnitudes(thismag, thatmag) == 0
end


--[==[
-- Compares the two values and returns whether they are equal. Returns `false`
-- by default if either value is non-operable.
--]==]
function equals(thisvalue, thatvalue)
   local thistype, thattype, _
         = arebothvalidoperablevalues(thisvalue, thatvalue, "")
   
   
   --[[ If either are not operable, then I can't be sure they're equal ]]
   if not thistype then
      return false
   end
   
   
   return comparevalues(thisvalue, thistype, thatvalue, thattype) == 0
end


--[==[
-- Returns the smallest value (closest to negative infinity) of a bunch of
-- operable values.
--
-- This function checks the operability of every value but does so in the same
-- pass as it compares all the values.
--]==]
function minimum(...)
   local list = {...}
   local valuetype, reason = isvalidoperablevalue(list[1])
   
   assert(valuetype, "bad argument #1: " .. reason)
   
   
   --[[ Keep the first value as our current smallest ]]
   local smallestsign, smallestmag = getsignandmagnitude(list[1], valuetype)
   local smallestindex = 1
   
   
   for i = 2, #list do
      --[[ For each remaining argument, validate first ]]
      local valuetype, reason = isvalidoperablevalue(list[i])
      
      assert(valuetype, "bad argument #" .. i .. ": " .. reason)
      
      
      --[[ Get the sign and magnitude and compare to the current smallest ]]
      valuesign, valuemag = getsignandmagnitude(list[i], valuetype)
      
      if comparesignmagnitude(
            valuesign, valuemag,
            smallestsign, smallestmag) < 0 then
         smallestsign = valuesign
         smallestmag = valuemag
         smallestindex = i
      end
   end
   
   
   --[[ Return the original item passed in using the saved index value ]]
   return list[smallestindex]
end


--[==[
-- Returns the largest value (closest to positive infinity) of a bunch of
-- operable values.
--
-- This function checks the operability of every value but does so in the same
-- pass as it compares all the values.
--]==]
function maximum(...)
   local list = {...}
   local valuetype, reason = isvalidoperablevalue(list[1])
   
   assert(valuetype, "bad argument #1: " .. reason)
   
   
   --[[ Keep the first value as our current largest ]]
   local largestsign, largestmag = getsignandmagnitude(list[1], valuetype)
   local largestindex = 1
   
   
   for i = 2, #list do
      --[[ For each remaining argument, validate first ]]
      valuetype, reason = isvalidoperablevalue(list[i])
      
      assert(valuetype, "bad argument #" .. i .. ": " .. reason)
      
      
      --[[ Get the sign and magnitude and compare to the current largest ]]
      local valuesign, valuemag = getsignandmagnitude(list[i], valuetype)
      
      if comparesignmagnitude(
            valuesign, valuemag,
            largestsign, largestmag) > 0 then
         largestsign = valuesign
         largestmag = valuemag
         largestindex = i
      end
   end
   
   
   --[[ Return the original item passed in using the saved index value ]]
   return list[largestindex]
end


--[==[
-- Returns both the smallest and largest values of a bunch of operable values.
--
-- This function checks the operability of every value but does so in the same
-- pass as it compares all the values. Call this function if you need both the
-- min and the max since this will halve the number validation checks from
-- calling both `minimum` and `maximum`.
--]==]
function minmax(...)
   local list = {...}
   local valuetype, reason = isvalidoperablevalue(list[1])
   
   assert(valuetype, "bad argument #1: " .. reason)
   
   
   --[[ Keep the first value as our current smallest and largest ]]
   local smallestsign, smallestmag = getsignandmagnitude(list[1], valuetype)
   local smallestindex = 1
   
   local largestsign, largestmag = smallestsign, smallestmag
   local largestindex = 1
   
   
   for i = 2, #list do
      --[[ For each remaining argument, validate first ]]
      valuetype, reason = isvalidoperablevalue(list[i])
      
      assert(valuetype, "bad argument #" .. i .. ": " .. reason)
      
      
      --[[ Get the sign and magnitude and compare to the current smallest ]]
      local valuesign, valuemag = getsignandmagnitude(list[i], valuetype)
      
      if comparesignmagnitude(
            valuesign, valuemag,
            smallestsign, smallestmag) < 0 then
         smallestsign = valuesign
         smallestmag = valuemag
         smallestindex = i
      end
      
      
      --[[ Also compare to the current largest ]]
      if comparesignmagnitude(
            valuesign, valuemag,
            largestsign, largestmag) > 0 then
         largestsign = valuesign
         largestmag = valuemag
         largestindex = i
      end
   end
   
   
   --[[ Return the original items passed in using the saved index values ]]
   return list[smallestindex], list[largestindex]
end




--[==============================================================[
--[            ____   _  _              _                        ]
--[           |  _ \ (_)| |            (_)                       ]
--[           | |_) | _ | |_ __      __ _  ___   ___             ]
--[           |  _ < | || __|\ \ /\ / /| |/ __| / _ \            ]
--[           | |_) || || |_  \ V  V / | |\__ \|  __/            ]
--[           |____/ |_| \__|  \_/\_/  |_||___/ \___|            ]
--[   ____                            _    _                     ]
--[  / __ \                          | |  (_)                    ]
--[ | |  | | _ __    ___  _ __  __ _ | |_  _   ___   _ __   ___  ]
--[ | |  | || '_ \  / _ \| '__|/ _` || __|| | / _ \ | '_ \ / __| ]
--[ | |__| || |_) ||  __/| |  | (_| || |_ | || (_) || | | |\__ \ ]
--[  \____/ | .__/  \___||_|   \__,_| \__||_| \___/ |_| |_||___/ ]
--[         | |                                                  ]
--[         |_|                                                  ]
--]==============================================================]

--[=============[
--[ Bitwise Not ]
--]=============]

--[==[
-- Performs a bitwise-not on the passed operable value and returns the result
-- in a new biginteger object.
--]==]
function bitwisenot(value)
   local valuetype, reason = isvalidoperablevalue(value)
   
   assert(valuetype, reason)
   
   
   --[[ Get the word-array and bitnot every word ]]
   local wordarray = getwordarray(value, valuetype)

   for i = 1, #wordarray do
      wordarray[i] = bitnot(wordarray[i])
   end
   
   
   --[[ `getwordarray` produces a copy, so we can trust it ]]
   return constructorwordarraytrusted(wordarray)
end


--[==[
-- Performs a bitwise-not in-place on the passed biginteger.
--
-- This function uses the fact that Two's complement negation is flipping the
-- bits and adding 1 to the magnitude to make bitwise-notting quick.
--]==]
function mutablebitwisenot(bigint)
   assert(isvalidbiginteger(bigint))
   
   
   --[[ No need to perform a bitnot on the whole magnitude ]]
   local mag = bigint.magnitude
   
   if bigint.sign == 0 then
      --[[ ~0 == -1 ]]
      bigint.sign = -1
      mag[1] = 1
   
   else
      if bigint.sign == 1 then
         --[[ positive -> negative, increment magnitude: ~1 == -2 ]]
         destructiveincrementmagnitude(mag)
      
      else
         --[[ negative -> positive, decrement magnitude: ~(-2) == 1 ]]
         destructivedecrementmagnitude(mag)
      end
      
      
      --[[ Cover bitnotting from -1 to 0 ]]
      if mag[1] then
         bigint.sign = -bigint.sign
      
      else
         bigint.sign = 0
      end
   end
   
   
   return bigint
end



--[=================[
--[ Generic Bitwise ]
--]=================]

--[==[
-- Performs the binary bitwise operation on the two operable values and returns
-- the result in a new biginteger value.
--]==]
function binarybitwise(thisvalue, thatvalue, bitwisefunction, opname)
   local thistype, thattype, reason
         = arebothvalidoperablevalues(
               thisvalue,
               thatvalue,
               "bitwise-" .. opname)
   
   assert(thistype, reason)
   
   
   --[[ Convert to word arrays ]]
   local thisarray = getwordarray(thisvalue, thistype)
   local thatarray = getwordarray(thatvalue, thattype)
   
   
   --[[ Cache the lengths and determine the longer length ]]
   local thislength = #thisarray
   local thatlength = #thatarray
   local longerlength = max(thislength, thatlength)
   
   
   --[[ Get the sign-words to sign extend the word-arrays ]]
   local thissignint = getwordarraysignword(thisarray)
   local thatsignint = getwordarraysignword(thatarray)
   
   
   --[[ Perform the bitwise function on every word, sign-extending if needed ]]
   local destination = {}
   
   for i = 0, longerlength - 1 do
      destination[longerlength - i] = bitwisefunction(
            thisarray[thislength - i] or thissignint,
            thatarray[thatlength - i] or thatsignint)
   end
   
   
   return constructorwordarraytrusted(destination)
end


--[==[
-- Performs a binary bitwise operation in-place on the passed biginteger and
-- operable value.
--
-- This function leverages Two's complement to perform an on-the-fly magnitude
-- negation if this biginteger is negative, or if the result is negative.
--]==]
function mutablebinarybitwise(thisbigint, thatvalue, bitwisefunction, opname)
   local thattype, reason
         = arevalidbigintegerandoperablevalue(
               thisbigint,
               thatvalue,
               "bitwise-" .. opname)
   
   assert(thattype, reason)
   
   
   --[[ Get the word arrays ]]
   local thismagnitude = thisbigint.magnitude
   local thatwordarray = getwordarray(thatvalue, thattype)
   
   
   --[[ Get the sign-words for the input and the result ]]
   local thissignint = getintegersignword(thisbigint.sign)
   local thatsignint = getwordarraysignword(thatwordarray)
   
   local finalsignint = bitwisefunction(thissignint, thatsignint)
   
   
   --[[ If the bigint is negative, decrement for two's complement ]]
   if thissignint == 0xffffffff then
      destructivedecrementmagnitude(thismagnitude)
   end
   
   
   --[[ Get the word array lengths ]]
   local thislen = #thismagnitude
   local thatlen = #thatwordarray
   local longerlen = max(thislen, thatlen)
   
   
   --[[ Branch on whether we need to negate this magnitude or the result ]]
   if thissignint == 0xffffffff then
      if finalsignint == 0xffffffff then
         --[[ Negate both this magnitude and the result ]]
         for i = 0, longerlen - 1 do
            thismagnitude[longerlen - i] = bitnot(bitwisefunction(
                  bitnot(thismagnitude[thislen - i] or 0),
                  thatwordarray[thatlen - i] or thatsignint))
         end
         
      else
         --[[ Negate just this magnitude ]]
         for i = 0, longerlen - 1 do
            thismagnitude[longerlen - i] = bitwisefunction(
                  bitnot(thismagnitude[thislen - i] or 0),
                  thatwordarray[thatlen - i] or thatsignint)
         end
      end
      
   else
      if finalsignint == 0xffffffff then
         --[[ Negate just the result ]]
         for i = 0, longerlen - 1 do
            thismagnitude[longerlen - i] = bitnot(bitwisefunction(
                  thismagnitude[thislen - i] or 0,
                  thatwordarray[thatlen - i] or thatsignint))
         end
         
      else
         --[[ Negate neither this magnitude nor the result ]]
         for i = 0, longerlen - 1 do
            thismagnitude[longerlen - i] = bitwisefunction(
                  thismagnitude[thislen - i] or 0,
                  thatwordarray[thatlen - i] or thatsignint)
         end
      end
   end
   
   destructivestripleadingzeros(thismagnitude)
   
   
   --[[ Update the bigint's sign ]]
   if finalsignint == 0xffffffff then
      thisbigint.sign = -1
      
      
      --[[ If this magnitude is now negative, increment for two's complement ]]
      destructiveincrementmagnitude(thismagnitude)
   
   else
      thisbigint.sign = thismagnitude[1] and 1 or 0
   end
   
   
   return thisbigint
end



--[=============[
--[ Bitwise And ]
--]=============]

--[==[
-- Performs a bitwise-and on the two operable values and returns the result in
-- a new biginteger value.
--]==]
function bitwiseand(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitand, "and")
end


--[==[
-- Performs a bitwise-and in-place on the passed biginteger and operable value.
--]==]
function mutablebitwiseand(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitand, "and")
end



--[=================[
--[ Bitwise And-Not ]
--]=================]

--[==[
-- Performs a bitwise-and-not on the two operable values and returns the result
-- in a new biginteger value.
--]==]
function bitwiseandnot(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitandnot, "and-not")
end


--[==[
-- Performs a bitwise-and-not in-place on the passed biginteger and operable
-- value.
--]==]
function mutablebitwiseandnot(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitandnot, "and-not")
end



--[============[
--[ Bitwise Or ]
--]============]

--[==[
-- Performs a bitwise-or on the two operable values and returns the result in a
-- new biginteger value.
--]==]
function bitwiseor(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitor, "or")
end


--[==[
-- Performs a bitwise-or in-place on the passed biginteger and operable value.
--]==]
function mutablebitwiseor(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitor, "or")
end



--[=============[
--[ Bitwise Xor ]
--]=============]

--[==[
-- Performs a bitwise-xor on the two operable values and returns the result in
-- a new biginteger value.
--]==]
function bitwisexor(thisvalue, thatvalue)
   return binarybitwise(thisvalue, thatvalue, bitxor, "xor")
end


--[==[
-- Performs a bitwise-xor in-place on the passed biginteger and operable value.
--]==]
function mutablebitwisexor(thisbigint, thatvalue)
   return mutablebinarybitwise(thisbigint, thatvalue, bitxor, "xor")
end




--[====================================================================[
--[  ____   _  _           _____  _      _   __  _    _                ]
--[ |  _ \ (_)| |         / ____|| |    (_) / _|| |  (_)               ]
--[ | |_) | _ | |_  ____ | (___  | |__   _ | |_ | |_  _  _ __    __ _  ]
--[ |  _ < | || __||____| \___ \ | '_ \ | ||  _|| __|| || '_ \  / _` | ]
--[ | |_) || || |_        ____) || | | || || |  | |_ | || | | || (_| | ]
--[ |____/ |_| \__|      |_____/ |_| |_||_||_|   \__||_||_| |_| \__, | ]
--[      ____                            _    _                  __/ | ]
--[     / __ \                          | |  (_)                |___/  ]
--[    | |  | | _ __    ___  _ __  __ _ | |_  _   ___   _ __   ___     ]
--[    | |  | || '_ \  / _ \| '__|/ _` || __|| | / _ \ | '_ \ / __|    ]
--[    | |__| || |_) ||  __/| |  | (_| || |_ | || (_) || | | |\__ \    ]
--[     \____/ | .__/  \___||_|   \__,_| \__||_| \___/ |_| |_||___/    ]
--[            | |                                                     ]
--[            |_|                                                     ]
--]====================================================================]

--[====================[
--[ Bitwise Left Shift ]
--]====================]

--[==[
-- Performs a bitwise left shift on the passed operable value by the number of
-- bits specified in `displacement` and returns a new result in a new
-- biginteger value.
--
-- `displacement` must be a valid bit-index, which, in short, is a non-negative
-- integer.
--]==]
function bitwiseleftshift(value, displacement)
   local valuetype, reason = isvalidoperablevalue(value)
   
   assert(valuetype, reason)
   assert(isvalidbitindex(displacement))
   
   
   --[[ Get the magnitude, shift, and return; quick and easy ]]
   local sign, mag = getsignandmagnitude(value, valuetype)
   destructiveleftshiftmagnitude(mag, displacement)
   
   return createbiginteger(sign, mag)
end


--[==[
-- Performs a bitwise left shift in-place on the passed biginteger object by
-- the number of bits specified in `displacement`.
--]==]
function mutablebitwiseleftshift(bigint, displacement)
   assert(isvalidbiginteger(bigint))
   assert(isvalidbitindex(displacement))
   
   
   --[[ Left shift directly on the magnitude ]]
   destructiveleftshiftmagnitude(bigint.magnitude, displacement)
   
   return bigint
end



--[=====================[
--[ Bitwise Right Shift ]
--]=====================]

--[==[
-- Performs a bitwise right shift on the passed operable value by the number of
-- bits specified in `displacement` and returns a new result in a new
-- biginteger value.
--
-- `displacement` must be a valid bit-index, which, in short, is a non-negative
-- integer. If the displacement is greater than the number of bits in the
-- magnitude, then this returns either 0 or -1, depending on the sign.
--]==]
function bitwiserightshift(value, displacement)
   local valuetype, reason = isvalidoperablevalue(value)
   
   assert(valuetype, reason)
   assert(isvalidbitindex(displacement))
   
   
   --[[ Get the magnitude and right shift ]]
   local sign, mag = getsignandmagnitude(value, valuetype)
   
   destructiverightshiftmagnitude(mag, displacement)
   
   
   --[[ If the result is zero change either sign or magnitude to be correct ]]
   if not mag[1] then
      --[[ Negative numbers right shifted all the way always equal -1 ]]
      if sign == -1 then
         mag[1] = 1
      
      --[[ Otherwise it's zero ]]
      else
         sign = 0
      end
   end
   
   return createbiginteger(sign, mag)
end


--[==[
-- Performs a bitwise right shift in-place on the passed biginteger object by
-- the number of bits specified in `displacement`.
--
-- If the displacement is greater than the number of bits in the magnitude,
-- then this returns either 0 or -1, depending on the sign.
--]==]
function mutablebitwiserightshift(bigint, displacement)
   assert(isvalidbiginteger(bigint))
   assert(isvalidbitindex(displacement))
   
   
   --[[ Do the right shift directly on the magnitude ]]
   local mag = bigint.magnitude
   
   destructiverightshift(mag, displacement)
   
   
   --[[ Change either the sign or magnitude if the result is zero ]]
   if not mag[1] then
      --[[ Negative numbers right shifted all the way always equal -1 ]]
      if biginteger.sign == -1 then
         mag[1] = 1
      
      --[[ Otherwise they're zero ]]
      else
         biginteger.sign = 0
      end
   end
   
   return biginteger
end




--[===============================================================[
--[      _____  _                _              ____   _  _       ]
--[     / ____|(_)              | |            |  _ \ (_)| |      ]
--[    | (___   _  _ __    __ _ | |  ___  ____ | |_) | _ | |_     ]
--[     \___ \ | || '_ \  / _` || | / _ \|____||  _ < | || __|    ]
--[     ____) || || | | || (_| || ||  __/      | |_) || || |_     ]
--[    |_____/ |_||_| |_| \__, ||_| \___|      |____/ |_| \__|    ]
--[   ____                 __/ |       _    _                     ]
--[  / __ \               |___/       | |  (_)                    ]
--[ | |  | | _ __    ___  _ __   __ _ | |_  _   ___   _ __   ___  ]
--[ | |  | || '_ \  / _ \| '__| / _` || __|| | / _ \ | '_ \ / __| ]
--[ | |__| || |_) ||  __/| |   | (_| || |_ | || (_) || | | |\__ \ ]
--[  \____/ | .__/  \___||_|    \__,_| \__||_| \___/ |_| |_||___/ ]
--[         | |                                                   ]
--[         |_|                                                   ]
--]===============================================================]

function destructivebitwiseatbit(wordarray, bitfromend, bitwisefunction)
   local word, bit, length
   
   word, bit = splitlongtowordsandbits(bitfromend)
   
   length = max(#wordarray, word + 1)
   
   signextendwordarray(wordarray, length)
   wordarray[length - word] = bitwisefunction(wordarray[length - word], bitleftshift(1, bit))
   
   return wordarray
end

function bitwiseatbit(value, bitfromend, bitwisefunction)
   local wordarray
   local valuetype, reason = isvalidoperablevalue(value)
   
   
   assert(valuetype, reason)
   assert(isvalidbitindex(bitfromend))
   
   wordarray = getwordarray(value, valuetype)
   destructivebitwiseatbit(wordarray, bitfromend, bitwisefunction)
   
   return constructorwordarraytrusted(wordarray)
end

function mutablebitwiseatbit(bigint, bitfromend, bitwisefunction)
   assert(isvalidbiginteger(bigint))
   assert(isvalidbitindex(bitfromend))
   
   destructiveconvertsignmagnitudetowordarray(bigint.sign, bigint.magnitude)
   destructivebitwiseatbit(bigint.magnitude, bitfromend, bitwisefunction)
   destructiveconvertwordarraytosignmagnitude(bigint.magnitude)
   
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
   local wordarray, length
   local word, bit
   local valuetype, reason = isvalidoperablevalue(value)
   
   assert(valuetype, reason)
   assert(isvalidbitindex(bitfromend))
   
   word, bit = splitlongtowordsandbits(bitfromend)
   wordarray = getwordarray(value, valuetype)
   length = #wordarray
   
   if word >= length then
      return getwordarraysign(wordarray) == -1
   end
   
   return bitand(wordarray[length - word], bitleftshift(1, bit)) ~= 0
end




--[======================================================================[
--[                         _____  _                                     ]
--[                        / ____|(_)                                    ]
--[                       | (___   _   __ _  _ __                        ]
--[                        \___ \ | | / _` || '_ \                       ]
--[                        ____) || || (_| || | | |                      ]
--[                       |_____/ |_| \__, ||_| |_|                      ]
--[  __  __             _  _   __  _   __/ |       _    _                ]
--[ |  \/  |           | |(_) / _|(_) |___/       | |  (_)               ]
--[ | \  / |  ___    __| | _ | |_  _   ___   __ _ | |_  _   ___   _ __   ]
--[ | |\/| | / _ \  / _` || ||  _|| | / __| / _` || __|| | / _ \ | '_ \  ]
--[ | |  | || (_) || (_| || || |  | || (__ | (_| || |_ | || (_) || | | | ]
--[ |_|  |_| \___/  \__,_||_||_|  |_| \___| \__,_| \__||_| \___/ |_| |_| ]
--[                                                                      ]
--]======================================================================]

function negate(value)
   local sign, magnitude
   local valuetype, reason = isvalidoperablevalue(value)
   
   
   assert(valuetype, reason)
   
   
   sign, magnitude = getsignandmagnitude(value, valuetype)
   
   
   return createbiginteger(-sign, magnitude)
end


function mutablenegate(bigint)
   assert(isvalidbiginteger(bigint))
   
   bigint.sign = -bigint.sign
   
   return bigint
end


function absolutevalue(value)
   local sign, magnitude
   local valuetype, reason = isvalidoperablevalue(value)
   
   
   assert(valuetype, reason)
   
   
   sign, magnitude = getsignandmagnitude(value, valuetype)
   
   
   return createbiginteger(sign == -1 and 1 or sign, magnitude)
end


function mutableabsolutevalue(bigint)
   assert(isvalidbiginteger(bigint))
   
   if bigint.sign == -1 then
      bigint.sign = 1
   end
   
   return bigint
end




--[====================================================[
--[    ___       _      _                          _   ]
--[   / _ \     | |    | |                        | |  ]
--[  | |_| |  __| |  __| |        __ _  _ __    __| |  ]
--[  |  _  | / _` | / _` |       / _` || '_ \  / _` |  ]
--[  | | | || (_| || (_| |      | (_| || | | || (_| |  ]
--[  |_| |_| \__,_| \__,_|       \__,_||_| |_| \__,_|  ]
--[   _____         _      _                      _    ]
--[  / ____|       | |    | |                    | |   ]
--[ | (___   _   _ | |__  | |_  _ __  __ _   ___ | |_  ]
--[  \___ \ | | | || '_ \ | __|| '__|/ _` | / __|| __| ]
--[  ____) || |_| || |_) || |_ | |  | (_| || (__ | |_  ]
--[ |_____/  \__,_||_.__/  \__||_|   \__,_| \___| \__| ]
--[                                                    ]
--]====================================================]

function add(thisvalue, thatvalue)
   local sign, mag
   local thissign, thismag
   local thatsign, thatmag
   local comparison
   local thistype, thattype, reason
         = arebothvalidoperablevalues(thisvalue, thatvalue, "addition")
   
   
   assert(thistype, reason)
   
   
   thissign, thismag = getsignandmagnitude(thisvalue, thistype)
   thatsign, thatmag = getsignandmagnitude(thatvalue, thattype)
   
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
   
   return createbiginteger(sign, mag)
end

function mutableadd(thisbigint, thatvalue)
   local thatsign, thatmag
   local comparison
   local thattype, reason
         = arevalidbigintegerandoperablevalue(
               thisbigint, thatvalue, "addition")
   
   
   assert(thattype, reason)
   
   
   thatsign, thatmag = getsignandmagnitude(thatvalue, thattype)
   
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


function subtract(thisvalue, thatvalue)
   local sign, mag
   local thissign, thatsign
   local thismag, thatmag
   local comparison
   
   local thistype, thattype, reason
         = arebothvalidoperablevalues(thisvalue, thatvalue, "subtraction")
   
   assert(thistype, reason)
   
   thissign, thismag = getsignandmagnitude(thisvalue, thistype)
   thatsign, thatmag = getsignandmagnitude(thatvalue, thattype)
   
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
   
   return createbiginteger(sign, mag)
end

function mutablesubtract(thisbigint, thatvalue)
   local thatsign, thatmag
   local comparison
   local thattype, reason
         = arevalidbigintegerandoperablevalue(
               thisbigint, thatvalue, "subtraction")
   
   assert(thattype, reason)
   
   thatsign, thatmag = getsignandmagnitude(thatvalue, thattype)
   
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




--[==========================================[
--[   _____                                  ]
--[  / ____|                                 ]
--[ | (___    __ _  _   _   __ _  _ __  ___  ]
--[  \___ \  / _` || | | | / _` || '__|/ _ \ ]
--[  ____) || (_| || |_| || (_| || |  |  __/ ]
--[ |_____/  \__, | \__,_| \__,_||_|   \___| ]
--[             | |                          ]
--[             |_|                          ]
--]==========================================]

function squarecolinplumb(mag)
--[[
--             a  b  c  d  e
--          *  a  b  c  d  e
--          ==================
--             ae be ce de EE
--          ad bd cd DD de
--       ac bc CC cd ce
--    ab BB bc bd be
-- AA ab ac ad ae
-- 
-- There is the diagonal:
--                         EE
--                   DD
--             CC
--       BB
-- AA
-- 
-- And two triangles of the same set of products
--             ae be ce de
--          ad bd cd
--       ac bc
--    ab                de
--                cd ce
--          bc bd be
--    ab ac ad ae
-- 
-- So diagonal + 2 * triangles
--]]
   local maglength, resultlength
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
      diagonal[index - 1], diagonal[index] = intmultiplyint(piece, piece, 0)
   end
   
   triangle = allocatearray(resultlength)
   
   for i = 1, maglength - 1 do
      for j = 0, i - 1 do
         index = resultlength - i - j
         producthigh, productlow = intmultiplyint(mag[#mag - j],
                                                                    mag[#mag - i],
                                                                    0)
         
         -- Add productlow to the corresponding triangle word and continue the
         -- carry up to extraint
         carry, triangle[index] = splitlong(triangle[index] + productlow * 2)
         extraint, producthigh = splitlong(producthigh * 2 + carry)
         
         -- Add producthigh to the next corresponding triangle word and continue
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
   
   return destructivestripleadingzeros(triangle)
end

function squarekaratsuba(mag)
--[[
-- let B be the arbitrary base and Xx be the number we're squaring where
--    Xx = X*B + x
-- 
-- Xx = X*B + x, so
-- Xx * Xx = (X*B + x)(X*B + x)
--         = X*X*B*B + X*B*x + x*X*B + x*x
--         = X^2*B^2 + 2*X*B*x + x^2
--         = ((X^2)*B + 2*X*x)*B + x^2
-- 
-- Since in this case B is a power of 2, multiplying by B is a leftshift
--]]
   local halfway, shiftup
   local upper, lower
   local uppersquared, lowersquared, innersquared
   local result
   
   halfway = floor((#mag + 1) / 2)
   shiftup = halfway * 32
   
   upper, lower = splitarray(mag, halfway)
   
   uppersquared = squaremagnitude(upper)
   lowersquared = squaremagnitude(lower)
   innersquared = destructiveleftshiftmagnitude(multiplymagnitudes(upper, lower), 1)
   
   destructiveleftshiftmagnitude(uppersquared, shiftup)
   destructiveaddmagnitudes(uppersquared, innersquared)
   destructiveleftshiftmagnitude(uppersquared, shiftup)
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
      
      _, productlow = intmultiplyint(w, 0xaaaaaaab, 0)
      mag[maglength - i] = productlow
      
      if productlow >= 0xaaaaaaab then
         borrow = borrow + 2
      elseif productlow >= 0x55555556 then
         borrow = borrow + 1
      end
   end
   
   return destructivestripleadingzeros(mag)
end

function squaretoomcook(mag)
   local a2, a1, a0, ss
   local v0, v1, v2, vm1, vinf, t1, t2, tm1, da1
   
   ss = floor((#mag + 2) / 3)
   
   a2, a1, a0 = splitmagtoomcook(mag, ss)
   
   
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
   destructiveleftshiftmagnitude(da1, 1)
   destructivesubtractmagnitudes(da1, a0)
   v2 = squaremagnitude(da1)
   
   
   
   -- t2 = v2.subtract(vm1).exactDivideBy3(); last instance of v2, so t2 = v2
   destructivesubtractmagnitudes(v2, vm1)
   destructiveexactdividebythree(v2)
   t2 = v2
   
   -- tm1 = v1.subtract(vm1).shiftRight(1);
   tm1 = copyandsubtractmagnitudes(v1, vm1)
   destructiverightshiftmagnitude(tm1, 1)
   
   -- t1 = v1.subtract(v0); last instance of v1, so t1 = v1
   destructivesubtractmagnitudes(v1, v0)
   t1 = v1
   
   -- t2 = t2.subtract(t1).shiftRight(1); mutable
   destructivesubtractmagnitudes(t2, t1)
   destructiverightshiftmagnitude(t2, 1)
   
   -- t1 = t1.subtract(tm1).subtract(vinf); mutable
   destructivesubtractmagnitudes(t1, tm1)
   destructivesubtractmagnitudes(t1, vinf)
   
   -- t2 = t2.subtract(vinf.shiftLeft(1)); mutable
   destructivesubtractmagnitudes(t2, copyandleftshiftmagnitude(vinf, 1))
   
   -- tm1 = tm1.subtract(t2); mutable
   destructivesubtractmagnitudes(tm1, t2)
   
   
   --return vinf.shiftLeft(ss).add(t2).shiftLeft(ss).add(t1).shiftLeft(ss).add(tm1).shiftLeft(ss).add(v0);
   destructiveleftshiftmagnitude(vinf, ss)
   destructiveaddmagnitudes(vinf, t2)
   destructiveleftshiftmagnitude(vinf, ss)
   destructiveaddmagnitudes(vinf, t1)
   destructiveleftshiftmagnitude(vinf, ss)
   destructiveaddmagnitudes(vinf, tm1)
   destructiveleftshiftmagnitude(vinf, ss)
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
   local valuetype, reason = isvalidoperablevalue(value)
   
   assert(valuetype, reason)
   
   sign, mag = getsignandmagnitude(value, valuetype)
   
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




--[=============================================[
--[  __  __         _  _    _         _         ]
--[ |  \/  |       | || |  (_)       | |        ]
--[ | \  / | _   _ | || |_  _  _ __  | | _   _  ]
--[ | |\/| || | | || || __|| || '_ \ | || | | | ]
--[ | |  | || |_| || || |_ | || |_) || || |_| | ]
--[ |_|  |_| \__,_||_| \__||_|| .__/ |_| \__, | ]
--[                           | |         __/ | ]
--[                           |_|        |___/  ]
--]=============================================]

function multiplycolinplumb(thismag, thatmag)
   local thislength, thatlength
   local resultlength, result
   local producthigh, productlow, carry
   local index, extraint
   
   thislength = #thismag
   thatlength = #thatmag
   resultlength = thislength + thatlength
   
   result = allocatearray(resultlength)
   
   for i = 0, thislength - 1 do
      for j = 0, thatlength - 1 do
         index = resultlength - i - j
         producthigh, productlow = intmultiplyint(thismag[thislength - i],
                                                                    thatmag[thatlength - j],
                                                                    0)
         
         -- Add productlow to the corresponding result word and continue the
         -- carry up to extraint
         carry, result[index] = splitlong(result[index] + productlow)
         extraint, producthigh = splitlong(producthigh + carry)
         
         -- Add producthigh to the next corresponding result word and continue
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
   
   return destructivestripleadingzeros(result)
end

function multiplykaratsuba(thismag, thatmag)
   local halfway, shiftup
   local thisupper, thislower
   local thatupper, thatlower
   local uppers, lowers, inners
   local result
   
   halfway = floor((max(#thismag, #thatmag) + 1) / 2)
   shiftup = halfway * 32
   
   thisupper, thislower = splitarray(thismag, halfway)
   thatupper, thatlower = splitarray(thatmag, halfway)
   
   uppers = multiplymagnitudes(thisupper, thatupper)
   lowers = multiplymagnitudes(thislower, thatlower)
   inners = destructiveaddmagnitudes(multiplymagnitudes(thisupper, thatlower),
                                     multiplymagnitudes(thislower, thatupper))
   
   destructiveleftshiftmagnitude(uppers, shiftup)
   destructiveaddmagnitudes(uppers, inners)
   destructiveleftshiftmagnitude(uppers, shiftup)
   destructiveaddmagnitudes(uppers, lowers)
   
   return uppers
end

function multiplytoomcook(thismag, thatmag)
   local a2, a1, a0, b2, b1, b0, ss, _
   local v0, v1, v2, vm1, vinf, t1, t2, tm1, da1, db1
   local vm1sign, v2sign
   -- This algorithm takes advantage of magnitude destruction to avoid making
   -- extra unnecessary arrays and biginteger objects. Only one number
   -- calculated has the potential to be negative (all others are non-negative),
   -- thus its sign is handled separately
   
   local longerlength = max(#thismag, #thatmag)
   
   ss = floor((longerlength + 2) / 3)
   
   -- All slices here are non-negative values
   a2, a1, a0 = splitmagtoomcook(thismag, ss)
   b2, b1, b0 = splitmagtoomcook(thatmag, ss)
   
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
   destructiveleftshiftmagnitude(da1, 1)
   
   destructivesubtractmagnitudes(da1, a0)
   
   destructiveaddmagnitudes(db1, b2)
   destructiveleftshiftmagnitude(db1, 1)
   
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
      -- v1 - -vm1 = v1 + vm1
      destructiveaddmagnitudes(vm1, v1)
   else
      -- this function returns the difference regardless of the order
      -- in this algorithm, tm1 will never be negative
      destructivesubtractmagnitudes(vm1, v1)
   end
   destructiverightshiftmagnitude(vm1, 1)
   tm1 = vm1
   
   -- t1 = v1.subtract(v0); last instance of v1, so t1 = v1
   destructivesubtractmagnitudes(v1, v0)
   t1 = v1
   
   -- t2 = t2.subtract(t1).shiftRight(1);
   destructivesubtractmagnitudes(t2, t1)
   destructiverightshiftmagnitude(t2, 1)
   
   -- t1 = t1.subtract(tm1).subtract(vinf);
   destructivesubtractmagnitudes(t1, tm1)
   destructivesubtractmagnitudes(t1, vinf)
   
   -- t2 = t2.subtract(vinf.shiftLeft(1));
   destructivesubtractmagnitudes(t2, copyandleftshiftmagnitude(vinf, 1))
   
   -- tm1 = tm1.subtract(t2);
   destructivesubtractmagnitudes(tm1, t2)
   
   -- return vinf.shiftLeft(ss).add(t2).shiftLeft(ss).add(t1).shiftLeft(ss).add(tm1).shiftLeft(ss).add(v0);
   destructiveleftshiftmagnitude(vinf, ss)
   destructiveaddmagnitudes(vinf, t2)
   destructiveleftshiftmagnitude(vinf, ss)
   destructiveaddmagnitudes(vinf, t1)
   destructiveleftshiftmagnitude(vinf, ss)
   destructiveaddmagnitudes(vinf, tm1)
   destructiveleftshiftmagnitude(vinf, ss)
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
      -- Note: multiplying a large number (suppose it has 8'675'309-words) by a
      -- small number (say at most 79-words) will use this method of muliplying
      return multiplycolinplumb(thismag, thatmag)
   elseif max(thismaglen, thatmaglen) > toomcookmultiplythreshold then
      -- if either are greater than the Toom Cook threshold then do
      -- Toom Cook multiplication
      -- Note: multiplying a large number (suppose it has 8'675'309 words) by a
      -- small number (say at least 80 words) will use this method of muliplying
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
   
   local thistype, thattype, reason
         = arebothvalidoperablevalues(thisvalue, thatvalue, "multiplication")
   
   assert(thistype, reason)
   
   thissign, thismag = getsignandmagnitude(thisvalue, thistype)
   thatsign, thatmag = getsignandmagnitude(thatvalue, thattype)
   
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
   local thattype, reason
         = arevalidbigintegerandoperablevalue(
               thisbigint, thatvalue, "multiplication")
   
   assert(thattype, reason)
   
   thatsign, thatmag = getsignandmagnitude(thatvalue, thattype)
   
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




--[====================================[
--[  _____                             ]
--[ |  __ \                            ]
--[ | |__) | ___ __      __ ___  _ __  ]
--[ |  ___/ / _ \\ \ /\ / // _ \| '__| ]
--[ | |    | (_) |\ V  V /|  __/| |    ]
--[ |_|     \___/  \_/\_/  \___||_|    ]
--[                                    ]
--]====================================]

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
   -- if highest == lowest then
   --    -- Otherwise the value is a power of 2 and can be easily exponentiated by
   --    -- left-shifting. 
   --    
   --    shifts = lowest * (exponent - 1)
   --    ok, reason = isvalidinteger(shifts)
   --    
   --    if not ok then
   --       error("value too large to be exponentiated")
   --    end
   --    
   --    destructiveleftshiftmagnitude(mag, shifts)
   --    
   --    if bitand(exponent, 1) == 0 then
   --       -- exponent is even
   --       sign = 1
   --    end
   --    
   --    return constructorsignmagnitude(sign, mag)
   -- end
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
   local valuetype, reason = isvalidoperablevalue(value)
   
   assert(valuetype, reason)
   assert(isvalidint(exponent))
   
   
   -- Test for special, easy math cases (e == 0, e == 1, x == 0, and x == 2^n)
   if exponent == 0 then
      -- x^0 := 1 for any real x (defines 0^0 := 1)
      return constructornumber(1)
   end
   
   if exponent == 1 then
      -- x^1 := x for any real x
      return value
   end
   
   sign, mag = getsignandmagnitude(value, valuetype)
   
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
   local highest, lowest, sign
   local parttosquare, result
   
   assert(isvalidbiginteger(bigint))
   assert(isvalidint(exponent))
   
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




--[====================================[
--[  _____   _         _      _        ]
--[ |  __ \ (_)       (_)    | |       ]
--[ | |  | | _ __   __ _   __| |  ___  ]
--[ | |  | || |\ \ / /| | / _` | / _ \ ]
--[ | |__| || | \ V / | || (_| ||  __/ ]
--[ |_____/ |_|  \_/  |_| \__,_| \___| ]
--[                                    ]
--]====================================]

function divideoneword(dividend, divisor)
   -- ensure dividend is magnitude and divisor is 32-bit integer
   -- returns quotient and remainder, both magnitudes
   local shift, qhat, qrem, _
   local quotient, remainder
   local dividendlength, dividendestimate
   
   shift = numberofleadingzeros(divisor)
   
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
      _, qhat, qrem = longdivideint(qrem, dividend[i], divisor)
      
      quotient[i] = qhat
   end
   
   if shift > 0 then
      qrem = qrem % divisor
   end
   
   return destructivestripleadingzeros(quotient), qrem
end

function multiplythensubtract(remainder, div, qhat, offset)
   local carry, producthigh, productlow, signint
   local differencehigh, differencelow, _
   local divlength = #div
   
   carry = 0
   remainder[offset] = 0
   offset = offset + divlength
   
   for i = divlength, 1, -1 do
      signint = getwordarraysignword(remainder)
      producthigh, productlow = intmultiplyint(div[i], qhat, carry)
      differencehigh, differencelow = splitlong(remainder[offset] + (bitnot(productlow) + 1))
      differencehigh = (bitnot(producthigh) + differencehigh + signint) % 0x100000000
      
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
   
   shift = numberofleadingzeros(divisor[1])
   
   -- if shift == 0, it returns a copy
   div = copyandleftshiftmagnitude(divisor, shift)
   
   remainder = copyandleftshiftmagnitude(dividend, shift)
   
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
         qrem = (nh + nm) % 0x100000000
         skipcorrection = bitxor(qrem, negativemask) < nh2
      else
         --[[
         -- long nChunk = (((long)nh) << 32) | (nm & LONG_MASK);
         -- if (nChunk >= 0) {
         --    qhat = (int) (nChunk / dhLong);
         --    qrem = (int) (nChunk - (qhat * dhLong));
         -- } else {
         --    long tmp = divWord(nChunk, dh);
         --    qhat = (int) (tmp & LONG_MASK);
         --    qrem = (int) (tmp >>> 32);
         -- }
         --]]
         _, qhat, qrem = longdivideint(nh, nm, divhigh)
      end
      
      --[[
      -- if (qhat == 0)
      --    continue
      -- 
      -- well, there's no continue in Lua
      --]]
      
      if qhat ~= 0 then
         --[[
         -- if (!skipCorrection) { // Correct qhat
         --    long nl = rem.value[j+2+rem.offset] & LONG_MASK;
         --    long rs = ((qrem & LONG_MASK) << 32) | nl;
         --    long estProduct = (dl & LONG_MASK) * (qhat & LONG_MASK);
         --
         --    if (unsignedLongCompare(estProduct, rs)) {
         --       qhat--;
         --       qrem = (int)((qrem & LONG_MASK) + dhLong);
         --       if ((qrem & LONG_MASK) >=  dhLong) {
         --          estProduct -= (dl & LONG_MASK);
         --          rs = ((qrem & LONG_MASK) << 32) | nl;
         --          if (unsignedLongCompare(estProduct, rs))
         --             qhat--;
         --       }
         --    }
         -- }
         --]]
         
         if not skipcorrection then
            nl = remainder[i + 2]
            estproducthigh, estproductlow = intmultiplyint(divlow, qhat, 0)
            
            if estproducthigh > qrem or (estproducthigh == qrem and estproductlow > nl) then
               qhat = qhat - 1
               qrem = (qrem + divhigh) % 0x100000000
               
               if qrem >= divhigh then
                  if divlow > estproductlow then
                     estproducthigh = estproducthigh - 1
                     estproductlow = estproductlow + 0x100000000
                  end
                  
                  estproductlow = (estproductlow - divlow) % 0x100000000
                  
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
   
   destructiverightshiftmagnitude(remainder, shift)
   
   return destructivestripleadingzeros(quotient),
         destructivestripleadingzeros(remainder)
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
   
   return destructivestripleadingzeros(mag)
end

function divide2n1n(a, b)
   local a123, a4, q1, r, s
   local n, halfn
   local quotient
   
   n = #b
   
   -- step 1: base case
   -- if n is odd or small, do school division
   if bitand(n, 1) == 1 or n < burnikelzieglerthreshold then
      return destructivedivideknuth(a, b)
   end
   halfn = n / 2
   
   -- step 2: split A and B
   -- A = [a1,a2,a3,a4], a123 = [a1,a2,a3], each ai has up to n/2 words
   -- B = [b1,b2], but they're kept together in all calculations, so don't split
   a123, a4 = splitarray(a, halfn)
   
   -- step 3:   q1 = a123 / b,   R = [r1,r2] = a123 % b
   q1, r = divide3n2n(a123, b, halfn)
   
   -- step 4:   a4 = [r1,r2,a4],   q2 = a4 / b,   S = a4 % b
   destructiveadddisjoint(a4, r, halfn)
   quotient, s = divide3n2n(a4, b, halfn)
   
   -- step 5:   Q = [q1,q2]
   destructiveadddisjoint(quotient, q1, halfn)
   
   return destructivestripleadingzeros(quotient),
         destructivestripleadingzeros(s)
end

function divide3n2n(a, b, halfn)
   local a12, a1, a3, b1, b2, d, _
   local quotient, remainder
   
   -- used for decrementing
   local one = {1}
   
   -- step 1: A = [a1,a2,a3], let a12 = [a1,a2]
   a12, a3 = splitarray(a, halfn)
   a1, _ = splitarray(a12, halfn)
   
   -- step 2: B = [b1,b2]
   b1, b2 = splitarray(b, halfn)
   
   if comparemagnitudes(a1, b1) < 0 then
      -- step 3a: a1<b1,   Q = a12 / b1,   R = a12 % b1
      quotient, remainder = divide2n1n(a12, b1)
      
      -- step 4: d = Q * b2
      d = multiplymagnitudes(quotient, b2)
   else
      -- step 3b: Q = (beta^n) - 1,   R = a12 + b1 - b1*2^halfn
      destructiveaddmagnitudes(a12, b1)
      destructiveleftshiftmagnitude(b1, 32 * halfn)
      destructivesubtractmagnitudes(a12, b1)
      remainder = a12
      
      -- Q = beta^halfn - 1 = a halfn-int array of all ones
      quotient = {}
      for i = 1, halfn do
         quotient[i] = 0xffffffff
      end
      
      -- step 4: d = Q * b2 = (beta^halfn - 1) * b2 = b2 * beta^halfn - b2
      d = copyandleftshiftmagnitude(b2, 32 * halfn)
      destructivesubtractmagnitudes(d, b2)
   end
   
   -- step 5: rh = R*beta^halfn + a3 - d (paper erroneously has a4 instead of a3)
   -- wait until after the loop to subtract d to keep R from going negative
   -- R = rh
   destructiveleftshiftmagnitude(remainder, 32 * halfn)
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
   
   m = 2 ^ (64 - numberofleadingzeroslong(floor(divisorlength / burnikelzieglerthreshold)))
   j = ceil(divisorlength / m)
   n = j * m
   n32 = n * 32
   sigma = max(n32 - divisorbitlength, 0)
   
   destructiveleftshiftmagnitude(dividend, sigma)
   destructiveleftshiftmagnitude(divisor, sigma)
   t = max(floor((gethighestsetbit(dividend) + 1 + n32) / n32), 2)
   
   blocks = splitarrayintoblocks(dividend, n)
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
      destructiveaddmagnitudes(quotient, copyandleftshiftmagnitude(qi, (blocklength + 1 - i) * n * 32))
   end
   
   qi, ri = divide2n1n(z, divisor)
   destructiveaddmagnitudes(quotient, qi)
   
   destructiverightshiftmagnitude(ri, sigma)
   
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
   
   local thistype, thattype, reason
         = arebothvalidoperablevalues(thisvalue, thatvalue, "division")
   
   thissign, thismag = getsignandmagnitude(thisvalue, thistype)
   thatsign, thatmag = getsignandmagnitude(thatvalue, thattype)
   
   quotient, remainder = dividemagnitudes(thismag, thatmag)
   sign = thissign * thatsign
   
   return createbiginteger(#quotient == 0 and 0 or sign, quotient), createbiginteger(#remainder == 0 and 0 or thissign, remainder)
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




--[==============================================[
--[       _____  _          _                    ]
--[      / ____|| |        (_)                   ]
--[     | (___  | |_  _ __  _  _ __    __ _      ]
--[      \___ \ | __|| '__|| || '_ \  / _` |     ]
--[      ____) || |_ | |   | || | | || (_| |     ]
--[     |_____/  \__||_|   |_||_| |_| \__, |     ]
--[  ____          _  _      _  _      __/ |     ]
--[ |  _ \        (_)| |    | |(_)    |___/      ]
--[ | |_) | _   _  _ | |  __| | _  _ __    __ _  ]
--[ |  _ < | | | || || | / _` || || '_ \  / _` | ]
--[ | |_) || |_| || || || (_| || || | | || (_| | ]
--[ |____/  \__,_||_||_| \__,_||_||_| |_| \__, | ]
--[                                        __/ | ]
--[                                       |___/  ]
--]==============================================]

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
            sq = squaremagnitude(getintegermagnitude(radixcache[i - 1]))
         end
      else
         sq = squaremagnitude(radixcache[i - 1])
      end
      radixcache[i] = sq
   end
   
   pc = radixcache[exponent]
   
   if type(pc) == 'number' then
      return getintegermagnitude(pc)
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

function makestring(thisval, radix)
   local thissign, thismag
   local str
   local thistype, reason = isvalidoperablevalue(thisval)
   
   assert(thistype, reason)
   
   if radix then
      assert(isvalidradix(radix))
   else
      radix = 10
   end
   
   thissign, thismag = getsignandmagnitude(thisval, thistype)
   
   if thissign == 0 then
      return "0"
   end
   
   str = stringbuildrecursive(thismag, radix, 0)
   
   return (thissign == -1 and '-' or '') .. str
end




--[==================================[
--[   ____   _    _                  ]
--[  / __ \ | |  | |                 ]
--[ | |  | || |_ | |__    ___  _ __  ]
--[ | |  | || __|| '_ \  / _ \| '__| ]
--[ | |__| || |_ | | | ||  __/| |    ]
--[  \____/  \__||_| |_| \___||_|    ]
--[                                  ]
--]==================================]

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

return bi
--{biginteger = biginteger}
