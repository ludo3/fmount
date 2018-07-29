// Written in the D programming language.

/**
`fmount` main entry point.

The program enables mounting removable devices.

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
import std.getopt;
import std.stdio;

import argsutil;
import mnt.mount : fmount;
import run : run_parsed;

/**
 * The `fmount` program entry point.
 * Params:
 *     args    = The program arguments.
 */
void main(string[] args)
{
    try
    {
        auto parsed_args = getopt(
            args,
            std.getopt.config.bundling,

            "passfile|p",   passphrase_help, &passphrase_file,

            "use-norandom", norandom_help, &randfileHandler,
            "use-random",   random_help,   &randfileHandler,
            "use-urandom",  urandom_help,  &randfileHandler,

            "exec-dir|D",  exec_dir_help,  &execDirHandler,
            "option|o",  option_help,  &optionHandler,

            "quiet|q",   quiet_help, &verboseHandler,
            "verbose|v", verbose_help, &verboseHandler,
            "fake|F",    fake_help, &fake);

        if (parsed_args.helpWanted)
        {
            // FIXME improve getopt formatting.
            defaultGetoptPrinter("Mount a removable device, or any device if "
                                   ~"authorized by the system administrator.",
                                   parsed_args.options);
        }
        else {
            run_parsed(&fmount, args);
        }
    }
    catch(GetOptException goe)
    {
        writeln(goe.msg);
    }
}

