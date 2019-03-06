// Written in the D programming language.

/**
Dlang related utilities.

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
module dutil;
import std.array : appender, array, replace;
import std.conv : to;
import std.exception : ifThrown;
import std.format : format;
import std.range.primitives : ElementType, hasLength, isInputRange;
import std.stdio : writeln;
import std.traits: isArray, isAssignable, isIntegral, isScalarType,
                   isSomeString, Unqual;


/// Used to describe read-only, write-only and read-write properties.
enum RW : string
{
    /// Read-Only
    RO = "Read",

    /// Read-Write
    RW = "ReadWrite",

    /// Write-Only
    WO = "Write",
}


/**
 * Print one throwable (exception, error).
 *
 * This function can be used with `Throwable.opApply`.
 *
 * Params:
 *     th = the throwable to be printed.
 */
int defaultPrintTh(Throwable th)
{
    writeln(th.toString());
    return 0;
}


/**
 * The delegate used by `printThChain`.
 */
int function(Throwable) print1Throwable = &defaultPrintTh;


/**
 * Print the throwable chain.
 * Params:
 *     th = the throwable to be printed, starting the throwable chain.
 */
void printThChain(Throwable th)
{
    // Note https://tour.dlang.org/tour/en/gems/opdispatch-opapply
    foreach(Throwable inChain; th)
        print1Throwable(inChain);
}


/**
    Gather source file path, module, line number and function informations
    at compile time but in a modular way.
*/
struct Src
{
    @disable this();
    @disable this(this);

    /** Shorthand for `__FILE__`. */
    static string f(string fileName=__FILE__)()
    {
        return fileName;
    }

    /** Shorthand for `__LINE__`. */
    static size_t l(size_t line=__LINE__)()
    {
        return line;
    }

    /** Shorthand for `__FUNCTION__`. */
    static string fn(string functionName=__FUNCTION__)()
    {
        return functionName;
    }

    /**
       Shorthand for `__PRETTY_FUNCTION__` : function signature.

       Returns: A string with the return type, function name, argument types
                and names, function attributes.
     */
    static string fs(string signature =__PRETTY_FUNCTION__)()
    {
        return signature;
    }

    /** Shorthand for `__MODULE__`. */
    static string m(string moduleName=__MODULE__)()
    {
        return moduleName;
    }

}

/// `Src.fl`, `Src.ln`,
unittest
{
    enum string pfx = __FUNCTION__;
    import std.format: _f=format;

    with(Src)
    {
        assert(f == __FILE__);
        assert(f == srcln.file);
        assert(l == __LINE__);
        assert(l == __LINE__);

        enum l3 = l;
        enum l4 = l;
        assert(l4 == l3 + 1);

        assert(l == srcln.line);
        assert(l == srcinfo.line);

        void testFunction()
        {
            assert(fn == pfx ~ ".testFunction",
                   format!"fn is %s"(fn));
            assert(fs == _f!"void %s.testFunction()"(pfx),
                   format!"fs is %s"(fs));
        }

        long testFunctionFloat(float unusedArg)
        {
            assert(unusedArg == 0.0);
            assert(fn == pfx ~ ".testFunctionFloat",
                   format!"fn is %s"(fn));
            assert(fs == _f!"long %s.testFunctionFloat(float unusedArg)"(pfx),
                   format!"fs is %s"(fs));

            return cast(long)(unusedArg);
        }

        double testFunctionInt(int unusedArg)
        {
            assert(unusedArg == 0);
            assert(fn == pfx ~ ".testFunctionInt", format!"fn is %s"(fn));
            assert(fs == _f!"double %s.testFunctionInt(int unusedArg)"(pfx),
                   format!"fs is %s"(fs));

            return cast(double) unusedArg;
        }

        testFunction();
        testFunctionFloat(0.0);
        testFunctionInt(0);

        assert(m == __MODULE__);
    }
}

/// Gather source file path, module, line number and function informations.
struct SrcInfo
{
    public:
        /// Constructor with source informations.
        this(string file_, size_t line_, string funcName_,
             string prettyFuncName_, string moduleName_) @safe pure
        {
            this._file = file_;
            this._line = line_;
            this._moduleName = moduleName_;
            this._funcName = funcName_;
            this._prettyFuncName = prettyFuncName_;
            this._moduleName = moduleName_;
        }

        /// Copy constructor.
        this(this SL)(inout(SL) other) @safe pure
        {
            this._file = other.file;
            this._line = other.line;
            this._funcName = other.funcName;
            this._prettyFuncName = other.prettyFuncName;
            this._moduleName = other.moduleName;
        }

        /// Duplicate with a new line.
        SL withLine(this SL)(size_t line_=__LINE__) @safe pure
        {
            return SL(file, line_, funcName, prettyFuncName, moduleName);
        }

        /// Retrieve the file path.
        @property string file() const @safe pure { return _file; }

        /// Retrieve the line number in the file as a signed integer.
        @property int iLine() const @safe pure { return to!int(_line); }

        /// Retrieve the line number in the file.
        @property size_t line() const @safe pure { return _line; }

        /// Retrieve the line number in the file as a string.
        @property string sLine() const @safe pure { return to!string(line); }

        /// Retrieve the function name.
        @property string funcName() const @safe pure { return _funcName; }

        /// Retrieve the full function name.
        @property string prettyFuncName() const @safe pure
        {
            return _prettyFuncName;
        }

        /// Retrieve the module name.
        @property string moduleName() const @safe pure { return _moduleName; }

        /// Retrieve a short description of the source location.
        @property string shortDescription() const @safe pure
        {
            return format("@%s(%d): ", _file, _line);
        }

        /// Retrieve a long description of the source location.
        @property string longDescription() const @safe pure
        {
            return format("@%s(%d): %s ", _file, _line, _prettyFuncName);
        }

        /// Retrieve module and function detailed informations.
        @property string funcDetails() const @safe pure
        {
            return format("%s : %s (%d) ", _moduleName, _prettyFuncName, _line);
        }

        /// Common way to retrieve a string description.
        string toString() const @safe pure { return shortDescription; }

        /**
         * Create a custom description.
         *
         * The following keys are simply replaced with their actual values:
         *
         * $(BOOKTABLE The following keys are simply replaced with their actual
         * values:, $(TR $(TH Key) $(TH Value))
         *
         * $(TR $(TD $B( "${file}")) $(TD The file path.))
         *
         * $(TR $(TD $B( "${line}")) $(TD The line.))
         *
         * $(TR $(TD $(B "${func}")) $(TD The function name.))
         *
         * $(TR $(TD $(B "${fargs}")) $(TD The function return type, name and
         * argument types.))
         *
         * $(TR $(TD $(B "${mod}")) $(TD The module name.))
         * )
         */
        string customDescription(string fmt) const @safe pure
        {
            if (fmt is null || fmt.length == 0)
                return fmt;

            return fmt.replace("${file}", file)
                      .replace("${line}", to!string(line))
                      .replace("${func}", funcName)
                      .replace("${fargs}", prettyFuncName)
                      .replace("${mod}", moduleName);
        }

        /// Use this struct as a `"@file(line): "` string value.
        alias shortDescription this;

    private:
        string _file;
        size_t _line;
        string _funcName;
        string _prettyFuncName;
        string _moduleName;

        /**
         * DLang specification: No default constructor available if at least one
         * with parameters exists.
         */
        @disable this();
}

/// Create an SrcInfo instance.
SrcInfo srcinfo(string file=__FILE__,
                size_t line=__LINE__,
                string funcName=__FUNCTION__,
                string prettyFuncName=__PRETTY_FUNCTION__,
                string moduleName=__MODULE__) @safe pure
{
    return SrcInfo(file, line, funcName, prettyFuncName, moduleName);
}

///
unittest
{
    import std.algorithm.comparison : equal;

    void testSrcInfo()
    {
        // Note: the following declarations must be on the same line.
        immutable size_t l = __LINE__; immutable inf0 = srcinfo;
        immutable string f = __FILE__;
        immutable string fn = __FUNCTION__;
        immutable string pf = __PRETTY_FUNCTION__;
        immutable string m = __MODULE__;

        immutable ln = to!string(l);

        assert(inf0.file == f);
        assert(inf0.line == l);
        assert(inf0.funcName == fn);
        assert(inf0.prettyFuncName == pf);
        assert(inf0.moduleName == m);

        assert(fn == "dutil.__unittest_L"~to!string(l-7)~"_C1.testSrcInfo", fn);
        assert(inf0.shortDescription == "@src/dutil.d("~ln~"): ");

        string s = inf0;
        assert(s.equal(inf0.shortDescription));

        assert(inf0.longDescription == "@src/dutil.d("~ln~"): "~pf~" ");
        assert(inf0.funcDetails == m ~ " : " ~ pf ~ " (" ~ ln ~ ") ");

        assert(inf0.customDescription("") == "");
        immutable _fmt =
            "In ${mod}(${file}), line ${line}: ${func} === ${fargs}";
        assert(inf0.customDescription(_fmt) ==
            ("In " ~ m ~ "(" ~ f ~ "), line " ~ ln ~ ": "
            ~ fn ~ " === " ~ pf));
    }

    testSrcInfo;
}


/// Gather source file path, module, line number and function informations.
struct SrcLoc(size_t line_, string file_, string function_, string signature_,
              string module_)
{
    /// The line number in the source file.
    enum size_t LINE = line_;

    /// The line number in the source file as a string.
    enum string SLINE = to!string(line_);

    /// The source file.
    enum string FILE = file_;

    /// The function name.
    enum string FUNCTION = function_;

    /// The full function return type, name and argument type and names.
    enum string SIGNATURE = signature_;

    /// The module name.
    enum string MODULE = module_;

    /// Retrieve a short description of the source location.
    enum string SHORT_DESCR = format!"@%s(%d): "(FILE, LINE);

    /// Retrieve a long description of the source location.
    enum string LONG_DESCR = format!"@%s(%d): %s "(FILE, LINE, SIGNATURE);

    /// Retrieve module and function detailed informations.
    enum string FUNC_DETAILS =
        format!"%s : %s (%d) "(MODULE, SIGNATURE, LINE);

    /**
     * Create a custom description.
     *
     * The following keys are simply replaced with their actual values:
     *
     * $(BOOKTABLE The following keys are simply replaced with their actual
     * values:, $(TR $(TH Key) $(TH Value))
     *
     * $(TR $(TD $B( "${file}")) $(TD The file path.))
     *
     * $(TR $(TD $B( "${line}")) $(TD The line.))
     *
     * $(TR $(TD $(B "${func}")) $(TD The function name.))
     *
     * $(TR $(TD $(B "${fargs}")) $(TD The function return type, name and
     * argument types.))
     *
     * $(TR $(TD $(B "${mod}")) $(TD The module name.))
     * )
     */
    template customDescr(string fmt)
    {
        static if (fmt is null || fmt.length == 0)
            enum customDescr = fmt;
        else
            enum customDescr = fmt.replace("${file}", FILE)
                                  .replace("${line}", SLINE)
                                  .replace("${func}", FUNCTION)
                                  .replace("${fargs}", SIGNATURE)
                                  .replace("${mod}", MODULE);
    }

    /// Use this struct as a `"@file(line): "` string value.
    alias SHORT_DESCR this;

    /// Create an `SrcInfo` instance from this `SrcLoc` template.
    static SrcInfo toSrcInfo() @safe pure
    {
        return srcinfo(FILE, LINE, FUNCTION, SIGNATURE, MODULE);
    }
}


/// Create an SrcInfo instance.
SrcLoc!(line_, file_, function_, signature_, module_)
srcloc(size_t line_=__LINE__,
       string file_=__FILE__,
       string function_=__FUNCTION__,
       string signature_=__PRETTY_FUNCTION__,
       string module_=__MODULE__)() @safe pure
{
    return SrcLoc!(line_, file_, function_, signature_, module_)();
}

/// srcloc
unittest
{
    import std.algorithm.comparison : equal;

    void testSrcLoc()
    {
        // Note: the following declarations must be on the same line.
        immutable size_t l = __LINE__; immutable info = srcloc;
        immutable string f = __FILE__;
        immutable string fn = __FUNCTION__;
        immutable string pf = __PRETTY_FUNCTION__;
        immutable string m = __MODULE__;

        immutable ln = to!string(l);

        assert(info.FILE == f);
        assert(info.LINE == l);
        assert(info.FUNCTION == fn);
        assert(info.SIGNATURE == pf);
        assert(info.MODULE == m);

        assert(fn == "dutil.__unittest_L"~to!string(l-7)~"_C1.testSrcLoc", fn);
        assert(info.SHORT_DESCR == "@src/dutil.d("~ln~"): ");

        string s = info;
        assert(s.equal(info.SHORT_DESCR));

        assert(info.LONG_DESCR == "@src/dutil.d("~ln~"): "~pf~" ");
        assert(info.FUNC_DETAILS == m ~ " : " ~ pf ~ " (" ~ ln ~ ") ");

        assert(info.customDescr!("") == "");
        enum string _fmt =
            "In ${mod}(${file}), line ${line}: ${func} === ${fargs}";
        assert(info.customDescr!(_fmt) ==
            ("In " ~ m ~ "(" ~ f ~ "), line " ~ ln ~ ": "
            ~ fn ~ " === " ~ pf));

        immutable sameInfo = info;

        assert(sameInfo.FILE == f);
        assert(sameInfo.LINE == l);
        assert(sameInfo.FUNCTION == fn);
        assert(sameInfo.SIGNATURE == pf);
        assert(sameInfo.MODULE == m);

        immutable inf2 = srcloc;
        assert(inf2.FILE == f);
        assert(inf2.LINE == __LINE__-2);
        assert(inf2.FUNCTION == fn);
        assert(inf2.SIGNATURE == pf);
        assert(inf2.MODULE == m);
    }

    testSrcLoc;
}

/// Check whether a type is an `SrcLoc` instance.
template isSrcLoc(SL)
{
    enum bool isSrcLoc =
        __traits(compiles, SL.LINE) &&
        __traits(compiles, SL.FILE) &&
        __traits(compiles, SL.FUNCTION) &&
        __traits(compiles, SL.SIGNATURE) &&
        __traits(compiles, SL.MODULE);
}

/// isSrcLoc
unittest
{
    immutable info = srcloc;
    immutable inf2 = srcloc;
    static assert(inf2.LINE == info.LINE + 1);
    static assert(!is(typeof(inf2) : typeof(info)));
    assert(isSrcLoc!(typeof(info)));
    assert(isSrcLoc!(typeof(inf2)));
}


/// Describe a file path and line number as`"@file(line): "` .
struct SrcLn
{
    public:
        /// Constructor with a path and line number.
        this(string file_, size_t line_) @safe pure
        {
            this._file = file_;
            this._line = line_;
            this._fln = format("@%s(%d): ", file, line);
        }

        /// Copy constructor.
        this(this SL)(inout(SL) other) @safe pure
        {
            this._file = other.file;
            this._line = other.line;
            this._fln = other.fln;
        }

        /// Retrieve the file path.
        @property string file() const  @safe pure { return _file; }

        /// Retrieve the line number in the file.
        @property size_t line() const @safe pure { return _line; }

        /// Retrieve the full description.
        @property string fln() const  @safe pure { return _fln; }

        /// Common way to retrieve a string description.
        string toString() const @safe pure{ return fln; }

        /// Use this struct as a `"@file(line): "` string value.
        alias fln this;

    private:
        /**
         * DLang specification: No default constructor available if at least one
         * with parameters exists.
         */
        @disable this();

        string _file;
        size_t _line;
        string _fln;
}

/// Create an SrcLn instance with a source path and line number.
SrcLn srcln(string file=__FILE__, size_t line=__LINE__) @safe pure
{
    return SrcLn(file, line);
}

///
unittest
{
    // Note: the following declarations must be on the same line.
    immutable string f = __FILE__; size_t l = __LINE__; auto fl = srcln;

    assert(fl == "@" ~ f ~ "(" ~ to!string(l) ~ "): ");
}


version(unittest)
    debug=1;

debug
{
    import std.stdio : stderr;

    /// Build and remember the "@file(line):" debug prefix.
    struct Dbg
    {
        public:
            /// `true` when run from unit tests.
            enum bool enabled = true;

            /// Constructor with the caller's file and line.
            this(string file_, size_t line_) @safe pure
            {
                _file = file_.idup;
                _line = line_;
                _prefix = srcln(file_, line_);
            }

            /// Copy constructor.
            this(const ref Dbg other) @safe pure
            {
                _file = other._file;
                _line = other._line;
            }

            /// Retrieve the caller's file.
            @property string file() const @safe pure { return _file.idup; }

            /// Retrieve the caller's line.
            @property size_t line() const @safe pure { return _line; }

            /// Retrieve the debug message prefix, with caller's file and line.
            @property string prefix() const @safe pure { return _prefix.idup; }

            /// Write a formatted debug information on the standard error file.
            ref Dbg ln(alias fmt, Args...)(lazy Args args) @trusted
            if (isSomeString!(typeof(fmt)))
            {
                return ln(fmt, args);
            }

            /// Write a formatted debug information on the standard error file.
            ref Dbg ln(S, Args...)(lazy S fmt, lazy Args args) @trusted
            if (isSomeString!(typeof(fmt)))
            {
                stderr.write(_prefix);
                static if (args.length == 0)
                    stderr.writeln(fmt);
                else
                    stderr.writefln(fmt, args);

                return this;
            }

        private:
            string _file;
            size_t _line;
            string _prefix;
    }

}
else
{
    import std.traits : isSomeString;

    /// Build and remember the "@file(line):" debug prefix.
    struct Dbg
    {
        /// `true` when run from unit tests.
        enum bool enabled = false;

        /// Constructor with the caller's file and line.
        this(string file_, size_t line_) @safe pure
        {
        }

        public:
            /// Copy constructor.
            this(const ref Dbg other) @safe pure
            {
            }

            /// Retrieve the caller's file.
            @property string file() const @safe pure { return ""; }

            /// Retrieve the caller's line.
            @property size_t line() const @safe pure { return size_t.init; }

            /// Retrieve the debug message prefix, with caller's file and line.
            @property string prefix() const @safe pure { return ""; }

            /// Write a formatted debug information on the standard error file.
            ref Dbg ln(alias fmt, Args...)(lazy Args args) @trusted
            if (isSomeString!(typeof(fmt)))
            {
                return ln(args);
            }

            /// Write a debug information on the standard error file.
            ref Dbg ln(S, Args...)(lazy S fmt, lazy Args args) @trusted
            if (isSomeString!(typeof(fmt)))
            {
                unused(fmt);
                unused(args);
                return this;
            }
    }

}

/// Construct a Dbg formatter with caller's file and line.
Dbg dbg(string file_=__FILE__, size_t line_=__LINE__) @safe pure
{
    return Dbg(file_, line_);
}

/// Copy a Dbg formatter.
Dbg dbg(ref const Dbg other) @safe pure
{
    return Dbg(other);
}

/// dbg tests.
unittest
{
    dbg.ln("dbg.ln");
    dbg.ln("dbg.ln %%d => %d", 1);
}


/// Backup or change temporarily a variable value (lvalue).
struct ScopeVal(V)
{
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


/// Sleeps the current thread the specified number of duration units.
void sleep(T, alias unit="msecs")(T nbUnits)
if (isScalarType!(T) && isSomeString!(typeof(unit)))
{
    import core.thread : dur, Thread;
    Thread.sleep( dur!unit(nbUnits) );
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
    import std.range.primitives : isInputRange;

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
    // needed for tests using ApproxTime.
    import std.datetime.date : Date, DateTime, TimeOfDay;
    import std.datetime.systime : SysTime;
    import dateutil : ApproxTime, isDateType, isTimeType, round, toHash;

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


/**
 * Make sure that a functionally unused argument is indeed used by the compiler.
 *
 * Params:
 *   T   = The type of an unused argument.
 *   arg = An unused argument or lvalue.
 */
void unused(T)(auto ref T arg)
{
    static assert(__traits(compiles, typeof(arg)));
}

/**
 * Make sure that some functionally unused arguments are indeed used by the
 * compiler.
 *
 * Params:
 *   Args = A sequence of types.
 *   args = A sequence of values.
 */
void unused(Args...)(auto ref Args args)
if (Args.length >= 2)
{
    static foreach(arg; args)
        unused(arg);
}

/**
 * Make sure that an empty list of  arguments is indeed used by the
 * compiler.
 *
 * Params:
 *   Args = An empty sequence of types.
 *   args = An empty sequence of values.
 */
void unused()
{
    // nothing to do
}

///
unittest
{
    void f1(int i) { unused(i); }
    void f2(int j, string s) { unused(s, j); }

    f1(3);
    f2(7, "seven");

    void f0(T...)(T args) { unused(args); }
    f0();
    f0(1,2,3);
}


import std.typecons : tuple, isTuple;

/**
 * Create a sequence of typed values.
 *
 * Params:
 *   Args = A sequence of types, known as `AliasSeq`.
 *   args = A sequence of function arguments.
 */
auto varArgs(Args...)(auto ref Args args)
out(result)
{
    static assert(isTuple!(typeof(result)));
}
do
{
    return tuple(args);
}


/// Objects comparable to a string of type S : `string`, `wstring`, `dstring`.
interface StrEquality(S)
if (isSomeString!S)
{
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


/// Create a named value, i.e. a named tuple with one named element.
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
    import std.range : isRandomAccessRange;
    import std.typecons : isTuple;

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
        ptrdiff_t idx=0L;

        static foreach(i, Arg; Args)
        {
            mixin("enum argIndexes"~to!string(i)~" = findAll!(data, Arg.spec);");

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


/+
auto strToStrEqs(string data, Args...)(auto ref Args replacements)
if (isSomeString!(typeof(data)))
out(result)
{
/+
    import std.range.primitives : isInputRange;
    static assert(isInputRange!(typeof(result)));
+/
}
do
{
    import std.algorithm.sorting : sort;
    import std.container.dlist : DList;
    import std.range : isRandomAccessRange;
    import std.string : indexOf;
    import std.traits : isArray;
    import std.typecons : tuple, Tuple;
    alias S = typeof(data);

    static foreach(Arg; Args)
    {
        static assert(isTuple!Arg || isRandomAccessRange!Arg || isArray!Arg);
        static assert(isSomeString!(typeof(Arg.init[0])));
        static assert(is(typeof(Arg.init[0]) == S));
    }

    alias StrEq = StrEquality!S;
    alias PosAndRepl = Tuple!(size_t, StrEquality!S);
    alias PosAndRepls = PosAndRepl[];

    void updateOrderedRepls(R)(auto ref R repl, ref PosAndRepls posNRepls)
    {
        S spec = repl[0];
        ptrdiff_t pos = data.indexOf(spec);
        if (pos >= 0)
        {
            auto strEq = toStrEq!S(repl[1]);
            posNRepls ~= PosAndRepl(pos, strEq);
        }
    }

    PosAndRepls posNRepls =
    {
        PosAndRepls buildingOrderedRepls;
        static foreach(i; 0..Args.length)
        {
            updateOrderedRepls(replacements[i], buildingOrderedRepls);
        }

        return sort!"a[0] < b[0]"(buildingOrderedRepls).array;
    }();

    auto result = DList!StrEq();
    size_t dataPos;

    foreach(posAndRepl; posNRepls)
    {
        size_t pos = posAndRepl[0];

        if (dataPos < pos)
            result ~= toStrEq!S(data[dataPos..pos]);

        result ~= toStrEq!S(posAndRepl[1]);
        dataPos = pos + 2;
    }

    if (dataPos < data.length)
        result ~= toStrEq!S(data[dataPos..$]);

    return result;
}
+/

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

// GlobVar usage.
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


/// Check whether type `T` is a structured type: struct, union or class.
template isStructured(T)
{
    enum bool isStructured =
        is(T == struct) ||
        is(T == union) ||
        is(T == class);
}


/**
   Check whether a structured type `T` has a field of type `F` named `name`.
 */
template hasTypedField(T, F, string name)
//fails with Tuple : why? ==> if (isStructured!T)
{
    import std.traits: Fields, FieldNameTuple, isAssignable;

    static assert(isStructured!T, T.stringof ~ " is not a structured type.");

    enum bool hasTypedField = {
        static foreach(i, ft; Fields!T)
        {
            if (FieldNameTuple!T[i] == name)
            {
                // Found field `name`
                return isAssignable!(F, ft);
            }
        }

        return false;
    }();
}


/**
   Check whether a structured type has the expected field types and names.

   Each field type is expected to be followed by its name.
 */
template hasTypedFields(T, TypedNames...)
{
    import std.format : _f=format;
    import std.meta : Stride;
    import std.traits: isExpressions, isTypeTuple;

    static assert(isTypeTuple!(Stride!(2, TypedNames)),
        _f!"Expected a list of types instead of '%s'.\nPlease check '%s'."
           (Stride!(2, TypedNames).stringof,
            Stride!(2, TypedNames).stringof));

    enum bool hasTypedFields = {
        bool htf = true;

        foreach (i, ft; Stride!(2, TypedNames))
        {
            static assert(is(ft),
                _f!"Expected a type instead of '%s'."(ft.stringof));

            static assert(isExpressions!(TypedNames[2*i+1])
                      && isSomeString!(typeof(TypedNames[2*i+1])),
                _f!"Expected a field name instead of '%s'."
                   (TypedNames[2*i+1].stringof));

            if (!(hasTypedField!(T, ft, TypedNames[2*i+1])))
            {
                htf = false;
                break;
            }
        }

        return htf;
    }();
}

/// `hasTypedFields`
unittest
{
    struct S
    {
        int i1;
        long L2;
        int[] arr;
    }

    class C
    {
        string len;
        size_t sz;
    }

    assert(hasTypedField!(S, int[], "arr"));
    assert(hasTypedFields!(S, long, "L2", int, "i1"));

    assert(hasTypedField!(C, string, "len"));
    assert(hasTypedFields!(C, string, "len", size_t, "sz"));
}



