// Written in the D programming language.

/**
Dlang transactional programming.

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
module dutil.trx;

version(unittest)
{
    import std.conv : to;
}


/// Backup or change temporarily a variable value (lvalue).
struct ScopeVal(V)
{
    import std.traits : isAssignable;

private:
    alias P = V*;

public:

    /// Constructor remembering the initial value.
    this(ref V init_)
    {
        _init = init_;
        _valueAddr = cast(P)(&init_);
    }

    /**
     * Constructor remembering the initial value and replacing temporarily the
     * variable value.
     */
    this(ref V init_, V value)
    {
        this(init_);
        doAssign(value);
    }

    /**
     * Constructor remembering the initial value and replacing temporarily the
     * variable value.
     */
    this(ref V init_, ref V value)
    {
        this(init_);
        doAssign(value);
    }

    /// Copy constructor.
    this(this T)(auto ref T other)
    {
        this(other.initialValue);
    }

    /// The desctructor puts back the initial variable value.
    ~this()
    {
        doRollback();
    }

    ref T opAssign(this T, X)(auto ref X value)
    if (isAssignable!(V, X))
    {
        doAssign(value);
        return this;
    }

    /// Retrieve the initial value.
    @property ref V initial() { return _init; }

    /// Retrieve the current value.
    @property ref V current() { return *_valueAddr; }

    /// Put back the initial value.
    ref V rollback() { doRollback; return current; }

    /// Keep the new value, forget the initial one.
    ref V release() { doRelease; return current; }

    /// Allow implicit calls to the initial value.
    alias initial this;
private:
    V _init;
    P _valueAddr;
    bool _done;

    @property bool done() { return _done; }
    @property void done(bool b) { _done = b; }

    void doRelease() { if (!done) initial = *_valueAddr; done = true; }

    void doRollback() { if (!done) doAssign(initial); done = true; }

    void doAssign(X)(auto ref X value)
    if (isAssignable!(V, X))
    {
        *_valueAddr = value;
    }
}

/// Backup temporarily a variable value (lvalue).
ScopeVal!(T) bkv(T)(ref T initialValue)
{
    return ScopeVal!(T)(initialValue);
}

/// Backup temporarily a variable value (lvalue).
const(ScopeVal!(T)) cstbkv(T)(ref T initialValue)
{
    return cast(typeof(return)) bkv(initialValue);
}

/// Backup temporarily a variable value (lvalue).
immutable(ScopeVal!(T)) immbkv(T)(ref T initialValue)
{
    return cast(typeof(return)) bkv(initialValue);
}


/// Backup temporarily a variable value (lvalue) and assigns it a temporary one.
ScopeVal!(T) bkv(T)(ref T initialValue, auto ref T value)
{
    return ScopeVal!(T)(initialValue, value);
}

/// Backup temporarily a variable value (lvalue) and assigns it a temporary one.
const(ScopeVal!(T)) cstbkv(T)(ref T initialValue, auto ref T value)
{
    return cast(typeof(return)) bkv(initialValue, value);
}

/// Backup temporarily a variable value (lvalue) and assigns it a temporary one.
immutable(ScopeVal!(T)) immbkv(T)(ref T initialValue, auto ref T value)
{
    return cast(typeof(return)) bkv(initialValue, value);
}


///
unittest
{
    int x = 9;
    {
        auto x9 = bkv(x);

        x = 7;
        assert(x9 == 9);
        assert(x == 7);
    }
    assert(x == 9);

    string s = "some description";
    {
        auto sDescr = bkv(s);

        s = "some other text";
        assert(sDescr == "some description");
        assert(s == "some other text");
    }
    assert(s == "some description");

    import std.math : approxEqual;
    double pi = 3.14;
    {
        auto pickup = bkv(pi);
        pi *= pi;
        assert(pi.approxEqual(pickup * pickup));

        try
        {
            pi += 1;
            auto pickup2p1 = bkv(pi);

            pi *= to!double("3 dot 14");
            assert(pi.approxEqual(1 + pickup2p1 * pickup));
        }
        catch(Exception)
        {
            // pass
        }
        assert(pi.approxEqual(1 + pickup * pickup));
    }
    assert(pi.approxEqual(3.14));
}


/**
 * Rollback a value to its initial state if an exception is thrown, otherwise
 * keep its current state.
 *
 * Parameters:
 *    V = The type of the value to be rolled back if an exception is thrown.
 *    X = The expression type.
 *    E = The exception type, defaulting to `Exception`.
 *    value = The value to be rolled back if an expression
 *
 */
ref V rollbackIfThrown(V, X, E : Throwable = Exception)(ref V value,
                       lazy scope X pression)
{
    auto initial = bkv(value);

    try
    {
        pression();
        return initial.release;
    }
    catch(E xception)
    {
        return initial.rollback;
    }
}

/// rollback unittest
unittest
{
    import std.exception : assertNotThrown;

    struct S
    {
        int i;
        string s;
        double d;

        this(this) { s = s.dup; }
    }

    auto v0 = S(5, "seven", 9.0);
    auto v1 = v0;
    auto v2 = v0;
    assertNotThrown(v2.s = to!string(6.0));

    assert(rollbackIfThrown(v1, v1.i = to!int(v1.s)) == v0,
           "v1 is " ~ to!string(v1) ~ ", v0 is " ~ to!string(v0));

    assert(rollbackIfThrown(v1, v1.s = to!string(6.000)) == v2,
           "v1 is " ~ to!string(v1) ~ ", v2 is " ~ to!string(v2));
}


