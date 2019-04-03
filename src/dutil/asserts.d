// Written in the D programming language.

/**
Assertion functions.

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
module dutil.asserts;

import std.traits : isAssignable, isSomeString, Unqual;

import dutil.src : srcinfo, SrcInfo;


/**
 * Test a described value against an expected one.
 *
 * In case of assertion failure, the error message contains the description,
 * the actual value and the expected one.
 *
 * Params:
 *   AT = The type of the actual value.
 *   XT = The type of the expected value.
 *   S  = The string type of the description.
 *   actual = The actual value.
 *   expected = The expected value.
 *   description = A description of the value.
 *   file = The source code file.
 *   line = The line in the calling source code.
 *   func = The name of the calling function.
 *   prfn = The detailed description of the calling function.
 *   mod  = The module name of the calling source code.
 */
void assertEquals(AT, XT, S)(auto ref AT actual,
                             auto ref XT expected,
                             auto ref S description,
                             string file=__FILE__,
                             size_t line=__LINE__,
                             string func=__FUNCTION__,
                             string prfn=__PRETTY_FUNCTION__,
                             string mod=__MODULE__)
if (isAssignable!(AT, XT) && isSomeString!S)
{
    auto si = srcinfo(file, line, func, prfn, mod);
    assertEquals(si, actual, expected, description);
}


/**
 * Test a described value against an expected one.
 *
 * In case of assertion failure, the error message contains the description,
 * the actual value and the expected one.
 *
 * Params:
 *   AT = The type of the actual value.
 *   XT = The type of the expected value.
 *   S  = The string type of the description.
 *   actual = The actual value.
 *   expected = The expected value.
 *   description = A description of the value.
 */
void assertEquals(SI, AT, XT, S)(auto ref SI info,
                                 auto ref AT actual,
                                 auto ref XT expected,
                                 auto ref S description)
if (is(SI == SrcInfo) && isAssignable!(AT, XT) && isSomeString!S)
{
    assert(actual == expected,
           format!"\n%s: %s '%s', expected '%s'."
           (info, description, actual, expected));
}


/**
 * Test a described string value against a sequence of expected values
 * comparable or at least assignable to string.
 *
 * In case of assertion failure, the error message contains the description,
 * the actual value and the expected ones.
 *
 * Params:
 *   S  = The string type of the description.
 *   AT = The type of the actual value.
 *   XT = The type of the expected values.
 *   file = The source code file.
 *   line = The line in the calling source code.
 *   func = The name of the calling function.
 *   prfn = The detailed description of the calling function.
 *   mod  = The module name of the calling source code.
 *   description = A description of the value.
 *   actual = The actual value.
 *   expected = The expected values.
 */
void assertEqBySteps(S, AT,
                     string file=__FILE__,
                     size_t line=__LINE__,
                     string func=__FUNCTION__,
                     string prfn=__PRETTY_FUNCTION__,
                     string mod=__MODULE__, XT...)
(auto ref S description,
 auto ref AT actual,
 auto ref XT expected)
if (isSomeString!(AT) && isSomeString!S)
{
    auto si = srcinfo(file, line, func, prfn, mod);
    return assertEqBySteps(si, description, actual, expected);
}


/**
 * Make sure that equality functions between unrelated types are called when
 * available.
 */
private bool customEqual(T, U)(auto ref T t, auto ref U u)
{
    static if (is(T == typeof(null)))
        return (is(U == T));
    else static if (__traits(compiles, t.opEquals(u)))
        return t.opEquals(u);
    else static if (__traits(compiles, u.opEquals(t)))
        return u.opEquals(t);
    else
        return t == u;
}


/**
 * Test a described string value against a sequence of expected values
 * comparable or at least assignable to string.
 *
 * In case of assertion failure, the error message contains the description,
 * the actual value and the expected ones.
 *
 * Params:
 *   SI = The type of the source information.
 *   S  = The string type of the description.
 *   AT = The type of the actual value.
 *   XT = The type of the expected values.
 *   si = The source information (file, line, ...) .
 *   description = A description of the value.
 *   actual = The actual value.
 *   expected = The expected values.
 */
void assertEqBySteps(SI, S, AT, XT...)
(auto ref SI si,
 auto ref S description,
 auto ref AT actual,
 auto ref XT expected)
if (is(Unqual!SI == SrcInfo) && isSomeString!(AT) && isSomeString!S)
{
    // FIXME why is this needed for tests using ApproxTime?
    import std.datetime.date : Date, DateTime, TimeOfDay;
    import std.datetime.systime : SysTime;
    import timeutil : ApproxTime, isDateType, isTimeType, round, toHash;

    // FIXME why don't template opEquals work with ApproxTime?
    /// Compare to a formatted timestamp.
    bool opEquals(ApproxTime!SysTime time, string formatted)
    {
        return time.opCmp(formatted) == 0;
    }

    size_t pos;

    enum EQ_NOT_COMPILES = "'%s == %s' does not compile";

    string spected()
    {
        import std.array : appender;
        auto app = appender!string();

        static foreach(xt; expected)
            app.put(to!string(xt));

        return app.data;
    }

    foreach (xt; expected)
    {
        import std.format : _f=format;
        import std.traits : isBasicType;
        static assert(__traits(compiles, to!AT(xt)));
        static if (!isBasicType!(typeof(xt)))
        {
            static assert(__traits(compiles, { bool b = (xt == actual); }),
                          _f!EQ_NOT_COMPILES(typeof(xt).stringof, AT.stringof));
        }

        immutable AT st = to!AT(xt);
        size_t len = st.length;
        immutable AT at = actual[pos..pos+len];

        static if (isBasicType!(typeof(xt)))
            auto exp = to!AT(xt);
        else
            auto exp = xt;

        assert(customEqual(exp, at),
               _f!"\n%s: %s = '%s', expected '%s'."
               (si, description, at, st) ~
               _f!"\n%s: %s = '%s', expected '%s'."
               (si, description, actual, spected));

        pos += len;
    }
}


