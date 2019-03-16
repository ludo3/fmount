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
module mnt.umount;

import std.path : baseName;

import argsutil : exec_dirs;
import constvals : VbLevel;
import dev : dev_descr, dev_display, dev_path, get_dm_and_raw_dev, is_encrypted;
import luks : luksClose;
import mnt.common : check_user, find_mountpoint, is_in_fstab,
                    remove_automatically_created_dir;
import osutil : get_exec_path, runCommand;
import ui : dbugf, info_, infof, show_warnings, traceStack;

private alias bn = baseName;

/**
 * Main fumount function.
 * Params:
 *     prog = The fumount program path.
 *     args = The positional arguments.
 */
void fumount(string prog, string[] args) {
    info_("running fumount");

    immutable string device_path = dev_path(args[0]);

    enum fumountArgsFmt = `
  %s(device_path=%s);
    `;

    dbugf(fumountArgsFmt, prog, device_path);

    check_user(device_path, "fumount");

    immutable unmount_prog = get_exec_path("umount", exec_dirs);

    auto current_mountpoint = find_mountpoint(device_path);
    auto descr = dev_descr(device_path, dev_display(device_path));

    if (current_mountpoint is null || current_mountpoint.length == 0)
    {
        // cleanup the directory if needed
        remove_automatically_created_dir(current_mountpoint);
        infof("Note: %s is already unmounted.", descr);
        return;
    }

    infof("Unmounting %s from %s", descr, current_mountpoint);

    do_unmount(unmount_prog, device_path, current_mountpoint);
}


private void do_unmount(string exec_prog,
                        string disk,
                        string mountpoint)
{
    string mountname = dev_display(disk);
    string descr = dev_descr(disk, mountname);

    try
    {
        // The next code needs root privileges.
        if (is_encrypted(disk))
        {
            auto dm_and_raw = get_dm_and_raw_dev(disk);

            string dm = dm_and_raw[0];
            disk = dm_and_raw[1];

            _do_unmount_nocrypt(exec_prog, dm, mountpoint);

            luksClose(bn(dm));
        }
        else
        {
            _do_unmount_nocrypt(exec_prog, disk, mountpoint);
        }
    }
    catch(Exception ex)
    {
        traceStack(ex);
        show_warnings!(VbLevel.None)(descr ~ ": " ~ ex.toString());
    }
}


/**
 * Unmount one single unencrypted disk. No 'already unmounted' check is done.
 */
private void _do_unmount_nocrypt(string exec_prog,
                                 string disk,
                                 string mountpoint)
{
    if (is_in_fstab(disk))
    {
        // TODO if custom arguments are ever defined, disable them.
    }

    auto args = [exec_prog, dev_path(disk)];
    runCommand(args);
    remove_automatically_created_dir(mountpoint);
}


