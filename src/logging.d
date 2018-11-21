// Written in the D programming language.

/**
Dlang application logging.

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
module logging;
import std.conv : to;
import std.format : format;
import std.range.primitives : ElementType, hasLength;
import std.stdio : stderr, writeln;
import std.traits: EnumMembers, isOrderingComparable, isSomeString;

import argsutil : VbLevel, verbose;
import dutil: srcinfo, SrcInfo;

/**
 * Log information if the logging level is enabled, with an optional prefix with
 * file and line.
 */
struct LoggerT(Lvl)
if (is(Lvl == enum) &&
    isOrderingComparable!Lvl)
{
    public:
        /**
         * Constructor for an uninitialized logger.
         *
         * The current level cannot be used.
         *
         * Params:
         *   minimumLevel     =  the minimum logging level
         */
        this(Lvl minimumLevel)
        {
            _minLevel = minimumLevel;
        }

        /**
         * Constructor.
         *
         * Params:
         *   currentLevel_    =  the minimum logging level
         *   minimumLevel     =  the minimum logging level
         */
        this(ref Lvl currentLevel_, Lvl minimumLevel)
        {
            _minLevel = minimumLevel;
            _pCurrentLevel = &currentLevel_;
        }

        /// Copy constructor.
        this(this L)(L other)
        {
            _minLevel = other._minLevel;
            _pCurrentLevel = other._pCurrentLevel;
        }

        /// Retrieve the minimum level for which logging is enabled.
        @property Lvl minLevel() inout { return _minLevel; }

        /// Retrieve the current logging level.
        @property Lvl currentLevel() inout {
            if (_pCurrentLevel is null)
                return Lvl.init;

            return *_pCurrentLevel;
        }

        //FIXME let log to other files.
        //TODO logging configuration.
        //TODO let log to several outputs.
        //TODO let enable/disable logging globally
        //TODO let enable/disable logging per module

        /**
         * Write a formatted logging information.
         *
         * Params:
         *   F                =  the message type or format type
         *   file_            =  the caller's file
         *   line_            =  the caller's line
         *   funcName_        =  the caller's function name
         *   prettyFuncName_  =  the caller's function type, name and parameters
         *   moduleName_      =  the caller's module name
         *   Args             =  the types for the optional arguments
         *   fmt              =  the message or its format
         *   args             =  the optional message arguments
         */
        void ln(F,
                string file=__FILE__,
                size_t line=__LINE__,
                string funcName=__FUNCTION__,
                string prettyFuncName=__PRETTY_FUNCTION__,
                string moduleName=__MODULE__,
                Args...)(lazy F fmt, lazy Args args) const
        if (isSomeString!(typeof(fmt)))
        {
            ln!(F, file, line, funcName, prettyFuncName, moduleName, Args)
               (true, fmt, args);
        }

        /**
         * Write a formatted logging information.
         *
         * If the condition is not met the formatting and logging are disabled.
         *
         * Params:
         *   F                =  the format type
         *   file_            =  the caller's file
         *   line_            =  the caller's line
         *   funcName_        =  the caller's function name
         *   prettyFuncName_  =  the caller's function type, name and parameters
         *   moduleName_      =  the caller's module name
         *   Args             =  the types for the optional arguments
         *   fmt              =  the message or its format
         *   args             =  the optional message arguments
         */
        void ln(F,
                string file=__FILE__,
                size_t line=__LINE__,
                string funcName=__FUNCTION__,
                string prettyFuncName=__PRETTY_FUNCTION__,
                string moduleName=__MODULE__,
                Args...)(lazy bool condition, lazy F fmt, lazy Args args)
        const
        if (isSomeString!(typeof(fmt)))
        {
            if (currentLevel >= minLevel && condition)
            {
                doLog(srcinfo(file, line, funcName, prettyFuncName, moduleName),
                      fmt, args);
            }
        }

        /**
         * Write unconditionally a formatted logging information to the backend.
         *
         * Params:
         *   F                =  the format type.
         *   Args             =  the types for the optional arguments
         *   src              =  the source file, line, function informations.
         *   fmt              =  the message or its format
         *   args             =  the optional message arguments
         */
        void doLog(F, Args...)(SrcInfo src, lazy F fmt, lazy Args args) const
        if (isSomeString!(typeof(fmt)))
        {
            stderr.write(src.shortDescription);
            static if (args.length == 0)
                stderr.writeln(fmt);
            else
                stderr.writefln(fmt, args);
        }

        /**
         * Format a logging information if `currentLevel >= minLevel` .
         * The logging prefix is excluded.
         *
         * Params:
         *   F                =  the format type
         *   Args             =  the types for the optional arguments
         *   fmt              =  the message or its format
         *   args             =  the optional message arguments
         */
        string s(F, Args...)(lazy F fmt, lazy Args args) const
        if (isSomeString!(typeof(fmt)))
        {
            if (currentLevel >= minLevel)
            {
                string ret;

                static if (args.length == 0)
                    ret = fmt;
                else
                    ret = format(fmt, args);

                return ret;
            }

            return "";
        }

        /**
         * Format a logging information if `currentLevel >= minLevel` .
         * The logging prefix is included.
         *
         * Params:
         *   F                =  the format type
         *   file_            =  the caller's file
         *   line_            =  the caller's line
         *   funcName_        =  the caller's function name
         *   prettyFuncName_  =  the caller's function type, name and parameters
         *   moduleName_      =  the caller's module name
         *   Args             =  the types for the optional arguments
         *   fmt              =  the message or its format
         *   args             =  the optional message arguments
         */
        string ps(F,
                  string file=__FILE__,
                  size_t line=__LINE__,
                  string funcName=__FUNCTION__,
                  string prettyFuncName=__PRETTY_FUNCTION__,
                  string moduleName=__MODULE__,
                  Args...)(lazy F fmt, lazy Args args) const
        if (isSomeString!(typeof(fmt)))
        {
            if (currentLevel >= minLevel)
            {
                auto src = srcinfo(file, line, funcName, prettyFuncName,
                                   moduleName);
                return s(src.shortDescription ~ fmt, args);

            }

            return "";
        }

    private:
        @disable this();

        Lvl _minLevel;
        Lvl* _pCurrentLevel;
}


/// Create a logger.
LoggerT!Lvl logger(Lvl)(ref Lvl level, Lvl minLvl)
{
    return LoggerT!Lvl(level, minLvl);
}

/// Create an uninitialized logger.
LoggerT!Lvl uninitializedLogger(Lvl)()
{
    return LoggerT!Lvl(Lvl.init);
}

/// The application specific logger type.
alias Logger = LoggerT!VbLevel;


package Logger _lgwrn = uninitializedLogger!VbLevel();
package Logger _lginf = uninitializedLogger!VbLevel();
package Logger _lgmor = uninitializedLogger!VbLevel();
package Logger _lgdbg = uninitializedLogger!VbLevel();

static this()
{
    _lgwrn = logger(verbose, VbLevel.Warn);
    _lginf = logger(verbose, VbLevel.Info);
    _lgmor = logger(verbose, VbLevel.More);
    _lgdbg = logger(verbose, VbLevel.Dbug);
}

/// Retrieve the warning logger.
@property Logger lgwrn() { return _lgwrn; }

/// Retrieve the information logger.
@property Logger lginf() { return _lginf; }

/// Retrieve the details logger.
@property Logger lgmor() { return _lgmor; }

/// Retrieve the debug logger.
@property Logger lgdbg() { return _lgdbg; }


unittest
{
    import std.conv : to;
    import std.traits : EnumMembers;
    import dutil : scopeVal;

    string here(string file = __FILE__,
                size_t ln = __LINE__,
                string fun = __FUNCTION__)
    {
        return "@" ~ file ~ "(" ~ to!string(ln) ~ "): " ~ fun ~ " ";
    }

    lgwrn.ln("lgwrn.ln");
    lgwrn.ln("lgwrn.ln %%d => %d", 1);

    assert(lgwrn.s("lgwrn.s") == "lgwrn.s");
    assert(lgwrn.s("lgwrn.s %%d => %d", 1) == "lgwrn.s %d => 1");

    assert(lgwrn.ps("lgwrn.ps") == here ~ "lgwrn.ps");
    assert(lgwrn.ps("lgwrn.ps %%d => %d", 1) == here ~ "lgwrn.ps %d => 1");

    assert([
        VbLevel.None,
        VbLevel.Warn,
        VbLevel.Info,
        VbLevel.More,
        VbLevel.Dbug
           ] == [EnumMembers!VbLevel],
           "EnumMembers!VbLevel = " ~ to!string([EnumMembers!VbLevel]));

    {
        auto vnon = scopeVal(verbose, VbLevel.None);
        assert(lgwrn.s("lgwrn.s %%d => %d", 1) == "");
        assert(lginf.s("lginf.s %%d => %d", 1) == "");
        assert(lgmor.s("lgmor.s %%d => %d", 1) == "");
        assert(lgdbg.s("lgdbg.s %%d => %d", 1) == "");
    }

    {
        auto vwarn = scopeVal(verbose, VbLevel.Warn);
        assert(lgwrn.s("lgwrn.s %%d => %d", 1) == "lgwrn.s %d => 1");
        assert(lginf.s("lginf.s %%d => %d", 1) == "");
        assert(lgmor.s("lgmor.s %%d => %d", 1) == "");
        assert(lgdbg.s("lgdbg.s %%d => %d", 1) == "");
    }

    {
        auto vinf = scopeVal(verbose, VbLevel.Info);
        assert(lgwrn.s("lgwrn.s %%d => %d", 1) == "lgwrn.s %d => 1");
        assert(lginf.s("lginf.s %%d => %d", 1) == "lginf.s %d => 1");
        assert(lgmor.s("lgmor.s %%d => %d", 1) == "");
        assert(lgdbg.s("lgdbg.s %%d => %d", 1) == "");
    }

    {
        auto vmor = scopeVal(verbose, VbLevel.More);
        assert(lgwrn.s("lgwrn.s %%d => %d", 1) == "lgwrn.s %d => 1");
        assert(lginf.s("lginf.s %%d => %d", 1) == "lginf.s %d => 1");
        assert(lgmor.s("lgmor.s %%d => %d", 1) == "lgmor.s %d => 1");
        assert(lgdbg.s("lgdbg.s %%d => %d", 1) == "");
    }

    {
        auto vdbg = scopeVal(verbose, VbLevel.Dbug);
        assert(lgwrn.s("lgwrn.s %%d => %d", 1) == "lgwrn.s %d => 1");
        assert(lginf.s("lginf.s %%d => %d", 1) == "lginf.s %d => 1");
        assert(lgmor.s("lgmor.s %%d => %d", 1) == "lgmor.s %d => 1");
        assert(lgdbg.s("lgdbg.s %%d => %d", 1) == "lgdbg.s %d => 1");
    }

}


