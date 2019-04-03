// Written in the D programming language.

/**
Global variable generators.

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
module dutil.globvar;

import std.format : format;


mixin template GlobVar(T, int i=-1, string name="gvar%d")
{
    import std.string : indexOf;

    static if (i >= 0)
    {
        static if (name.indexOf('%') >= 0)
            mixin(format!("__gshared %s " ~ name ~ ";")(T.stringof, i));
        else
            mixin GlobVar!(T, i, name ~ "%d");
    }
    else
    {
        static if (name.indexOf('%') < 0)
            mixin(format!("__gshared %s " ~ name ~ ";")(T.stringof));
        else
        {
            import std.array : replace;
            mixin GlobVar!(T, i, name.replace("%d", ""));
        }
    }
    /+
    static if (i >= 0 && name.indexOf('%') >= 0)
        mixin(format!("__gshared %s " ~ nameFmt ~ ";")(T.stringof, i));
    else
        mixin(format!("__gshared %s " ~ nameFmt ~ ";")(T.stringof));
        +/
}

mixin template GlobVar(T, string name="gvar")
{
    import std.string : indexOf;
    static assert(name.indexOf('%') < 0);

    mixin GlobVar!(T, -1, name);
}

/// GlobVar usage.
unittest
{
    struct S { string s; }
    class C { char c; }
    interface I {}
    class Impl : I {}

    mixin GlobVar!(int, 0, "gvar%d");

    mixin GlobVar!(S, 1);
    mixin GlobVar!(C, 2);
    mixin GlobVar!(I, "theI");

    mixin GlobVar!(string, 7, "description%d");
    mixin GlobVar!(ulong, "longUnsignedGV");

    static assert(__traits(compiles, gvar0 = 5));
    gvar0 = 5;

    static assert(__traits(compiles, gvar1.s = "content"));
    gvar1.s = "content";

    static assert(__traits(compiles, gvar2 = new C()));
    gvar2 = new C();

    static assert(__traits(compiles, gvar2.c = '*'));
    gvar2.c = '*';

    static assert(__traits(compiles, theI = new Impl));
    theI = new Impl;

    // TODO test description7
    // TODO test longUnsignedGV
}


/**
   Create a global variable by calling an initializer.

   Implementation details:
   ----
   // An inline spinlock is used to make sure the initializer is only run once.
   // It is assumed there will be at most uint.max / 2 threads trying to
   // initialize the global variable at once and steal the high bit is stolen
   // to indicate that the globals have been initialized.
   ----

   Code inspired by `std.stdio.makeGlobal`.
 */
// TODO generic instanciation/initialization specific to class/interface
/+
@property ref T mkGlob(T, Args...)(void delegate(ref T, ref Args) initialize)
{
    __gshared T result;
    __gshared Args gvars;

    static foreach(i, Arg; Args)
    {
        GlobVar!(Arg, i, "gvar%d");
    }

    static shared uint spinlock;
    import core.atomic : atomicLoad, atomicOp, MemoryOrder;
    if (atomicLoad!(MemoryOrder.acq)(spinlock) <= uint.max / 2)
    {
        for (;;)
        {
            if (atomicLoad!(MemoryOrder.acq)(spinlock) > uint.max / 2)
                break;
            if (atomicOp!"+="(spinlock, 1) == 1)
            {
                initialize(result, args);
                static foreach(i, Arg; Args)
                {
                    mixin(format!"gvar%d = gvars[i];"(i));
                }

                atomicOp!"+="(spinlock, uint.max / 2);
                break;
            }
            atomicOp!"-="(spinlock, 1);
        }
    }
    return result;
}
+/

private mixin template _do_mkGlob()
{

}

unittest
{
    struct S { string s; }
    interface I { char c(); }
    class C : I
    {
        private char _c;
        this(char c_) { _c = c_; }
        char c() { return _c; }
    }

    int createGlobIntTest()
    {
        return 3;
    }

    void initGlobIntTest(ref int i)
    {
        i = createGlobIntTest();
    }

    S createGlobStructTest()
    {
        S s;
        return s;
    }

    void initGlobStructTest(ref S s)
    {
        s = createGlobStructTest();
        s.s = "structTest";
    }

    C createGlobCTest()
    {
        return new C('+');
    }

    void initGlobClassTest(ref C c)
    {
        c = createGlobCTest();
    }

    I createGlobInterfaceTest()
    {
        return createGlobCTest();
    }

    void initGlobInterfaceTest(ref I i)
    {
        i = createGlobInterfaceTest();
    }


    /+
    void delegate(ref int) initialize = &initGlobIntTest;
    alias globInt = mkGlob!(int, initialize);
    i = createGlobIntTest();
    +/
    /+
    alias globInt = mkGlob!(int, &initGlobIntTest);
    => src/dutil.d(1062,21): Error: template instance
            `mkGlob!(int, initGlobIntTest)`
       does not match template declaration
            `mkGlob(T, void delegate(ref T) initialize)()`
            +/
    // TODO test with struct, class, interface
}



