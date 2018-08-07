// Written in the D programming language.

/**
Definition of project-specific command line options.

The module args defines command line parsing functions and variables which are
specific to this project.

Currently this module relies on std.getopt module.

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
module mnt.mount;

import std.stdio : writeln;
import std.string : format;

import argsutil : verbose;
import constvals : VbLevel;
import dev : dev_descr, dev_display, dev_path;
import mnt.common : check_user;


/**
 * Main fmount function.
 * Params:
 *     args = The positional arguments.
 */
void fmount(string[] args) {
    immutable string device_path = dev_path(args[0]);
    string mountpoint;

    if (args.length > 1)
        mountpoint = args[1];
    else
        mountpoint = "";

    if (verbose >= VbLevel.Dbug)
    {
        immutable string fmt = q"TXT
fmount(device_path=%s,
       mountpoint=%s);
TXT";
        writeln(format!fmt(device_path, mountpoint));
    }

    if (args.length > 1)
        mountpoint = args[1];
    else
    {
        // TODO retrieve from disk label
    }

    writeln("running fmount");
    check_user(device_path, "fmount");
}


