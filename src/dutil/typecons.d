// Written in the D programming language.

/**
Type construction utilities, related to `std.typecons`.

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
module dutil.typecons;

import std.traits : isSomeString;
import std.typecons : tuple;


/// A named tuple with one element.
alias named = tuple!("name", "value");


/**
   Create a specified value, i.e. a structure with a string `spec` with one
   typed `value`.

   Note: the `spec` does not need to be a valid dlang identifier.
*/
template from(alias fmt)
if (isSomeString!(typeof(fmt)))
{
    alias S = typeof(fmt);

    /// Map a runtime value from a string manifest constant.
    struct From(V)
    {
        /// The reference manifest constant.
        enum S spec = fmt;

        /// The runtime value attached to the manifest constant.
        V value;
    }

    auto from(T)(auto ref T value)
    {
        return From!T(value);
    }
}

/// Check whether a value is (compatible with) a `from` instance.
template isFrom(T)
{
    enum bool isFrom =
        __traits(compiles, T.spec) &&
        isSomeString!(typeof(T.spec)) &&
        __traits(compiles, T.init.value) &&
        !is(T.init.value);
}


private template findAll(alias fmt, alias s, size_t startIdx=0UL)
if (isSomeString!(typeof(fmt)) && isSomeString!(typeof(s)))
{
    enum size_t[] findAll = findAllImpl!(fmt, s, startIdx);
}

private template findAllImpl(alias fmt, alias s, size_t startIdx)
if (isSomeString!(typeof(fmt)) && isSomeString!(typeof(s)))
{
    import std.string : indexOf;
    enum nextIdx = fmt.indexOf(s, startIdx);

    static if (nextIdx >= 0)
    {
        enum size_t uNextIdx = to!size_t(nextIdx);
        static if (fmt.length > uNextIdx+s.length)
        {
            enum size_t nextStart = uNextIdx+s.length;
            enum size_t[] findAllImpl =
                [uNextIdx] ~ findAllImpl!(fmt, s, nextStart);
        }
        else
            enum size_t[] findAllImpl = [uNextIdx];
    }
    else
    {
        enum size_t[] findAllImpl = [];
    }
}

/// Translate a string into a tuple of string and other data types.
auto strToTuple(alias data, Args...)(auto ref Args replacements)
if (isSomeString!(typeof(data)))
in
{
    alias S = typeof(data);

    static foreach(Arg; Args)
        static assert(isFrom!Arg);
}
out(result)
{
    import std.typecons : isTuple;
    static assert(isTuple!(typeof(result)));
}
do
{
    import std.array : array;
    import std.algorithm.iteration : map;
    import std.algorithm.sorting : sort;
    import std.string : indexOf;
    import std.typecons : Tuple;

    alias S = typeof(data);
    alias PS = Tuple!(size_t, string);

    enum PS[] PosAndSpecs = {
        size_t[] indexes;
        string[data.length] specs;
        ptrdiff_t idx;

        static foreach(i, Arg; Args)
        {
            mixin("enum argIndexes"~to!string(i)~
                  " = findAll!(data, Arg.spec);");

            static foreach(argIndex; mixin("argIndexes"~to!string(i)))
            {
                specs[argIndex] = Arg.spec;
            }
            indexes ~= mixin("argIndexes"~to!string(i));
        }

        auto toTuple(size_t sz)
        {
            return tuple(sz, specs[sz]);
        }

        auto result = indexes
            .sort
            .map!(toTuple)
            .array;

        if (result)
            return result;

        return [];
    }();

    version(none)
    pragma(msg, __FILE__, "(", __LINE__, "): ", "PosAndSpecs = ", PosAndSpecs);

    auto impl(alias S fmt, alias size_t fmtStart, alias size_t psIdx)()
    {
        static if (psIdx >= PosAndSpecs.length)
            return tuple(fmt[fmtStart..$]);
        else
        {
            enum PS = PosAndSpecs[psIdx];
            enum Pos = PS[0];
            enum S Spec = PS[1];

            enum S fmt0 = fmt[fmtStart..Pos];

            static foreach (repl; replacements)
                static if (repl.spec == Spec)
                    auto r = repl.value;

            static assert(__traits(compiles, is(typeof(r))),
                          format!"replacement not found for '%s'."(Spec));

            static if (Pos + Spec.length < fmt.length)
            {
                static if (Pos > fmtStart)
                    return tuple(tuple(fmt0).expand,
                                 r,
                                 impl!(fmt, Pos+Spec.length, psIdx+1)().expand);
                else
                    return tuple(r,
                                 impl!(fmt, Pos+Spec.length, psIdx+1)().expand);
            }
            else
            {
                static if (Pos > fmtStart)
                    return tuple(tuple(fmt0).expand, r);
                else
                    return tuple(r);
            }
        }
    }

    return impl!(data, 0UL, 0UL)();
}


