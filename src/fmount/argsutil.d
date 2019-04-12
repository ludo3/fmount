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
module fmount.argsutil;

import std.format : format;

import dutil.ui : tracef;


/// The exception raised when an error is found in program arguments.
class ArgumentException : Exception
{

    /// Create an ArgumentException related to a bad number of arguments.
    static ArgumentException badNb(size_t min, size_t max, size_t actual)
    {
        string msg;

        if (max > min)
        {
            enum fmt = "%d arguments, but between %d and %d are expected";
            msg = format!fmt(actual, min, max);
        }
        else
        {
            enum fmt = "%d arguments instead of %d.";
            msg = format!fmt(actual, min);
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

