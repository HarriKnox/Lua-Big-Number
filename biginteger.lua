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




--[==========================================================[
--[   _____                     _                  _         ]
--[  / ____|                   | |                | |        ]
--[ | |       ___   _ __   ___ | |_   __ _  _ __  | |_  ___  ]
--[ | |      / _ \ | '_ \ / __|| __| / _` || '_ \ | __|/ __| ]
--[ | |____ | (_) || | | |\__ \| |_ | (_| || | | || |_ \__ \ ]
--[  \_____| \___/ |_| |_||___/ \__| \__,_||_| |_| \__||___/ ]
--[                                     _                    ]
--[                                    | |                   ]
--[                    __ _  _ __    __| |                   ]
--[                   / _` || '_ \  / _` |                   ]
--[             _    | (_| || | | || (_| |  _                ]
--[            | |    \__,_||_| |_| \__,_| | |               ]
--[            | |       ___    ___   __ _ | | ___           ]
--[            | |      / _ \  / __| / _` || |/ __|          ]
--[            | |____ | (_) || (__ | (_| || |\__ \          ]
--[            |______| \___/  \___| \__,_||_||___/          ]
--[                                                          ]
--]==========================================================]

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
-- The largest number bit32 can work with reliably (despite being a 32-bit
-- library).
--
-- maxinteger = 2^51 - 1
--]==]
local maxinteger = 0x7ffffffffffff


--[==[
-- The largest magnitude allowable because of 32 bits per word (allows for up
-- to `maxinteger` bits).
--
-- maxmagnitudelength = 2^51 / 32 - 1
--]==]
local maxmagnitudelength = 0x3fffffffffff


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
-- A table, indexed by radix, of the number of digits of a given radix that can
-- fit in an int without overflowing or "going negative" (in Two's complement
-- form): that is, the largest number `n` for a radix `r` such that
-- r^n < 2^31 (or 0x80000000).
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
-- the value. Lowercase is used to increase variety in the heights of numbers.
-- In the following example, the number on the left has a varied and more
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
-- conversion. There are three layers of tables: this is an array of lists of
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




--[========================================================================[
--[  _______                        _______          _    _                ]
--[ |__   __|                      |__   __|        | |  (_)               ]
--[    | | _   _  _ __    ___  ______ | |  ___  ___ | |_  _  _ __    __ _  ]
--[    | || | | || '_ \  / _ \|______|| | / _ \/ __|| __|| || '_ \  / _` | ]
--[    | || |_| || |_) ||  __/        | ||  __/\__ \| |_ | || | | || (_| | ]
--[    |_| \__, || .__/  \___|        |_| \___||___/ \__||_||_| |_| \__, | ]
--[         __/ || |                                                 __/ | ]
--[        |___/ |_|                                                |___/  ]
--[           ______                    _    _                             ]
--[          |  ____|                  | |  (_)                            ]
--[          | |__  _   _  _ __    ___ | |_  _   ___   _ __   ___          ]
--[          |  __|| | | || '_ \  / __|| __|| | / _ \ | '_ \ / __|         ]
--[          | |   | |_| || | | || (__ | |_ | || (_) || | | |\__ \         ]
--[          |_|    \__,_||_| |_| \___| \__||_| \___/ |_| |_||___/         ]
--[                                                                        ]
--]========================================================================]

--[==[
-- Tests whether the passed value is an integer that the library can use. This
-- fails if the value is
--  * not an number type (string, table, etc)
--  * outside the range of [-maxinteger, maxinteger]
--  * a float
--]==]
function isvalidinteger(int)
   local r = "not a valid integer: "
   
   
   --[[ Check that the value is actually a number ]]
   if type(int) ~= 'number' then
      return false, r .. "it's a " .. type(int)
   end
   
   
   --[[ Now check that it's in range ]]
   if int > maxinteger or int < -maxinteger then
      return false, r .. "outside allowable range"
   end
   
   
   --[[ Now check that it's not a float ]]
   if int % 1 ~= 0 then
      return false, r .. "it's a float"
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is an int that the library can use.
-- This fails if the value is
--  * not a number type (string, table, etc)
--  * outside the range [0, 4294967295] (it's negative or larger than 32 bits)
--  * a float
--]==]
function isvalidint(int)
   local r = "not a valid int: "
   
   
   --[[ First, check that it is a number ]]
   if type(int) ~= 'number' then
      return false, r .. "it's a " .. type(int)
   end
   
   
   --[[ Ensure that it doesn't exceed 32 bits ]]
   if int > 0xffffffff then
      return false, r .. "outside 32 bits"
   end
   
   
   --[[ Ensure that it's not negative ]]
   if int < 0 then
      return false, r .. "negative"
   end
   
   
   --[[ Ensure that it's not a float ]]
   if int % 1 ~= 0 then
      return false, r .. "it's a float"
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is a 32-bit integer that, when made positive,
-- the library can use. This fails if the value is
--  * not a number
--  * not a 32-bit integer when made positive
--
-- Note, this is not looking at the Two's complement form of the number (that
-- would be redundant since the number would need to be a 32-bit number
-- anyway). This checks the value to ensure it is in the range
-- [-4294967295, 4294967295].
--]==]
function isvalidabsolute32bitinteger(int)
   local r = "not a valid absolute 32-bit integer: "
   
   local ok, reason
   
   
   --[[ Check if it's a number ]]
   if type(int) ~= 'number' then
      return false, r .. "it's a " .. type(int)
   end
   
   
   --[[ Now check if the absolute value is an int ]]
   ok, reason = isvalidint(abs(int))
   
   
   return ok, r .. reason
end


--[==[
-- Tests whether the passed value is a word-array that the library can use.
-- This fails if the value is
--  * not a table (string, number, etc)
--  * a biginteger (in which it won't be treated as a word-array)
--  * an array that contains a value that is not an int
--
-- Note, this function (and every other array function, for that matter) uses
-- the length operator (#) in a `for i = 1, #array do` loop.
--]==]
function isvalidwordarray(array)
   local r = "not a valid word-array: "
   
   local ok, reason
   
   
   --[[ First check that it's a table ]]
   if type(array) ~= 'table' then
      return false, r .. "not an array (table): it's a " .. type(array)
   end
   
   
   --[[ Next, if it could be terated as a biginteger, then fail ]]
   if isvalidbiginteger(array) then
      return false, r
            .. "it's a biginteger and will not be treated as a word-array"
   end
   
   
   --[[ Now test every element from 1 to #array to ensure each is an int ]]
   for i = 1, #array do
      ok, reason = isvalidint(array[i])
      
      
      if not ok then
         return false, r .. "element " .. i .. " " .. reason
      end
   end
   
   return true
end


--[==[
-- Tests whether the passed value is a magnitude that the library can use. This
-- fails if the value is
--  * not a valid word array
--  * too large
--  * with leading zeros
--]==]
function isvalidmagnitude(mag)
   local r = "not a valid magnitude: "
   
   local ok, reason
   
   
   --[[ Make sure the magnitude is an actual array ]]
   ok, reason = isvalidwordarray(mag)
   
   if not ok then
      return false, r .. reason
   end
   
   
   --[[ Ensure the length of the array doesn't exceed the maximum length ]]
   if #mag >= maxmagnitudelength then
      return false, r .. "too large (overflow)"
   end
   
   
   --[[ Ensure there are no leading zeros ]]
   if mag[1] == 0 then
      return false, r .. "has leading zeros"
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is a sign that the library can use. This
-- fails if the value is
--  * not a number
--  * not -1, 0, or 1
--]==]
function isvalidsign(sign)
   local r = "not a valid sign: "
   
   
   --[[ Check that the value is a number ]]
   if type(sign) ~= 'number' then
      return false, r .. "not a number: it's a " .. type(sign)
   end
   
   
   --[[ Use a super-complex algorithm to see if it equals -1, 0, or +1 ]]
   if sign ~= -1 and sign ~= 0 and sign ~= 1 then
      return false, r .. "not in {-1, 0, 1}"
   end
   
   
   return true
end


--[==[
-- Tests whether the sign and magnitude given are a sign-magnitude pairing that
-- the library can use. This fails if
--  * `sign` isn't a sign
--  * `mag` isn't a magnitude
--  * a non-zero magnitude is paired with a zero-sign (ambiguous sign)
--  * a zere-magnitude is paired with a non-zero-sign (redundant zeros)
--
-- Note, preventing redundant zeros are just to enforce that there aren't
-- multiple notations for the same value, that is -0, 0, and +0. This isn't as
-- big of an issue as ambiguous signage, so I might remove this part of the
-- test later.
--]==]
function isvalidsignmagnitudecombination(sign, mag)
   local r = "not a valid sign-magnitude pair: "
   
   local ok, reason
   
   
   --[[ CCheck that the sign is a proper sign ]]
   ok, reason = isvalidsign(sign)
   
   if not ok then
      return false, r .. reason
   end
   
   
   --[[ Now check that the magnitude is a proper magnitude ]]
   ok, reason = isvalidmagnitude(mag)
   
   if not ok then
      return false, r .. reason
   end
   
   
   --[[ A value that is not positive nor negative nor zero isn't supported ]]
   if sign == 0 and #mag ~= 0 then
      return false, r .. "non-zero magnitude with zero sign"
   end
   
   
   --[[ Positive and negative zeros aren't allowed to ensure uniqueness ]]
   if sign ~= 0 and #mag == 0 then
      return false, r .. "non-zero sign with zero magnitude"
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is a biginteger that the library can use.
-- This fails if the value
--  * is not a table
--  * does not contain a valid sign
--  * does not contain a valid magnitude
--  * does not contain a valid sign-magnitude pair
--]==]
function isvalidbiginteger(bigint)
   local r = "not a valid biginteger: "
   
   local ok, reason
   
   
   --[[ Make sure the value is a table (Lua's object) ]]
   if type(bigint) ~= 'table' then
      return false, r .. "not a table: it's a " .. type(bigint)
   end
   
   
   --[[ Make sure there exists a bigint.sign and that it is a sign ]]
   ok, reason = isvalidsign(bigint.sign)
   
   if not ok then
      return false, r .. reason
   end
   
   
   --[[ Make sure there exists a bigint.magnitude and that it is a magnitude ]]
   ok, reason = isvalidmagnitude(bigint.magnitude)
   
   if not ok then
      return false, r .. reason
   end
   
   
   --[[ Make sure the sign and magnitude play nice ]]
   ok, reason = isvalidsignmagnitudecombination(bigint.sign, bigint.magnitude)
   
   if not ok then
      return false, r .. reason
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is a radix that the library can use. This
-- fails if the value is
--  * not an integer
--  * not in the range [2, 36]
--]==]
function isvalidradix(radix)
   local r = "not a valid radix: "
   
   local ok, reason
   
   
   --[[ Make sure it's a number ]]
   ok, reason = isvalidinteger(radix)
   
   if not ok then
      return false, r .. reason
   end
   
   
   --[[ Check that it's in the bounds of 2 <= r <= 36 ]]
   if radix < 2 or radix > 36 then
      return false, r .. "outside allowable range"
   end
   
   
   return true
end


--[==[
-- Tests whether the passed value is a string-number that the library can use.
-- This fails if the value
--  * is not a string
--  * contains a character that is not valid with the given radix
--]==]
function isvalidstringnumber(str, radix)
   local r = "not a valid string-number: "
   local highest = radix - 1
   
   local set, index, c, _
   
   
   --[[ First make sure the thing is a string ]]
   if type(str) ~= 'string' then
      return false, r .. "not a string: it's a" .. type(str)
   end
   
   
   --[[ See if the string has no digits in it and fail if so ]]
   if stringmatch(str, '^[-+]?$') then
      return false, r .. "zero-length string"
   end
   
   
   --[[
   -- Use the highest valid value of the radix to determine the upper bound to
   -- the set of characters.
   --]]
   if highest < 10 then
      set = '0-' .. tostring(highest)
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
   _, index, c = stringfind(str, '^[-+]?[' .. set .. ']*([^' .. set .. '])')
   
   return false,
         "not a valid string number: contains non-digit character at index "
         .. tostring(index) .. ": '" .. char .. "'"
end


--[==[
-- Tests if the passed value is either a integer, word-array, or biginteger
-- that the library can use. This fails if the value is neither of those
-- things.
--]==]
function isvalidoperablevalue(value)
   --[[ Check if the value is either an integer, word-array, or biginteger ]]
   if isvalidinteger(value) or isvalidwordarray(value)
         or isvalidbiginteger(value) then
      return true
   end
   
   
   return false, "not a valid operable value: it's a " .. type(value)
end


--[==[
-- Tests if the passed values are both operable values and fails if either are
-- not. The second return value (the reason it failed) will incorporate the
-- operation attempted, thus the `operation` parameter is a string of what the
-- operation was (such as "addition" or "multiplication").
--]==]
function arebothvalidoperablevalues(thisvalue, thatvalue, operation)
   --[[ Check if both values are operable values ]]
   if isvalidoperablevalue(thisvalue) and isvalidoperablevalue(thatvalue) then
      return true
   end
   
   
   return false, "attempt to perform " .. operation .. " on "
         .. gettype(thisvalue) .. " and " .. gettype(thatvalue)
end


--[==[
-- Tests if the first value is a biginteger and the second value is an operable
-- value. This fails if the first value is not a biginteger or the second value
-- is not operable. Like the previous function, this incorporates the name of
-- the operation being attempted into the returned reason.
--]==]
function arevalidbigintegerandoperablevalue(bigint, value, operation)
   local ok, reason
   
   
   --[[ If the first value is not a biginteger, fail ]]
   ok, reason = isvalidbiginteger(bigint)
   
   if not ok then
      return false, reason
   end
   
   
   --[[ Check if the second value is a operable value ]]
   if not isvalidoperablevalue(thatvalue) then
      return false, "attempt to perform " .. operation .. " on biginteger and "
            .. gettype(value)
   end
   
   
   return true
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
   return floor(number / 32), bitand(number, 0x1f)
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
-- appendix document "int_multiply_int".
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


--[==[
-- Returns the number of leading zeros in the int. This uses one of the
-- Hacker's Delight algorithms featured in HD Figure 5-6. Some optimizing
-- modifications were made (switching the bit-shifts to multiplications) for
-- speed.
--]==]
function numberofleadingzeros(int)
   local n = 0
   
   
   --[[ Special case that is easy to check ]]
   if int == 0 then
      return 32
   end
   
   
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
      n = n = 1
   end
   
   
   return n
end


--[==[
-- Returns the number of trailing zeros in the int. This uses one of the
-- Hacker's Delight algorithms featured in (HD Figure 5-14).
--
-- This uses the algorithm selected by the Java Integer class and is slow
-- because of all the calls to the bit-shifting function. Unlike the function
-- for counting leading zeros, this function can't be optimized in the same
-- way (changing bit-shifts for multiplications and divisions), but that's OK
-- because this function is rarely called in comparison to its counterpart.
--]==]
function numberoftrailingzeros(int)
   local y
   local n = 32
   
   
   --[[ Quick check for zero ]]
   if int == 0 then
      return 32
   end
   
   
   --[[ Check if lowest 16 bits are zeros ]]
   y = bitleftshift(int, 16)
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
-- Returns the number of leading zeros in a long. Because this function uses
-- only the most significant bits, the least significant aren't looked at so
-- the full 64 bits can be used without the fear of the loss of the lowest
-- bits.
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
-- Returns the number of trailing zeros in a long. Because this function uses
-- the least significant bits, the results of it are undefined if passed an
-- integer too large for the 64-bit floating-point number (a 54-bit integer or
-- larger).
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
--[           | |_| | _ __  _ __   __ _  _   _            ]
--[           |  _  || '__|| '__| / _` || | | |           ]
--[           | | | || |   | |   | (_| || |_| |           ]
--[           |_| |_||_|   |_|    \__,_| \__, |           ]
--[  ______                    _    _     __/ |           ]
--[ |  ____|                  | |  (_)   |___/            ]
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
   local arraylength = #array
   local newvalueslength = #newvalues
   
   
   --[[ Copy the values in from the start ]]
   for i = 1, newvalueslength do
      array[i] = newvalues[i]
   end
   
   
   --[[ If `array` was longer, clear the remaining entries ]]
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
   local maglength = #mag
   local upperlength = maglength - length
   
   local upper, lower
   
   
   --[[ If the length is zero/negative, 'lower' is empty ]]
   if length <= 0 then
      return copyarray(mag), {}
   end
   
   
   --[[ If the length is the entire array or more, 'upper' is empty ]]
   if length >= maglength then
      return {}, copyarray(mag)
   end
   
   
   --[[ Initialize the sub-arrays ]]
   upper = {}
   lower = {}
   
   
   --[[ Copy the first values into 'upper' ]]
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
-- For example, pretend these X's are a 35-long array, split with blocksize 8;
-- these would be the resulting blocks.
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


function splitarraytoomcook(mag, fullsize)
   -- fullsize is used when multiplying two magnitudes of different sizes
   local maglength = #mag
   local size = floor((fullsize + 2) / 3)
   local lowersize = min(size, maglength)
   local middlesize = min(size, maglength - lowersize)
   local uppersize = min(size, maglength - lowersize - middlesize)
   
   local lowerslice, middleslice, upperslice
   
   
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





--[=======================================================[
--[         _       _                   _                 ]
--[        | |     | |                 | |                ]
--[        | |  _  | |  ___   _ __   __| | ______         ]
--[        | | | | | | / _ \ | '__| / _` ||______|        ]
--[        | |_| |_| || (_) || |   | (_| |                ]
--[         \___.___/  \___/ |_|    \__,_|                ]
--[             ___                                       ]
--[            / _ \                                      ]
--[           | |_| | _ __  _ __   __ _  _   _            ]
--[           |  _  || '__|| '__| / _` || | | |           ]
--[           | | | || |   | |   | (_| || |_| |           ]
--[           |_| |_||_|   |_|    \__,_| \__, |           ]
--[  ______                    _    _     __/ |           ]
--[ |  ____|                  | |  (_)   |___/            ]
--[ | |__  _   _  _ __    ___ | |_  _   ___   _ __   ___  ]
--[ |  __|| | | || '_ \  / __|| __|| | / _ \ | '_ \ / __| ]
--[ | |   | |_| || | | || (__ | |_ | || (_) || | | |\__ \ ]
--[ |_|    \__,_||_| |_| \___| \__||_| \___/ |_| |_||___/ ]
--[                                                       ]
--]=======================================================]

function signextendwordarrayto(source, destination, newlength)
   local length = #source
   local signwords = newlength - length
   local signint = getwordarraysignint(source[1])
   
   if signwords <= 0 then
      if source ~= destination then
         -- if no sign words are being added and the source and destination are
         -- different, then copy the values from source to destination and
         -- return. If the source and destination are the same table, then do
         -- nothing and return.
         for i = 1, length do
            destination[i] = source[i]
         end
      end
      return destination
   end
   
   for i = newlength, signwords + 1, -1 do
      destination[i] = source[i - signwords]
   end
   
   for i = 1, signwords do
      destination[i] = signint
   end
   
   return destination
end

function copyandsignextendwordarray(array, newlength)
   return signextendwordarrayto(array, {}, newlength)
end

function destructivesignextendwordarray(array, newlength)
   return signextendwordarrayto(array, array, newlength)
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


function negatewordarrayto(source, destination)
   --[[
   -- This function is correct, even though it seems it should do something with
   -- `addend` after the loop. The only number that would cause an overflow when
   -- added to 1 is 0b1111111111111111 (-1). The bitnot of that is 0. Thus the
   -- only number that would cause `addend` to still be 1 after the loop is 0,
   -- and the negation of 0 is 0.
   --]]
   local length = #source
   local addend = 1
   
   for i = length, 1, -1 do
      addend, destination[i] = splitlong(bitnot(source[i]) + addend)
   end
   
   destructivestripleadingzeros(destination)
   
   return destination
end

function copyandnegatewordarray(array)
   return negatewordarrayto(array, {})
end

function destructivenegatewordarray(array)
   return negatewordarrayto(array, array)
end


function gethighestsetbit(mag)
   -- Will return the zero-index, little-endian index of the highset set bit,
   -- or -1 if array is equal to zero
   local length = #mag
   
   for i = 1, length do
      if mag[i] ~= 0 then
         return (length - i + 1) * 32 - numberofleadingzeros(mag[i]) - 1
      end
   end
   
   return -1
end

function getlowestsetbit(array)
   -- Will return the zero-index, little-endian index of the lowset set bit,
   -- or -1 if array is equal to zero
   local length = #array
   
   for i = length, 1, -1 do
      if mag[i] ~= 0 then
         return (length - i) * 32 + numberoftrailingzeros(mag[i])
      end
   end
   
   return -1
end




--[=======================================================[
--[           _____        _    _                         ]
--[          / ____|      | |  | |                        ]
--[         | |  __   ___ | |_ | |_   ___  _ __           ]
--[         | | |_ | / _ \| __|| __| / _ \| '__|          ]
--[         | |__| ||  __/| |_ | |_ |  __/| |             ]
--[          \_____| \___| \__| \__| \___||_|             ]
--[  ______                    _    _                     ]
--[ |  ____|                  | |  (_)                    ]
--[ | |__  _   _  _ __    ___ | |_  _   ___   _ __   ___  ]
--[ |  __|| | | || '_ \  / __|| __|| | / _ \ | '_ \ / __| ]
--[ | |   | |_| || | | || (__ | |_ | || (_) || | | |\__ \ ]
--[ |_|    \__,_||_| |_| \___| \__||_| \___/ |_| |_||___/ ]
--[                                                       ]
--]=======================================================]

function gettype(thing)
   return (isvalidinteger(thing) and 'integer') or
          (isvalidbiginteger(thing) and 'biginteger') or
          (isvalidwordarray(thing) and 'word-array') or
          type(thing)
end


function getwordarraysignint(array)
   if array[1] and array[1] >= negativemask then
      return 0xffffffff
   end
   
   return 0
end

function getwordarraysign(array)
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

function getwordarraymagnitude(array)
   if getwordarraysign(array) == -1 then
      return copyandnegatewordarray(array)
   end
   return copyandstripleadingzeros(array)
end

function getwordarraysignandmagnitude(array)
   local sign = getwordarraysign(array)
   if sign == -1 then
      return sign, copyandnegatewordarray(array)
   end
   return sign, copyandstripleadingzeros(array)
end


function getnumbersign(int)
   return (int < 0 and -1) or (int > 0 and 1) or 0
end

function getnumbermagnitude(int)
   local highword, lowword = splitlong(abs(int))
   
   if highword == 0 then
      if lowword == 0 then
         return {}
      end
      return {lowword}
   end
   return {highword, lowword}
end

function getnumbersignandmagnitude(int)
   return getnumbersign(int), getnumbermagnitude(int)
end


function getsign(value)
   if isvalidbiginteger(value) then
      return value.sign
      
   elseif isvalidwordarray(value) then
      return getwordarraysign(value)
      
   elseif isvalidinteger(value) then
      return getnumbersign(value)
   end
   
   -- precautionary error that should not run unless I missed a check somewhere
   error("cannot obtain sign of " .. gettype(value))
end

function getmagnitude(value)
   if isvalidbiginteger(value) then
      return copyarray(value.magnitude)
      
   elseif isvalidwordarray(value) then
      return getwordarraymagnitude(value)
      
   elseif isvalidinteger(value) then
      return getnumbermagnitude(value)
   end
   
   -- precautionary error that should not run unless I missed a check somewhere
   error("cannot obtain magnitude of " .. gettype(value))
end

function getsignandmagnitude(value)
   if isvalidbiginteger(value) then
      return value.sign, copyarray(value.magnitude)
      
   elseif isvalidwordarray(value) then
      return getwordarraysignandmagnitude(value)
      
   elseif isvalidinteger(value) then
      return getnumbersignandmagnitude(value)
   end
   
   -- precautionary error that should not run unless I missed a check somewhere
   error("cannot obtain sign and magnitude of " .. gettype(value))
end


function gettrustedsignmagnitudewordarray(sign, mag)
   if sign == -1 then
      destructivenegatewordarray(mag)
      
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

function getsignmagnitudewordarray(sign, mag)
   return gettrustedsignmagnitudewordarray(sign, copyarray(mag))
end

function getwordarray(thing)
   if isvalidwordarray(thing) then
      return copyarray(thing)
   end
   
   return gettrustedsignmagnitudewordarray(getsignandmagnitude(thing))
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
   assert(isvalidwordarray(mag))
   
   return constructorsignmagnitudetrusted(sign, copyandstripleadingzeros(mag))
end

function constructorbitsrng(bitlength, randomnumbergenerator)
   local mag = {}
   local numberofwords, excesswords
   
   assert(bitlength >= 0 and bitlength % 1 == 0, "bit length not valid: must be a non-negative integer")
   assert(type(randomnumbergenerator()) == "number", "RNG function not valid: must return a number in the range [0, 1)")
   
   numberofwords = floor((bitlength + 31) / 32)
   for i = 1, numberofwords do
      -- This weird multiplication-addition is necessary since the default
      -- math.random would not operate on all 32 bits
      mag[i] = floor(randomnumbergenerator() * 0x10000) * 0x10000 +
               floor(randomnumbergenerator() * 0x10000)
   end
   
   excesswords = 32 * numberofwords - bitlength
   mag[1] = bitand(mag[1], 2 ^ (32 - excesswords) - 1)
   
   destructivestripleadingzeros(mag)
   
   return createbiginteger(1, mag)
end

function constructorwordarraytrusted(array)
   local sign
   
   assert(isvalidwordarray(array))
   
   sign = getwordarraysign(array)
   
   if sign == -1 then
      destructivenegatewordarray(array)
   end
   
   return constructorsignmagnitudetrusted(sign, array)
end

function constructorwordarray(array)
   return constructorwordarraytrusted(getwordarray(array))
end


function destructivemultiplyandadd(mag, factor, addend)
   local maglength = #mag
   local product = 0
   local carry = 0
   local index = maglength
   
   for i = maglength, 1, -1 do
      carry, mag[i] = intmultiplyint(factor, mag[i], carry)
   end
   
   carry = addend
   
   for i = maglength, 1, -1 do
      carry, mag[i] = splitlong(mag[i] + carry)
   end
   
   return mag
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
      elseif typeb == 'word-array' then
         return constructorsignmagnitude(a, b)
      elseif typeb == 'function' then
         return constructorbitsrng(a, b)
      end
   elseif typea == 'biginteger' and typeb == 'nil' then
      return clone(a)
   elseif typea == 'word-array' and typeb == 'nil' then
      return constructorwordarray(a)
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
      -- If the magnitudes are different sizes, then they cannot be equal.
      -- The function assumes magnitudes, so leading zeros will cause problems
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
function bitwisenotwordarray(wordarray)
   local destination = {}
   
   for i = 1, #wordarray do
      destination[i] = bitnot(wordarray[i])
   end
   
   return destination
end

function bitwisenot(value)
   assert(isvalidoperablevalue(value))
   
   return constructorwordarraytrusted(bitwisenotwordarray(getwordarray(value)))
end

function mutablebitwisenot(bigint)
   assert(isvalidbiginteger(bigint))
   
   bigint.sign, bigint.magnitude = getwordarraysignandmagnitude(bitwisenot(getwordarray(bigint)))
   
   return bigint
end


function bitwisewordarrays(thisarray, thatarray, mergefunction)
   local thislength, thatlength, longerlength
   local thissignint, thatsignint
   local destination = {}
   
   thislength = #thisarray
   thatlength = #thatarray
   longerlength = max(thislength, thatlength)
   
   thissignint = getwordarraysignint(thisarray)
   thatsignint = getwordarraysignint(thatarray)
   
   for i = 0, longerlength - 1 do
      destination[longerlength - 1] = mergefunction(thisarray[thislength - i] or thissignint,
                                                    thatarray[thatlength - i] or thatsignint)
   end
   
   return destination
end

function binarybitwise(thisvalue, thatvalue, bitwisefunction, opname)
   assert(arebothvalidoperablevalues(thisvalue, thatvalue, "bitwise " .. opname))
   
   return constructorwordarraytrusted(bitwisewordarrays(getwordarray(thisvalue),
                                                        getwordarray(thatvalue),
                                                        bitwisefunction))
end

function mutablebinarybitwise(thisbigint, thatvalue, bitwisefunction, opname)
   assert(arevalidbigintegerandoperablevalue(thisbigint, thatvalue, "bitwise " .. opname))
   
   thisbigint.sign, thisbigint.magnitude = bitwisewordarrays(getwordarray(thisvalue),
                                                             getwordarray(thatvalue),
                                                             bitwisefunction)
   
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


--[[ Shifting ]]
function destructiveleftshift(mag, displacement)
   local maglength
   local numberofbits, numberofwords
   local shiftmultiplier, carry
   
   if displacement == 0 then
      return mag
   end
   
   maglength = #mag
   
   numberofwords, numberofbits = splitlongtowordsandbits(displacement)
   
   shiftmultiplier = bitleftshift(1, numberofbits)
   carry = 0
   
   if numberofbits ~= 0 then
      for i = maglength, 1, -1 do
         carry, mag[i] = intmultiplyint(mag[i], shiftmultiplier, carry)
      end
   end
   
   for i = 1, numberofwords do
      mag[maglength + i] = 0
   end
   
   if carry ~= 0 then
      tableinsert(mag, 1, carry)
   end
   
   return mag
end

function destructiverightshift(mag, displacement)
   local maglength
   local numberofbits, numberofwords
   local numberofbitsadjusted
   local shiftmultiplier, lowbits, carry, oldcarry
   
   if displacement == 0 then
      return mag
   end
   
   maglength = #mag
   numberofwords, numberofbits = splitlongtowordsandbits(displacement)
   
   if numberofwords >= maglength then
      -- when right-shifting more bits than there are in the array, the result
      -- is -1 for negative values and 0 for non-negative values
      return cleararray(mag)
   end
   
   numberofbitsadjusted = 32 - numberofbits
   shiftmultiplier = bitleftshift(1, numberofbitsadjusted)
   carry = 0
   oldcarry = 0
   
   if numberofbits ~= 0 then
      for i = 1, maglength do
         lowbits, carry = intmultiplyint(mag[i], shiftmultiplier, 0)
         mag[i] = lowbits + oldcarry
         oldcarry = carry
      end
   end
   
   for i = 0, numberofwords - 1 do
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


--[[ Bitwise at Bit ]]
function destructivebitwiseatbit(wordarray, bitfromend, bitwisefunction)
   local word, bit, length
   
   word, bit = splitlongtowordsandbits(bitfromend)
   
   length = max(#wordarray, word + 1)
   
   destructivesignextendwordarray(wordarray, length)
   wordarray[length - word] = bitwisefunction(wordarray[length - word], bitleftshift(1, bit))
   
   return wordarray
end

function bitwiseatbit(value, bitfromend, bitwisefunction)
   local wordarray
   
   assert(isvalidoperablevalue(value))
   assert(isvalidinteger(bitfromend))
   assert(bitfromend >= 0, "not valid integer: negative")
   
   wordarray = getwordarray(value)
   destructivebitwiseatbit(wordarray, bitfromend, bitwisefunction)
   
   return constructorwordarraytrusted(wordarray)
end

function mutablebitwiseatbit(bigint, bitfromend, bitwisefunction)
   assert(isvalidbiginteger(bigint))
   assert(isvalidinteger(bitfromend))
   assert(bitfromend >= 0, "not valid integer: negative")
   
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
   
   assert(isvalidoperablevalue(value))
   assert(isvalidinteger(bitfromend))
   assert(bitfromend >= 0, "not valid integer: negative")
   
   word, bit = splitlongtowordsandbits(bitfromend)
   wordarray = getwordarray(value)
   length = #wordarray
   
   if word >= length then
      return getwordarraysign(wordarray) == -1
   end
   
   return bitand(wordarray[length - word], bitleftshift(1, bit)) ~= 0
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
   local larger, largerlength
   local smaller, smallerlength
   
   if comparemagnitudes(minuend, subtrahend) < 0 then
      -- minuend < subtrahend
      smaller = copyarray(minuend)
      larger = subtrahend
   else
      -- minuend >= subtrahend
      smaller = subtrahend
      larger = minuend
   end
   
   largerlength = #larger
   smallerlength = #smaller
   
   borrow = 0
   difference = 0
   
   for i = 0, largerlength - 1 do
      difference = (larger[largerlength - i] or 0) -
                   (smaller[smallerlength - i] or 0) -
                   borrow
      
      if difference < 0 then
         borrow = 1
      else
         borrow = 0
      end
      
      minuend[largerlength - i] = difference % 0x100000000
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
   destructivestripleadingzeros(triangle)
   
   return triangle
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
      
      _, productlow = intmultiplyint(w, 0xaaaaaaab, 0)
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
   
   a2, a1, a0, ss = splitarraytoomcook(mag, #mag)
   
   
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
   
   thisupper, thislower = splitarray(thismag, halfway)
   thatupper, thatlower = splitarray(thatmag, halfway)
   
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
   a2, a1, a0, ss = splitarraytoomcook(thismag, longerlength)
   b2, b1, b0, _  = splitarraytoomcook(thatmag, longerlength)
   
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
      -- v1 - -vm1 = v1 + vm1
      destructiveaddmagnitudes(vm1, v1)
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
   --    destructiveleftshift(mag, shifts)
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
   
   assert(isvalidoperablevalue(value))
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


-- Division
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
      signint = getwordarraysignint(remainder)
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
   div = copyandleftshift(divisor, shift)
   
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
   
   destructivestripleadingzeros(quotient)
   destructivestripleadingzeros(s)
   
   return quotient, s
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
   
   m = 2 ^ (64 - numberofleadingzeroslong(floor(divisorlength / burnikelzieglerthreshold)))
   j = ceil(divisorlength / m)
   n = j * m
   n32 = n * 32
   sigma = max(n32 - divisorbitlength, 0)
   
   destructiveleftshift(dividend, sigma)
   destructiveleftshift(divisor, sigma)
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


-- Temp stuff
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
