// Written in the D programming language.

/**
Dlang source file utilities.

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
module dutil.src;

import std.array : replace;
import std.conv : to;
import std.format : format;


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

        assert(fn == "dutil.src.__unittest_L"~to!string(l-7)~"_C1.testSrcInfo",
               fn);
        assert(inf0.shortDescription == "@src/dutil/src.d("~ln~"): ",
               inf0.shortDescription);

        string s = inf0;
        assert(s.equal(inf0.shortDescription));

        assert(inf0.longDescription == "@src/dutil/src.d("~ln~"): "~pf~" ");
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


/**
 * Gather source file path, module, line number and function informations.
 *
 * `SrcLoc` should be used from template definitions.
 */
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

        assert(fn == "dutil.src.__unittest_L"~to!string(l-7)~"_C1.testSrcLoc",
               fn);
        assert(info.SHORT_DESCR == "@src/dutil/src.d("~ln~"): ");

        string s = info;
        assert(s.equal(info.SHORT_DESCR));

        assert(info.LONG_DESCR == "@src/dutil/src.d("~ln~"): "~pf~" ");
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


