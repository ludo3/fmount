// Written in the D programming language.

/**
`mnt.mount` options.

This module gathers options used mainly when mounting a file system.

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
module fmount.mnt.mountargs;

import std.stdio : stderr;


/**
 * Mount the filesystem for reading only (`--read-only`) or for writing
 * (`--read-write`) as well. By default the `mount` program will choose the best
 * value.
 */
string force_readonly_or_readwrite;

/// Help for the read-only|r option.
immutable static string read_only_help = "Mount the filesystem readonly.";

/// Help for the read-write|w option.
immutable static string read_write_help =
    "Mount the filesystem read/write (the default).";

/// Tell whether read-only or read-write access is explicitly requested.
enum ForceReadWrite : string
{
    /// Neither read-only nor read-write access is explicitly requested.
    None = "",

    /// Read-only access is explicitly requested.
    RO = "--read-only",

    /// Read-write access is explicitly requested.
    RW = "--read-write",
}

/**
 * readWriteHandler handles `--read-only` and `--read-write` options.
 * Params:
 *     option =    an option without argument: one of
 *                 `-r`, `--read-only`, `-w`, `--read-write`.
 */
void readWriteHandler(string option)
{
    switch (option)
    {
      case "read-only|r":
        force_readonly_or_readwrite = ForceReadWrite.RO;
        break;

      case "read-write|w":
        force_readonly_or_readwrite = ForceReadWrite.RW;
        break;

      default :
        stderr.writeln("Unknown read/write ", option);
        break;
    }
}


/// Help for the atime|A option.
immutable static string atime_help =
    "Enable access time updates. The default is atime=no";

/// The default mount atime options.
immutable string[] dflt_atimes = [ "noatime" ];

/// The mount atime options.
string[] atimes = dflt_atimes.dup;

/**
 * atimeHandler handles the `-A` / `--atime` option.
 *
 * The `atimes` public value is updated.
 *
 * Params:
 *     program_option =    the option short or long name: one of
 *                 `-A`, `--atime`.
 *     value  =    the option value.
 */
void atimeHandler(string program_option, string value)
{
    import std.algorithm.searching : startsWith;
    string parsed_value;
    if (value.startsWith("no"))
        parsed_value = "no";

    switch(value)
    {
        case "rel":
        case "relatime":
            parsed_value ~= "relatime";
            break;

        case "dir":
        case "diratime":
            parsed_value ~= "diratime";
            break;

        case "":
        case "atime":
            parsed_value ~= "atime";
            break;

        default:
            stderr.writefln!"Unknown atime value '%s'."(value);
            return;
    }

    atimes ~= [ parsed_value ];
}


/// Help for the noexec|E option.
immutable static string noexec_help =
    "Disable program and script executions. This is the default.";

/// Help for the exec|e option.
immutable static string exec_help =
    "Enable program and script executions. The default is noexec.";

/// The exec / noexec option.
bool exec;

/**
 * execHandler handles the `-e` / `--exec` option.
 *
 * The `exec` public value is updated.
 *
 * Params:
 *     option =    an option without argument: one of
 *                 `-E`, `--noexec` (the default), `-e`, `--exec`.
 */
void execHandler(string option)
{
    switch (option)
    {
      case "noexec|E": exec = false; break;
      case "exec|e": exec = true; break;
      default :
        stderr.writeln("Unknown exec option ", option);
        break;
    }
}


/// The filesystem type help message.
immutable static string type_help = "The filesystem type.";

/// The filesystem type.
string type;

/**
 * typeHandler handles the `-t` / `--type` option.
 *
 * The `type` public value is updated.
 *
 * Params:
 *     option =    the option short or long name: one of
 *                 `-t`, `--type`.
 *     value  =    the option value.
 */
void typeHandler(string option, string value)
{
    type = value;
}


/// The charset help message.
immutable static string charset_help =
    "Character  set  to use for converting between 8 bit characters" ~
    " and 16 bit Unicode characters. Same as 'iocharset' mount option.";

/// The conversion character set.
string charset;

/**
 * charsetHandler handles the `-c` / `--charset` option.
 *
 * The `charset` public value is set or updated.
 *
 * Params:
 *     option =    the option short or long name: one of
 *                 `-c`, `--charset`.
 *     value  =    the (io)charset value.
 */
void charsetHandler(string option, string value)
{
    charset = value;
}


/// The umask help message.
immutable static string umask_help =
    "Use  specified  umask  instead of the default one.";

/// The conversion character set.
string umask;

/**
 * umaskHandler handles the `-u` / `--umask` option.
 *
 * The `umask` public value is set or updated.
 *
 * Params:
 *     option =    the option short or long name: one of
 *                 `-u`, `--umask`.
 *     value  =    the umask value.
 */
void umaskHandler(string option, string value)
{
    umask = value;
}


/// Help for the async|S option.
immutable static string async_help =
    "Write without caching (should rarely be needed, if ever).";

/// Help for the sync|s option.
immutable static string sync_help =
    "Cache data before writing the cache content. This is the default.";

/// The sync option.
bool sync;

/**
 * syncHandler handles the `-s` / `--sync` and `-S` / `--async` options.
 *
 * The `sync` public value is updated.
 *
 * Params:
 *     option =    an option without argument: one of
 *                 `-s`, `--sync`, `-S` or `--async`.
 */
void syncHandler(string option)
{
    switch (option)
    {
      case "async|S": sync = false; break;
      case "sync|s": sync = true; break;
      default :
        stderr.writeln("Unknown sync option ", option);
        break;
    }
}


/// The mount options.
string[] options = [];

/// The option help message.
immutable static string option_help =
    "Select a mount option or a comma-separated list of options." ~
    " Can be used several times.";

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


