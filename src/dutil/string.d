// Written in the D programming language.

/**
String utilities.

Copyright: Copyright Ludovic Dordet 2018.
License:   $(HTTP www.gnu.org/licenses/gpl-3.0.md,
             GNU GENERAL PUBLIC LICENSE 3.0).
Authors:   Ludovic Dordet
*/
/*
         Copyright Ludovic Dordet 2018.
Distributed under the GNU GENERAL PUBLIC LICENSE, Version 3.0.
   (See accompanying file LICENSE.md or copy at
         http://www.gnu.org/licenses/gpl-3.0.md)
*/
module dutil.string;

import std.traits : isSomeString;


/// Objects comparable to a string of type S : `string`, `wstring`, `dstring`.
interface StrEquality(S)
if (isSomeString!S)
{
    /// Check the equality of this object with `data` of type S.
    bool equals(in S data) const;
}

/// Identity converter of an object comparable to a string.
StrEquality!S toStrEq(S, R : StrEquality!S)(auto ref R refData)
{
    return refData;
}

/// Wrap an object which has an equality to string operator.
StrEquality!S toStrEq(S, R)(auto ref R refData)
if (!is(R : StrEquality!S) &&
    __traits(compiles, refData == ""))
{
    class StrEq(S, R) : StrEquality!S
    {
        public this(R)(auto ref R rd) { _refData = rd; }
        bool equals(in S data) const { return _refData == data; }

        private:
            R _refData;
    }

    return new StrEq!(S, R)(refData);
}

/// Wrap an object which has an opCmp to string operator.
StrEquality!S toStrEq(S, R)(auto ref R refData)
if (!is(R : StrEquality!S) &&
    !__traits(compiles, refData == "") &&
     __traits(compiles, refData.opCmp("")))
{
    class StrCmpToEq(S, R) : StrEquality!S
    {
        public this(R)(auto ref R rd) { _refData = rd; }
        bool equals(in S data) const { return _refData.opCmp(data) == 0; }

        private:
            R _refData;
    }

    return new StrCmpToEq!(S, R)(refData);
}


/// Wrap an object which can be translated to string with `to!S(refData)`.
StrEquality!S toStrEq(S, R)(auto ref R refData)
if (!is(R : StrEquality!S) &&
    !__traits(compiles, refData == "") &&
    !__traits(compiles, refData.opCmp("")) &&
    __traits(compiles, to!S(refData)))
{
    class ConvToEq(S, R) : StrEquality!S
    {
        public this(R)(auto ref R rd) { _refData = rd; }
        bool equals(in S data) const { return to!S(_refData) == data; }

        private:
            R _refData;
    }

    return new ConvToEq!(S, R)(refData);
}


