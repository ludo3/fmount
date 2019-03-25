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

import appargs :
    exec_dir_help, exec_dirs,
    execDirHandler,
    fake, fake_help,
    quiet_help,
    verbose, verbose_help, verboseHandler;
import argsutil : ArgumentException;
import dutil : named;
import mnt.umount : fumount;
import run;
import ui : error, traceStack;

/**
 * The `fmount` program entry point.
 * Params:
 *     args    = The program arguments.
 */
void main(string[] args)
{
    version(unittest)
        stderr.writefln!"%s(%d) unittest : %s is disabled."
                        (__FILE__, __LINE__, __FUNCTION__);
    else
        doMain(args);
}

private void doMain(string[] args)
{
    try
    {
        auto parsed_args = getopt(
            args,
            std.getopt.config.bundling,

            "exec-dir|D",  exec_dir_help,  &execDirHandler,

            "quiet|q",   quiet_help, &verboseHandler,
            "verbose|v", verbose_help, &verboseHandler,
            "fake|F",    fake_help, &fake);

        if (parsed_args.helpWanted)
        {

            // FIXME improve getopt formatting.
            defaultGetoptPrinter("Unmount a removable device, or any device if "
                                ~"authorized by the system administrator.",
                                parsed_args.options);
        }
        else {
            string progName = args[0];
            args = args[1..$];

            if (args.length != 1)
                throw ArgumentException.badNb(1, 1, args.length);

            run_parsed(&fumount, progName, args,
                       named("exec_dirs", exec_dirs),
                       named("verbose", verbose),
                       named("fake", fake));
        }
    }
    catch(ArgumentException ae)
    {
        traceStack(ae);
        error(ae.msg);
    }
    catch(GetOptException goe)
    {
        traceStack(goe);
        error(goe.msg);
    }
}
