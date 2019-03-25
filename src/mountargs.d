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
module mountargs;

import std.array : join;
import std.conv : text;
import std.file : getSize;
import std.format : format;
import std.string : outdent;
import std.stdio : stderr;


/// help for the passphrase option
auto passphrase_help = outdent(join([
    "If the device is encrypted (dm-crypt with LUKS metadata),",
    " read the password from the 'passphrase' file instead of prompting",
    " at the terminal.",
    ], " "));

// FIXME add a handler which checks existing readable file names.
/// The full `passphrase_file` content is a password.
string passphrase_file;


private immutable static string dev = "/dev/";

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
      default :
        stderr.writeln("Unknown random source ", option);
        break;
    }
}

immutable static string random_fmt = "Use %s as entropy source.";

/// help for use-random option
auto random_help = format!random_fmt(RandFile.Random);

/// help for use-urandom option
auto urandom_help = format!random_fmt(RandFile.Urandom);

/// help for use-norandom option
auto norandom_help = "Do not use any entropy source (use with care).";


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


