// Written in the D programming language.

/**
`devices` options.

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
module devices.devargs;

import std.array : join;
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

private enum string random_fmt = "Use %s as entropy source.";

/// help for use-random option
auto random_help = format!random_fmt(RandFile.Random);

/// help for use-urandom option
auto urandom_help = format!random_fmt(RandFile.Urandom);

/// help for use-norandom option
auto norandom_help = "Do not use any entropy source (use with care).";


