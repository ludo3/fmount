// Written in the D programming language.

/**
Dlang related utilities.

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
module dutil;
import std.stdio : writeln;


/**
 * Print one throwable (exception, error).
 *
 * This function can be used with `Throwable.opApply`.
 *
 * Params:
 *     th = the throwable to be printed.
 */
int defaultPrintTh(Throwable th)
{
    writeln(th.toString());
    return 0;
}


/**
 * The delegate used by `printThChain`.
 */
int function(Throwable) print1Throwable = &defaultPrintTh;


/**
 * Print the throwable chain.
 * Params:
 *     th = the throwable to be printed, starting the throwable chain.
 */
void printThChain(Throwable th)
{
    // Note https://tour.dlang.org/tour/en/gems/opdispatch-opapply
    foreach(Throwable inChain; th)
        print1Throwable(inChain);
}



