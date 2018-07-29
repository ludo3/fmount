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
module run;
import argsutil : check_exec_dirs, print_args, VbLevel, verbose;

alias main_fun = void delegate(string[]);

/**
 * Run a program entry point after the options parsing, and handle any thrown
 * exceptions.
 *
 * Params:
 *     main    = The entry point to be run.
 *     args    = The program arguments.
 */
void run_parsed(void function(string[]) main, string[] args)
{
        check_exec_dirs();

        if (verbose >= VbLevel.More)
            print_args(args);

        main(args);
}

