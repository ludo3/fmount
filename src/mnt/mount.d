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

import argsutil : exec_dirs, verbose;
import constvals : VbLevel;
import dev : dev_descr, dev_display, dev_path;
import mnt.common : check_user, find_mountpoint;
import osutil : get_exec_path;


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

    check_user(device_path, "fmount");

    immutable mount_prog = get_exec_path("mount", exec_dirs);

    auto current_mountpoint = find_mountpoint(device_path);
    auto descr = dev_descr(device_path, dev_display(device_path));

    if (current_mountpoint !is null && current_mountpoint.length > 0)
    {
        if (verbose >= VbLevel.Info)
        {
            immutable fmt = "Note : %s is already mounted at %s .";
            writeln(format!fmt(descr, current_mountpoint));
        }
        return;
    }

    if (verbose >= VbLevel.Info)
        writeln("Mounting ", descr);

    if (mountpoint is null || mountpoint.length == 0)
        mountpoint = dev_display(device_path);

    /*
    // request a password if needed,
    // put it password into a temporary file,
    // and tell to 'fmount' to use that password file.
    try:
        with read_password(device_path,
                           pass_file=kw.get('passphrase'),
                           strict=True,
                           verbose=verbose,
                           test=test,
                           delete=False) as pwf:
            do_mount(mount_prog,
                     device_path,
                     password_file=pwf,
                     mountpoint=mountpoint,
                     verbose=verbose,
                     test=test,
                     **kw)
    except UserWarning as uw:
        if verbose >= vbmore:
            print_exc()
        elif verbose >= vbwarn:
            print(uw)
    */
}


