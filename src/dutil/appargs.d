// Written in the D programming language.

/**
`mount`, `umount` and `mkfs` options.

This module gathers common options.

Copyright: Copyright Ludovic Dordet 2019.
License:   $(HTTP www.gnu.org/licenses/gpl-3.0.md,
             GNU GENERAL PUBLIC LICENSE 3.0).
Authors:   Ludovic Dordet
*/
/*
         Copyright Ludovic Dordet 2019.
Distributed under the GNU GENERAL PUBLIC LICENSE, Version 3.0.
   (See accompanying file LICENSE.md or copy at
         http://www.gnu.org/licenses/gpl-3.0.md)
*/
module dutil.appargs;

import std.array : join;
import std.format : format;
import std.stdio : stderr;

import dutil.constvals : VbLevel;
import dutil.src : unused;


private enum VbLevel dflt_verbose = VbLevel.Warn;

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
auto dflt_exec_dirs = _usual_exec_dirs.dup;

/// The execution directories.
string[] exec_dirs = [];

/**
 * execDirHandler handles the `-D` / `--exec-dir` option.
 *
 * The `exec_dirs` public value is updated.
 *
 * Params:
 *     option =    the option short or long name: one of `-D`, `--exec-dir`.
 *     value  =    the option value.
 */
void execDirHandler(string option, string value)
{
    unused(option);
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


/// Tells when the program version is requested.
bool version_requested;

/// Help for rhe version|V option.
string version_help = "Print the current version number.";

// TODO version number (major, minor, revision, preversion) and string.


