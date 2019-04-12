// Written in the D programming language.

/**
main application runner.

This module contains code common to all modules with a `main` function.

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
module dutil.run;

import std.getopt : GetOptException, GetoptResult, getopt;
import std.stdio : writeln;

import dutil.appargs : check_exec_dirs, verbose;
import dutil.constvals : VbLevel;
import dutil.exceptions : printThChain;
import dutil.ui : info_, error, print_args;

//TODO replace std.getopt with argsd library
/**
 * Call `std.getopt.getopt(args, ...)` and print any option-related exception.
 */
GetoptResult check_opts(T...)(ref string[] args, T opts)
{
    try
    {
        return getopt(args, opts);
    }
    catch(GetOptException goe)
    {
        error(goe.msg);
        throw goe;
    }
}


alias main_fun = void delegate(string[]);

/**
 * Run a program entry point after the options parsing, and handle any thrown
 * exceptions.
 *
 * Params:
 *     Opts    = The types of the program-specific options.
 *     main    = The entry point to be run.
 *     prog    = The program path.
 *     args    = The program arguments.
 *     customOptions = The program-specific options.
 */
void run_parsed(Opts...)(void function(string, string[]) main,
                         string prog, string[] args,
                         Opts customOptions)
{
        check_exec_dirs();

        if (verbose >= VbLevel.More)
            print_args(prog, args, customOptions);

        try
        {
            main(prog, args);
        }
        catch(Exception ex)
        {
            if (verbose >= VbLevel.Dbug)
                printThChain(ex);
            info_(ex.msg);
        }
}

