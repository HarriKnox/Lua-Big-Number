local biginteger = require('biginteger')

--[==[ isvalidinteger(int) ]==]
--[==[ isvalid32bitinteger(int) ]==]
--[==[ isvalidabsolute32bitinteger(int) ]==]
--[==[ isvalidwordarray(array) ]==]
--[==[ isvalidmagnitude(mag) ]==]
--[==[ isvalidsign(sign) ]==]
--[==[ isvalidsignmagnitudecombination(sign, mag) ]==]
--[==[ isvalidbiginteger(bigint) ]==]
--[==[ isvalidradix(radix) ]==]
--[==[ isvalidstringnumber(str, radix) ]==]
--[==[ isvalidoperablevalue(value) ]==]
--[==[ arebothvalidoperablevalues(thisvalue, thatvalue, operation) ]==]
--[==[ arevalidbigintegerandoperablevalue(bigint, value, operation) ]==]
--[==[ splitlong(number) ]==]
--[==[ splitlongtowordsandbits(number) ]==]
--[==[ integermultiplyandaddtosplitlong(x, ab, c) ]==]
--[==[ divide64bitsby32bits(ah, al, b) ]==]
--[==[ numberofleadingzeros(int) ]==]
--[==[ numberoftrailingzeros(int) ]==]
--[==[ numberofleadingzeroslong(long) ]==]
--[==[ numberoftrailingzeroslong(long) ]==]
--[==[ copyarray(source) ]==]
--[==[ cleararray(array) ]==]
--[==[ clearandcopyintoarray(array, newvalues) ]==]
--[==[ swaparrays(thisarray, thatarray) ]==]
--[==[ allocatearray(length) ]==]
--[==[ splitmagnitudeintoblocks(mag, blocklength) ]==]
--[==[ splitarrayatwordfromend(mag, pivot) ]==]
--[==[ gettoomcookslices(mag, fullsize) ]==]
--[==[ signextendwordarrayto(source, destination, newlength) ]==]
--[==[ copyandsignextendwordarray(array, newlength) ]==]
--[==[ destructivesignextendwordarray(array, newlength) ]==]
--[==[ stripleadingzerosto(source, destination) ]==]
--[==[ copyandstripleadingzeros(array) ]==]
--[==[ destructivestripleadingzeros(array) ]==]
--[==[ negatewordarrayto(source, destination) ]==]
--[==[ copyandnegatewordarray(array) ]==]
--[==[ destructivenegatewordarray(array) ]==]
--[==[ gethighestsetbit(mag) ]==]
--[==[ getlowestsetbit(array) ]==]
--[==[ gettype(thing) ]==]
--[==[ getwordarraysignint(array) ]==]
--[==[ getwordarraysign(array) ]==]
--[==[ getwordarraymagnitude(array) ]==]
--[==[ getwordarraysignandmagnitude(array) ]==]
--[==[ getnumbersign(int) ]==]
--[==[ getnumbermagnitude(int) ]==]
--[==[ getnumbersignandmagnitude(int) ]==]
--[==[ getsign(value) ]==]
--[==[ getmagnitude(value) ]==]
--[==[ getsignandmagnitude(value) ]==]
--[==[ gettrustedsignmagnitudewordarray(sign, mag) ]==]
--[==[ getsignmagnitudewordarray(sign, mag) ]==]
--[==[ getwordarray(thing) ]==]
--[==[ createbiginteger(sign, mag) ]==]
do
end


--[==[ constructorinteger(int) ]==]
do
   --[[ positive integer -> pass ]]
   do
      local bi1 = biginteger.constructorinteger(0x01234567)
      
      
      --[[ Check the sign ]]
      assert(bi1.sign == 1, "sign not positive")
      
      
      --[[ Check the magnitude ]]
      assert(#bi1.magnitude == 1 and bi1.magnitude[1] == 0x01234567,
            "magnitude not correct")
      
   end
   
   
   --[[ negative integer -> pass ]]
   do
      local bi2 = biginteger.constructorinteger(-0x01234567)
      
      
      --[[ Check that sign reflects negativity ]]
      if bi2.sign ~= -1 then
         error("sign not negative")
      end
      
      
      --[[ Check that the magnitude is the correct magnitude ]]
      if not (#bi2.magnitude == 1 and bi2.magnitude[1] == 0x01234567) then
         error("magnitude not correct")
      end
   end
   
   
   --[[ table -> error ]]
   do
      local ok, result = pcall(biginteger.constructorinteger, biginteger)
      
      
      if ok then
         error("should have errored")
      end
   end
   
   
   --[[ number too big -> error ]]
   do
      local ok, result = pcall(biginteger.constructorinteger, 2 ^ 64)
      
      
      if ok then
         error("should have errored")
      end
   end
   
   
   --[[ negative number too big -> error ]]
   do
      local ok, result = pcall(biginteger.constructorinteger, -(2 ^ 64))
      
      
      if ok then
         error("should have errored")
      end
   end
   
   
   --[[ float -> error ]]
   do
      local ok, result = pcall(biginteger.constructorinteger, 1.5)
      
      
      if ok then
         error("should have errored")
      end
   end
end



--[==[ constructorsignmagnitudetrusted(sign, mag) ]==]
--[==[ constructorsignmagnitude(sign, mag) ]==]
--[==[ constructorbitsrng(bitlength, randomnumbergenerator) ]==]
--[==[ constructorwordarraytrusted(array) ]==]
--[==[ constructorwordarray(array) ]==]
--[==[ destructivemultiplyandadd(mag, factor, addend) ]==]
--[==[ constructorstringradix(str, radix) ]==]
--[==[ clone(bigint) ]==]
--[==[ biginteger(a, b) ]==]
--[==[ comparemagnitudes(thismag, thatmag) ]==]
--[==[ compare(thisvalue, thatvalue) ]==]
--[==[ equalmagnitudes(thismag, thatmag) ]==]
--[==[ equals(thisbigint, thatbigint) ]==]
--[==[ minimum(...) ]==]
--[==[ maximum(...) ]==]
--[==[ bitwisenotwordarray(wordarray) ]==]
--[==[ bitwisenot(value) ]==]
--[==[ mutablebitwisenot(bigint) ]==]
--[==[ bitwisewordarrays(thisarray, thatarray, mergefunction) ]==]
--[==[ binarybitwise(thisvalue, thatvalue, bitwisefunction, opname) ]==]
--[==[ mutablebinarybitwise(thisbigint, thatvalue, bitwisefunction, opname) ]==]
--[==[ bitwiseand(thisvalue, thatvalue) ]==]
--[==[ mutablebitwiseand(thisbigint, thatvalue) ]==]
--[==[ bitwiseandnot(thisvalue, thatvalue) ]==]
--[==[ mutablebitwiseandnot(thisbigint, thatvalue) ]==]
--[==[ bitwiseor(thisvalue, thatvalue) ]==]
--[==[ mutablebitwiseor(thisbigint, thatvalue) ]==]
--[==[ bitwisexor(thisvalue, thatbigint) ]==]
--[==[ mutablebitwisexor(thisbigint, thatvalue) ]==]
--[==[ destructiveleftshift(mag, displacement) ]==]
--[==[ destructiverightshift(mag, displacement) ]==]
--[==[ copyandleftshift(mag, displacement) ]==]
--[==[ copyandrightshift(mag, displacement) ]==]
--[==[ destructivebitwiseshift(mag, displacement, right) ]==]
--[==[ bitwiseshift(value, displacement, right) ]==]
--[==[ mutablebitwiseshift(bigint, displacement, right) ]==]
--[==[ bitwiseleftshift(value, displacement) ]==]
--[==[ mutablebitwiseleftshift(bigint, displacement) ]==]
--[==[ bitwiserightshift(value, displacement) ]==]
--[==[ mutablebitwiserightshift(bigint, displacement) ]==]
--[==[ destructivebitwiseatbit(wordarray, bitfromend, bitwisefunction) ]==]
--[==[ bitwiseatbit(value, bitfromend, bitwisefunction) ]==]
--[==[ mutablebitwiseatbit(bigint, bitfromend, bitwisefunction) ]==]
--[==[ clearbit(value, bitfromend) ]==]
--[==[ mutableclearbit(bigint, bitfromend) ]==]
--[==[ setbit(value, bitfromend) ]==]
--[==[ mutablesetbit(bigint, bitfromend) ]==]
--[==[ flipbit(value, bitfromend) ]==]
--[==[ mutableflipbit(bigint, bitfromend) ]==]
--[==[ testbit(value, bitfromend) ]==]
--[==[ destructiveaddmagnitudes(thismag, thatmag) ]==]
--[==[ copyandaddmagnitudes(thismag, thatmag) ]==]
--[==[ destructivesubtractmagnitudes(minuend, subtrahend) ]==]
--[==[ copyandsubtractmagnitudes(minuend, subtrahend) ]==]
--[==[ negate(bigint) ]==]
--[==[ mutablenegate(bigint) ]==]
--[==[ absolutevalue(bigint) ]==]
--[==[ mutableabsolutevalue(bigint) ]==]
--[==[ add(thisvalue, thatvalue) ]==]
--[==[ mutableadd(thisbigint, thatvalue) ]==]
--[==[ subtract(thisvalue, thatvalue) ]==]
--[==[ mutablesubtract(thisbigint, thatvalue) ]==]
--[==[ squarecolinplumb(mag) ]==]
--[==[ squarekaratsuba(mag) ]==]
--[==[ destructiveexactdividebythree(mag) ]==]
--[==[ squaretoomcook(mag) ]==]
--[==[ squaremagnitude(mag) ]==]
--[==[ square(value) ]==]
--[==[ mutablesquare(bigint) ]==]
--[==[ multiplycolinplumb(thismag, thatmag) ]==]
--[==[ multiplykaratsuba(thismag, thatmag) ]==]
--[==[ multiplytoomcook(thismag, thatmag) ]==]
--[==[ multiplymagnitudes(thismag, thatmag) ]==]
--[==[ multiply(thisvalue, thatvalue) ]==]
--[==[ mutablemultiply(thisbigint, thatvalue) ]==]
--[==[ raisemagnitude(mag, exponent) ]==]
--[==[ pow(value, exponent) ]==]
--[==[ mutablepow(bigint, exponent) ]==]
--[==[ divideoneword(dividend, divisor) ]==]
--[==[ multiplythensubtract(remainder, div, qhat, offset) ]==]
--[==[ divisoradd(divisor, remainder, offset) ]==]
--[==[ destructivedivideknuth(dividend, divisor) ]==]
--[==[ destructiveadddisjoint(mag, add, blocklength) ]==]
--[==[ divide2n1n(a, b) ]==]
--[==[ divide3n2n(a, b, halfn) ]==]
--[==[ destructivedivideburnikelziegler(dividend, divisor) ]==]
--[==[ dividemagnitudes(dividend, divisor) ]==]
--[==[ division(thisvalue, thatvalue) ]==]
--[==[ divideandremainder(thisvalue, thatvalue) ]==]
--[==[ divide(thisvalue, thatvalue) ]==]
--[==[ remainder(thisvalue, thatvalue) ]==]
--[==[ makestring(thisval, radix) ]==]
--[==[ intstringofradix(i, radix) ]==]
--[==[ smalltostring(thismag, radix) ]==]
--[==[ getpowercache(radix, exponent) ]==]
--[==[ stringbuildrecursive(thismag, radix, digits) ]==]
