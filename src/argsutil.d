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

import std.conv : text;
import std.file : getSize;
import std.getopt : Option;
import std.stdio;
import std.string;


/**
 * Get the --key-file and --keyfile-size arguments for cryptsetup.
 *
 * Params:
 *     password_file: the path to a file containing the password.
 *
 * Returns: a string array with `--key-file` and `--keyfile-size` options
 *          for `cryptsetup luksOpen`.
 */
string[] passphrase_to_luks_keyfile_args(const string password_file)
{
    auto pass_size = getSize(password_file);

    const string pass_name = password_file;
    auto pass_args = [ "--key-file",     pass_name,
                       "--keyfile-size", text(pass_size) ];

    return pass_args;
}


/// help for the passphrase option
auto passphrase_help = outdent(join([
    "If the device is encrypted (dm-crypt with LUKS metadata),",
    " read the password from the 'passphrase' file instead of prompting",
    " at the terminal.",
    ], " "));

// FIXME add a handler which checks existing readable file names.
/// The full `passphrase_file` content is a password.
string passphrase_file;


/// Private immutable value.
immutable static string dev = "/dev/";

/// The known random source files.
enum RandFile : string {
    /// Disabled random source
    None = "",

    /// Synchronous random source
    Random = dev ~ "random",

    /// Asynchronous random source
    Urandom = dev ~ "urandom"
}

/// The default random file is asynchronous : `RandFile.Urandom`.
immutable static RandFile default_random_file = RandFile.Urandom;

/**
 * Select the random source used to securize disk data.
 *
 * The possible random options are:
 * ---
 * --use-norandom
 * --use-random
 * --use-urandom
 * ---
 *
 * The default is `--use-urandom`; the first one should be used only when
 * the disk data have already been randomized by another process.
 */
RandFile random_file = default_random_file;

/**
 * randfileHandler handles `RandFile` options.
 * Params:
 *     option =    an option without argument: one of
 *                 `--use-random`, `--use-urandom`, `--use-norandom`.
 */
void randfileHandler(string option)
{
    switch (option)
    {
      case "use-norandom": random_file = RandFile.None; break;
      case "use-random": random_file = RandFile.Random; break;
      case "use-urandom": random_file = RandFile.Urandom; break;
      case "verbose|v": verbose += 1; break;
      default :
        stderr.writeln("Unknown random source ", option);
        break;
    }
}

/// Private immutable value.
immutable static string random_fmt = "Use %s as entropy source.";

/// help for use-random option
auto random_help = format!random_fmt(RandFile.Random);

/// help for use-urandom option
auto urandom_help = format!random_fmt(RandFile.Urandom);

/// help for use-norandom option
auto norandom_help = "Do not use any entropy source (use with care).";


/// verbose type
enum VbLevel
{
    /// Print errors.
    None,

    /// Print errors and warnings.
    Warn,

    /// Print errors, warnings and informations.
    Info,

    /// Print more informations in order to check small issues.
    More,

    /// Print as much informations as possible, for debugging purpose.
    Dbug
}

/// Private value.
immutable static VbLevel dflt_verbose = VbLevel.Warn;

/// Tell what is done.
VbLevel verbose = dflt_verbose;

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

/// private format
immutable static string verbose_fmt =
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
 *     opts    = The parsed optional arguments.
 *     args    = The remaining positional arguments.
 */
void print_args(string[] args)
{
    import std.stdio : stdout;
    output_args(stdout.lockingTextWriter(), args);
}


/// Private immutable value.
immutable static auto _usual_exec_dirs = [
        "/usr/local/sbin",
        "/usr/local/bin",
        "/usr/sbin",
        "/usr/bin",
        "/sbin",
        "/bin",
        ];

/// Private immutable value.
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
 * Params:
 *     Output = The output range used to write the options and arguments.
 *     args   = The positional arguments.
 */
void output_args(Output)(Output output, string[] args)
{
    import std.format : formattedWrite;
    string fmt = "%s is '%s'.\n";

    output.formattedWrite(format!"%s Options:\n"(args[0]));
    output.formattedWrite(format(fmt, "passphrase", passphrase_file));
    output.formattedWrite(format(fmt, "random_file", random_file));
    output.formattedWrite(format(fmt, "exec_dirs", exec_dirs));
    output.formattedWrite(format(fmt, "options", options));
    output.formattedWrite(format(fmt, "verbose", verbose));
    output.formattedWrite(format(fmt, "fake", fake));

    if (args.length >= 2)
    {
        output.formattedWrite("Positional arguments:\n    %s\n",
                              join(args[1..args.length], "\n    "));

    }
}


