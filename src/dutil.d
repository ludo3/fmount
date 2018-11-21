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
import std.array : replace;
import std.conv : to;
import std.format : format;
import std.range.primitives : ElementType, hasLength;
import std.stdio : writeln;
import std.traits: isSomeString;


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


/// Gather source file path, module, line number and function informations.
struct SrcInfo
{
    public:
        /// Constructor with source informations.
        this(string file_, size_t line_, string funcName_,
             string prettyFuncName_, string moduleName_)
        {
            this._file = file_;
            this._line = line_;
            this._moduleName = moduleName_;
            this._funcName = funcName_;
            this._prettyFuncName = prettyFuncName_;
            this._moduleName = moduleName_;
        }

        /// Copy constructor.
        this(this SL)(inout(SL) other)
        {
            this._file = other.file;
            this._line = other.line;
            this._funcName = other.funcName;
            this._prettyFuncName = other.prettyFuncName;
            this._moduleName = other.moduleName;
        }

        /// Retrieve the file path.
        @property string file() const { return _file; }

        /// Retrieve the line number in the file.
        @property size_t line() const { return _line; }

        /// Retrieve the function name.
        @property string funcName() const { return _funcName; }

        /// Retrieve the full function name.
        @property string prettyFuncName() const { return _prettyFuncName; }

        /// Retrieve the module name.
        @property string moduleName() const { return _moduleName; }

        /// Retrieve a short description of the source location.
        @property string shortDescription() const
        {
            return format("@%s(%d): %s ", _file, _line, _funcName);
        }

        /// Retrieve a long description of the source location.
        @property string longDescription() const
        {
            return format("@%s(%d): %s ", _file, _line, _prettyFuncName);
        }

        /// Retrieve module and function detailed informations.
        @property string funcDetails() const
        {
            return format("%s : %s (%d) ", _moduleName, _prettyFuncName, _line);
        }

        /// Common way to retrieve a string description.
        string toString() const { return shortDescription; }

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
        string customDescription(string fmt) const
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
                string moduleName=__MODULE__)
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
        immutable size_t l = __LINE__; immutable info = srcinfo;
        immutable string f = __FILE__;
        immutable string fn = __FUNCTION__;
        immutable string pf = __PRETTY_FUNCTION__;
        immutable string m = __MODULE__;

        immutable ln = to!string(l);

        assert(info.file == f);
        assert(info.line == l);
        assert(info.funcName == fn);
        assert(info.prettyFuncName == pf);
        assert(info.moduleName == m);

        assert(fn == "dutil.__unittest_L"~to!string(l-7)~"_C1.testSrcInfo", fn);
        assert(info.shortDescription == "@src/dutil.d("~ln~"): "~fn~" ");

        string s = info;
        assert(s.equal(info.shortDescription));

        assert(info.longDescription == "@src/dutil.d("~ln~"): "~pf~" ");
        assert(info.funcDetails == m ~ " : " ~ pf ~ " (" ~ ln ~ ") ");

        assert(info.customDescription("") == "");
        immutable _fmt =
            "In ${mod}(${file}), line ${line}: ${func} === ${fargs}";
        assert(info.customDescription(_fmt) ==
            ("In " ~ m ~ "(" ~ f ~ "), line " ~ ln ~ ": "
            ~ fn ~ " === " ~ pf));
    }

    testSrcInfo;
}


/// Describe a file path and line number as`"@file(line): "` .
struct SrcLn
{
    public:
        /// Constructor with a path and line number.
        this(string file_, size_t line_)
        {
            this._file = file_;
            this._line = line_;
            this._fln = format("@%s(%d): ", file, line);
        }

        /// Copy constructor.
        this(this SL)(inout(SL) other)
        {
            this._file = other.file;
            this._line = other.line;
            this._fln = other.fln;
        }

        /// Retrieve the file path.
        @property string file() const { return _file; }

        /// Retrieve the line number in the file.
        @property size_t line() const { return _line; }

        /// Retrieve the full description.
        @property string fln() const { return _fln; }

        /// Common way to retrieve a string description.
        string toString() const { return fln; }

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
SrcLn srcln(string file=__FILE__, size_t line=__LINE__)
{
    return SrcLn(file, line);
}

///
unittest
{
    // Note: the following declarations must be on the same line.
    string f = __FILE__; size_t l = __LINE__; auto fl = srcln;

    assert(fl == "@" ~ f ~ "(" ~ to!string(l) ~ "): ");
}


version(unittest)
{
    import std.stdio : stderr;

    /// Build and remember the "@file(line):" debug prefix.
    struct Dbg
    {
        public:
            /// Constructor with the caller's file and line.
            this(string file_, size_t line_)
            {
                _file = file_.idup;
                _line = line_;
                _prefix = srcln(file_, line_);
            }

            /// Copy constructor.
            this(const ref Dbg other)
            {
                _file = other._file;
                _line = other._line;
            }

            /// Retrieve the caller's file.
            @property string file() const { return _file.idup; }

            /// Retrieve the caller's line.
            @property size_t line() const { return _line; }

            /// Retrieve the debug message prefix, with caller's file and line.
            @property string prefix() const { return _prefix.idup; }

            /// Write a formatted debug information on the standard error file.
            void ln(S, Args...)(lazy S fmt, lazy Args args) const
            if (isSomeString!(typeof(fmt)))
            {
                stderr.write(_prefix);
                static if (args.length == 0)
                    stderr.writeln(fmt);
                else
                    stderr.writefln(fmt, args);
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
        /// Constructor with the caller's file and line.
        this(string file_, size_t line_)
        {
        }

        public:
            /// Copy constructor.
            this(const ref Dbg other)
            {
            }

            /// Retrieve the caller's file.
            @property string file() const { return ""; }

            /// Retrieve the caller's line.
            @property size_t line() const { return size_t.init; }

            /// Retrieve the debug message prefix, with caller's file and line.
            @property string prefix() const { return ""; }

            /// Write a debug information on the standard error file.
            void ln(S...)(lazy S messages) const
            {
            }

            /// Write a formatted debug information on the standard error file.
            void fln(S, Args...)(lazy S fmt, lazy Args args) const
            if (isSomeString!(typeof(fmt)))
            {
            }
    }

}

/// Construct a Dbg formatter with caller's file and line.
Dbg dbg(string file_=__FILE__, size_t line_=__LINE__)
{
    return Dbg(file_, line_);
}

/// Copy a Dbg formatter.
Dbg dbg(ref const Dbg other)
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
struct ScopeVal(V, P=V*)
{
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
        doRelease();
    }

    ref T opAssign(this T)(auto ref V value)
    {
        doAssign(value);
        return this;
    }

    /// Retrieve the initial value.
    @property ref V initialValue() { return _init; }

    /// Put back the initial value.
    V release() { doRelease; return *_valueAddr; }

    /// Allow implicit calls to the initial value.
    alias initialValue this;
private:
    V _init;
    P _valueAddr;

    void doRelease() { doAssign(initialValue); }
    void doAssign(V value) { *_valueAddr = value; }
    void doAssign(ref V value) { *_valueAddr = value; }
}

/// Backup temporarily a variable value (lvalue).
ScopeVal!(T, P) scopeVal(T, P=T*)(ref T initialValue)
{
    return ScopeVal!(T, P)(initialValue);
}

/// Change temporarily a variable value (lvalue).
ScopeVal!(T, P) scopeVal(T, P=T*)(ref T initialValue, auto ref T tempValue)
{
    return ScopeVal!(T, P)(initialValue, tempValue);
}

///
unittest
{
    int x = 9;
    {
        auto x9 = scopeVal(x);

        x = 7;
        assert(x9 == 9);
        assert(x == 7);
    }
    assert(x == 9);

    string s = "some description";
    {
        auto sDescr = scopeVal(s);

        s = "some other text";
        assert(sDescr == "some description");
        assert(s == "some other text");
    }
    assert(s == "some description");

}


