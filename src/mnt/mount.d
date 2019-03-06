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

import std.array : join;
import std.traits : hasMember;

import appconfig;
import argsutil : exec_dirs, verbose;
import constvals : VbLevel;
import dev : dev_descr, dev_display, dev_fs, dev_path, get_dm_name,
             is_encrypted;
import dutil : printThChain;
import luks : luksOpen, luksClose;
import mnt.common : check_user, ensure_mntdir_exists, find_mountpoint,
                    get_expected_mountpoint, remove_automatically_created_dir;
import osutil : get_exec_path, runCommand;
import ui : dbugf, info_, infof, read_password, show_warnings;


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

    enum fmountArgsFmt = `
  fmount(device_path=%s,
         mountpoint=%s);
    `;

    dbugf(fmountArgsFmt, device_path, mountpoint);

    if (args.length > 1)
        mountpoint = args[2];
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
        enum AlreadyMountedFmt = "Note : %s is already mounted at %s .";
        infof(AlreadyMountedFmt, descr, current_mountpoint);
        return;
    }

    info_("Mounting ", descr);

    if (mountpoint is null || mountpoint.length == 0)
        mountpoint = dev_display(device_path);

    // request a password if needed,
    // put it password into a temporary file,
    // and tell to 'cryptsetyp' to use that password file.
    auto pwf = read_password(device_path);

    do_mount(mount_prog,
             device_path,
             pwf,
             mountpoint);
}


/**
 * Mount one single disk if it is not mounted yet.
 */
private void do_mount(F)(string exec_prog,
                         string disk,
                         F password_file,
                         string mountpoint)
if (is(F == typeof(null)) || hasMember!(F, "name"))
{

    string mp = get_expected_mountpoint(disk, mountpoint);

    try
    {
        // The next code needs root privileges.
        if (is_encrypted(disk))
        {
            string dm_name = get_dm_name(disk);
            auto dmdev = luksOpen(disk,
                                  password_file,
                                  dm_name);
            scope(failure) luksClose(dm_name);

            _do_mount_nocrypt(exec_prog, dmdev, mp);
        }
        else
        {
            _do_mount_nocrypt(exec_prog, disk, mp);
        }
    }
    catch(Exception ex)
    {
        if (verbose >= VbLevel.More)
            printThChain(ex);
        string descr = dev_descr(disk, dev_display(disk));
        show_warnings!(VbLevel.None)(descr ~ ": " ~ ex.toString());
    }
}


/**
 * Parse the mount options and translate them for pmount or mount.
 */
private immutable(string[]) _get_mount_opts(string dev_file_system)
{
    string[] mount_opts = [];
    string[] comma_sep_opts = [];

    // TODO get configuration and get mount options from configuration.
    /++
    if kw.get('read_only'):
        mount_opts.append('--read-only')

    if kw.get('read_write'):
        mount_opts.append('--read-write')

    if kw.get('noatime'):
        comma_sep_opts.append('noatime')

    if kw.get('exec'):
        comma_sep_opts.append('exec')
    else:
        comma_sep_opts.append('noexec')

    type_ = kw.get('type')
    if type_:
        mount_opts.extend([ '-t', type_ ])

    charset = kw.get('charset')
    if charset:
        if type_ == 'ntfs' or dev_file_system == 'ntfs':
            optname = 'nls'
        else:
            optname = 'iocharset'
        comma_sep_opts.append(optname + '=' + charset)

    umask = kw.get('umask')
    if umask:
        comma_sep_opts.append('umask=' + umask)

    mnt_options = kw.get('mnt_options')
    if mnt_options:
        for mnt_opt in mnt_options:
            comma_sep_opts.append(mnt_opt)
    +/

    if (comma_sep_opts.length)
        mount_opts ~= ["-o", comma_sep_opts.join(",")];

    return mount_opts.idup;
}


/**
 * Mount one single unencrypted disk. No 'already mounted' check is done.
 */
private void _do_mount_nocrypt(string exec_prog,
                               string disk,
                               string mountpoint)
{
    ensure_mntdir_exists(mountpoint);
    scope(failure) remove_automatically_created_dir(mountpoint);

    immutable mount_opts = _get_mount_opts(dev_fs(disk));

    auto args = [exec_prog] ~ mount_opts ~ [dev_path(disk), mountpoint];
    runCommand(args);
}



