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
import std.array : array, join;
import std.conv : text;
import std.file : getSize;
import std.format : format;
import std.getopt : Option;
import std.range.primitives : isOutputRange;
import std.stdio : stderr;
import std.traits : isInstanceOf;


public import constvals : VbLevel;
import dutil: named;
import ui : tracef;


/**
 * Get the --key-file and --keyfile-size arguments for cryptsetup.
 *
 * Params:
 *     password_file = the path to a file containing the password.
 *
 * Returns: a string array with `--key-file` and `--keyfile-size` options
 *          for `cryptsetup luksOpen`.
 */
string[] luks_keyfile_args(const string password_file)
{
    if (password_file is null || password_file.length == 0)
        return [];

    auto pass_size = getSize(password_file);

    const string pass_name = password_file;
    auto pass_args = [ "--key-file",     pass_name,
                       "--keyfile-size", text(pass_size) ];

    return pass_args;
}


private immutable static VbLevel dflt_verbose = VbLevel.Warn;

/// Tell what is done.
VbLevel verbose = dflt_verbose;

static this()
{
    version(unittest)
    verbose = VbLevel.Info;
}

/**
 * verboseHandler handles `--quiet` and `--verbose` options.
 * Params:
 *     option =    an option without argument: one of
 *                 `-q`, `--quiet`, `-v`, `--verbose`.
 */
void verboseHandler(string option)
{
    switch (option)
    {
      case "quiet|q": verbose = VbLevel.None; break;
      case "verbose|v": verbose += 1; break;
      default :
        stderr.writeln("Unknown verbosity level ", option);
        break;
    }
}

/// help for quiet option
auto quiet_help = "Be quiet : disable verbosity.";

private immutable static string verbose_fmt =
    "Print what is done. This can be used several times. Default: %s.";

/// help for verbose option
auto verbose_help = format!verbose_fmt(dflt_verbose);


/// Disable the execution of the generated command.
bool fake = false;

/// Help for the fake|F option.
immutable static string fake_help = "Disable any modification command.";


/**
 * Print the parsed options and arguments.
 * Params:
 *     Opts    = The types of the program-specific options.
 *     prog    = The program name.
 *     args    = The remaining positional arguments.
 *     customOptions = The program-specific options.
 */
void print_args(Opts...)(string prog, string[] args, Opts customOptions)
{
    import std.stdio : stderr;
    output_args!(tracef, stderr, Opts)(prog, args, customOptions);
}


private immutable static auto _usual_exec_dirs = [
        "/usr/local/sbin",
        "/usr/local/bin",
        "/usr/sbin",
        "/usr/bin",
        "/sbin",
        "/bin",
        ];

/// The `--exec-dir` description.
auto exec_dir_help = join([
    "Use the specified execution directory. The option must be used for each",
    "directory to be used. The default execution directories are:\n",
    format!"               %s."(join(_usual_exec_dirs, "\n                ")),
    ], " ");

/**
 * The usual execution directories which may be overriden before parsing
 * program options.
 */
auto dflt_exec_dirs = _usual_exec_dirs;

/// The execution directories.
string[] exec_dirs = [];

/**
 * execDirHandler handles the `-D` / `--exec-dir` option.
 *
 * The `exec_dirs` public value is updated.
 *
 * Params:
 *     option =    the option short or long name: one of
 *                 `-D`, `--exec-dir`.
 *     value  =    the option value.
 */
void execDirHandler(string option, string value)
{
    exec_dirs ~= [ value ];
}

/**
 * Ensure that execution directories are set.
 */
void check_exec_dirs() {
    if (exec_dirs.length != 0)
        return;

    // A manual copy is needed because of the type difference.
    exec_dirs = new string[ dflt_exec_dirs.length ];
    for (auto i = 0; i < dflt_exec_dirs.length; i++) {
        exec_dirs[i] = dflt_exec_dirs[i];
    }
}


/// The mount options.
string[] options = [];

/// The option help message.
immutable static string option_help = "Enable an option";

/**
 * optionHandler handles the `-o` / `--option` option.
 *
 * The `options` public value is updated.
 *
 * Params:
 *     program_option =    the option short or long name: one of
 *                 `-o`, `--option`.
 *     value  =    the option value.
 */
void optionHandler(string program_option, string value)
{
    options ~= [ value ];
}


/**
 * Print the parsed options and arguments to the specified output range.
 *
 * Each `Opt` type is expected to be a `named` template instance.
 * Params:
 *     Opts   = The types of the program-specific options.
 *     uifun  = One of the ui `infof`, `tracef`, ... functions.
 *     output = An output range used to write the options and arguments.
 *     prog   = The program name.
 *     args   = The positional arguments.
 *     customOptions = The program-specific options.
 */
void output_args(alias uifun, alias output, Opts...)(string prog, string[] args,
                          Opts customOptions)
if (is(typeof(output) == typeof(stderr)))
in
{
    static foreach(customOpt; customOptions)
    {
        static assert(__traits(compiles, customOpt.name));
        static assert(__traits(compiles, customOpt.value));
    }
}
do
{
    enum fmt = "  %s is '%s'.";

    uifun("%s Options:", output, prog);

    foreach(customOpt; customOptions)
        uifun(fmt, output, customOpt.name, customOpt.value);

    uifun(fmt, output, "verbose", verbose);
    uifun(fmt, output, "fake", fake);

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
