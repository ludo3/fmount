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

import devices.devargs : passphrase_file, passphrase_help;
import dutil.appargs :
    exec_dir_help, exec_dirs,
    execDirHandler,
    fake, fake_help,
    quiet_help,
    verbose, verbose_help, verboseHandler,
    version_help, version_requested, versionHandler;
import dutil.os : program_name;
import dutil.run : run_parsed;
import dutil.typecons : named;
import fmount.appver : ver;
import fmount.argsutil : ArgumentException;
import fmount.mnt.mount : fmount;
import fmount.mnt.mountargs :
    atime_help, atimeHandler,
    exec_help, execHandler, noexec_help,
    option_help, options, optionHandler,
    read_only_help, read_write_help, readWriteHandler,
    sync_help, async_help, syncHandler,
    type_help, typeHandler,
    umask_help, umaskHandler;
import dutil.ui : error, traceStack;


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

void doMain(string[] args)
{
    try
    {
        auto parsed_args = getopt(
            args,
            std.getopt.config.bundling,

            "passphrase|p",   passphrase_help, &passphrase_file,

            //"use-norandom", norandom_help, &randfileHandler,
            //"use-random",   random_help,   &randfileHandler,
            //"use-urandom",  urandom_help,  &randfileHandler,

            "exec-dir|D",  exec_dir_help,  &execDirHandler,
            "read-only|r", read_only_help, &readWriteHandler,
            "read-write|w", read_write_help, &readWriteHandler,
            "atime|A", atime_help, &atimeHandler,
            "exec|e", exec_help, &execHandler,
            "noexec|E", noexec_help, &execHandler,
            "type|t", type_help, &typeHandler,
            "charset|c", type_help, &typeHandler,
            "umask|u", umask_help, &umaskHandler,
            "sync|s", sync_help, &syncHandler,
            "async|S", async_help, &syncHandler,
            "option|o",  option_help,  &optionHandler,

            "quiet|q",   quiet_help, &verboseHandler,
            "verbose|v", verbose_help, &verboseHandler,
            "fake|F",    fake_help, &fake,
            "version|V", version_help, &versionHandler);

        if (parsed_args.helpWanted)
        {
            // FIXME improve getopt formatting.
            defaultGetoptPrinter("Mount a removable device, or any device if "
                                   ~"authorized by the system administrator.",
                                   parsed_args.options);
        }
        else
        {
            args = args[1..$];

            if (!version_requested &&(args.length < 1 || args.length > 2))
                throw ArgumentException.badNb(1, 2, args.length);

            run_parsed(ver, &fmount, program_name, args,
                       named("passphrase", passphrase_file),
                       named("exec_dirs", exec_dirs),
                       named("options", options),
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


