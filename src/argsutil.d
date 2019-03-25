// Written in the D programming language.

/**
Definition of usual command line options.

The module argsutil defines functions and variables commonly used when parsing
a command line.

Currently this module relies on std.getopt module.

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
module argsutil;

import std.algorithm.iteration : filter;
import std.array : array;
import std.format : format;
import std.getopt : Option;
import std.range.primitives : isOutputRange;
import std.stdio : stderr;
import std.traits : isInstanceOf;


public import constvals : VbLevel;
import dutil: named;
import ui : tracef;


/**
 * Print the parsed options and arguments.
 * Params:
 *     Opts    = The types of the program options.
 *     prog    = The program name.
 *     args    = The remaining positional arguments.
 *     options = The program options.
 */
void print_args(Opts...)(string prog, string[] args, Opts options)
{
    import std.stdio : stderr;
    output_args!(tracef, stderr, Opts)(prog, args, options);
}


/**
 * Print the parsed options and arguments to the specified output range.
 *
 * Each `Opt` type is expected to be a `named` template instance.
 * Params:
 *     Opts   = The types of the program options.
 *     uifun  = One of the ui `infof`, `tracef`, ... functions.
 *     output = An output range used to write the options and arguments.
 *     prog   = The program name.
 *     args   = The positional arguments.
 *     options = The program options.
 */
void output_args(alias uifun, alias output, Opts...)(string prog, string[] args,
                          Opts options)
if (is(typeof(output) == typeof(stderr)))
in
{
    static foreach(option; options)
    {
        static assert(__traits(compiles, option.name));
        static assert(__traits(compiles, option.value));
    }
}
do
{
    enum fmt = "  %s is '%s'.";

    uifun("%s Options:", output, prog);

    foreach(option; options)
        uifun(fmt, output, option.name, option.value);

    auto positionalArgs = args
        .filter!(a => a.length == 0 || a[0] != '-')()
        .array;
    if (positionalArgs.length)
        uifun("Positional arguments:\n    %(%s\n    %)",
              output, positionalArgs);
}



/// The exception raised when an error is found in program arguments.
class ArgumentException : Exception
{

    /// Create an ArgumentException related to a bad number of arguments.
    static ArgumentException badNb(size_t min, size_t max, size_t actual)
    {
        string fmt;
        string msg;

        if (max > min)
        {
            fmt = "%d arguments, but between %d and %d are expected";
            msg = fmt.format(actual, min, max);
        }
        else
        {
            fmt = "%d arguments instead of %d.";
            msg = fmt.format(actual, min);
        }

        assert(msg !is null);
        assert(msg.length > 0);

        return new ArgumentException(msg);
    }

    /// Create an ArgumentException related to an unexpected argument.
    static ArgumentException unexpected(string expectedName, string actual)
    {
        string fmt = "Unexpected argument '%s' instead of a(n) '%s'.";
        string msg = fmt.format(actual, expectedName);

        return new ArgumentException(msg);
    }

    /// Create an ArgumentException related to an unexpected argument.
    static ArgumentException illegal(string argument, string reason="")
    {
        string msg;

        if (reason !is null && reason.length > 0)
            msg = format!"Illegal argument '%s' : %s."(argument, reason);
        else
            msg = format!"Illegal argument '%s'."(argument);

        return new ArgumentException(msg);
    }

    /// Constructor with the error message.
    this(string message)
    {
        super(message);
    }

}
