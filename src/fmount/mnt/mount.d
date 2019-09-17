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
module fmount.mnt.mount;

import std.algorithm.iteration : filter;
import std.algorithm.searching : canFind, findAmong, findSplit, startsWith;
import std.array : array, join, replace, split;
import std.functional : not;
import std.path : bn=baseName;
import std.traits : hasMember;

import devices.dev : dev_descr, dev_display, dev_fs, dev_path, get_dm_name,
             is_encrypted, search_dev_path;
import devices.devargs : passphrase_file;
import devices.luks : luksOpen, luksClose;
import dutil.appargs : exec_dirs, fake, verbose;
import dutil.constvals : VbLevel;
import fmount.config : getRoot;
import fmount.mnt.common :
    check_user, ensure_mntdir_exists, find_mountpoint,
    get_expected_mountpoint, get_fstab_mountpoint,
    remove_automatically_created_dir;
import fmount.mnt.mountargs :
    atimes, charset, exec, force_readonly_or_readwrite,
    options, sync, type, umask;
import dutil.os : get_exec_path, runCommand;
import dutil.ui : dbugf, infof, read_password, show_warnings, traceStack, warnf;


/**
 * Main fmount function.
 * Params:
 *     prog = The fmount program path.
 *     args = The positional arguments.
 */
void fmount(string prog, string[] args) {
    immutable string requested_device = args[0];
    immutable string device_path = search_dev_path(requested_device);
    string mountpoint;

    if (args.length > 1)
        mountpoint = args[1];

    enum fmountArgsFmt = `
  %s(device_path=%s, mountpoint=%s);
    `;

    dbugf(fmountArgsFmt, prog, device_path, mountpoint);

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

    if (mountpoint is null || mountpoint.length == 0)
        mountpoint = bn(requested_device);

    infof("Mounting %s to %s", descr, mountpoint);

    // request a password if needed,
    // put it password into a temporary file,
    // and tell to 'cryptsetyp' to use that password file.
    string description;
    if (is_encrypted(device_path))
        description = dev_descr(device_path, dev_display(device_path));

    auto pwf = read_password(description, passphrase_file);

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

            _do_mount_nocrypt(exec_prog, dmdev, mountpoint);
        }
        else
        {
            _do_mount_nocrypt(exec_prog, disk, mountpoint);
        }
    }
    catch(Exception ex)
    {
        traceStack(ex);
        string descr = dev_descr(disk, dev_display(disk));
        show_warnings(descr ~ ": " ~ ex.message);
    }
}


private immutable static string[][string] overriden_options;

static this()
{
    immutable string[][string] opts = [
        "async": ["sync"],
        "atime": ["noatime", "diratime", "nodiratime",
                  "norelatime", "relatime"],
        "auto": ["noauto"],
        "diratime": ["atime", "nodiratime"],
        "defaults":
            ["rw", "suid",   "dev",   "exec",   "auto",   "nouser", "async",
             "ro", "nosuid", "nodev", "noexec", "noauto", "user",   "sync"],
        "dev": ["nodev"],
        "exec": ["noexec"],
        "iversion": ["noiversion"],
        "lazytime": ["nolazytime"],
        "loud": ["silent"],
        "mand": ["nomand"],
        "noauto": ["auto"],
        "noatime": ["atime", "diratime", "nodiratime",
                    "norelatime", "relatime"],
        "nodev": ["dev"],
        "nodiratime": ["diratime"],
        "noexec": ["exec"],
        "noiversion": ["iversion"],
        "nolazytime": ["lazytime"],
        "nomand":["mand"],
        "norelatime": ["relatime"],
        "nosuid": ["suid"],
        "nouser": ["user", "users"],
        "owner": ["dev", "suid"], // owner implies nosuid and nodev
        "relatime": ["atime", "norelatime"],
        "ro": ["rw"],
        "rw": ["ro"],
        "silent": ["loud"],
        "suid": ["nosuid"],
        "sync": ["async"],
        "user": ["dev", "exec", "nouser", "suid"],
        "users": ["dev", "exec", "nouser", "suid"]
    ];

    overriden_options = opts;
}

private string[] filteroutOverridenOpts(string newOption, string[] currOptions)
{
    immutable sep = "=";
    immutable overrides = overriden_options.get(newOption, []);
    immutable splittedNew = newOption.findSplit(sep);
    immutable bool newIsNamed = splittedNew[1].length > 0;
    immutable string newOptName = splittedNew[0];

    bool isOverriden(string s)
    {
        if (newIsNamed)
        {   // handle umask= ..., charset= ...
            immutable splitted = s.findSplit(sep);
            immutable isNamed = splitted[1].length > 0;
            return isNamed && splitted[0] == newOptName;
        }
        else
            return overrides.canFind(s);
    }

    return currOptions
        .filter!(a => not!isOverriden(a))()
        .array
        ~ newOption;

}


private enum _DFLT_USER_OPT = "user";
private static immutable string[] _USER_OPTS = [ "user", "users" ];

private string _get_named_option(string name)
                                (string initialOption, string[] options)
{
    string selectedOption = initialOption;
    immutable pfx = name ~ "=";

    foreach (option; options)
    {
        if (option.startsWith(pfx))
        {
            string overridingOption = option[pfx.length..$];
            if (overridingOption != selectedOption && selectedOption !is null
                && selectedOption.length > 0)
            {
                infof("%s '%s' is overriden by '%s'",
                      name, selectedOption, overridingOption);
                selectedOption = overridingOption;
            }
        }
    }

    return selectedOption;
}

/**
 * Parse the mount options and translate them for pmount or mount.
 */
private string[] _get_mount_opts(string dev_file_system)
{
    string[] mount_opts = [];
    string[] mount_cs_opts = [];
    string[] cs_opts = options.dup;

    // make sure that "user" or "users" is first in mount_cs_opts
    auto foundUsr = cs_opts.findAmong(_USER_OPTS);
    if (foundUsr.length == 0)
        mount_cs_opts ~= [ _DFLT_USER_OPT ];

    if (type !is null && type.length > 0)
        mount_opts ~= [ "--types", type ];

    alias force_ro_rw = force_readonly_or_readwrite;
    if (force_ro_rw !is null && force_ro_rw.length > 0)
        mount_opts ~= force_ro_rw;

    foreach(atime; atimes)
    {
        mount_cs_opts = filteroutOverridenOpts(atime, mount_cs_opts);
    }

    if (exec)
        mount_cs_opts ~= "exec";

    if (sync)
        mount_cs_opts ~= "sync";
    // Note: noexec is implied by "user" and by "users".

    string selectedCharset = _get_named_option!"charset"(charset, cs_opts);

    if (selectedCharset !is null && selectedCharset.length > 0)
    {
        string optName = "iocharset";
        if (type == "ntfs" || dev_file_system == "ntfs")
            optName = "nls";

        mount_cs_opts ~= optName ~ "=" ~ selectedCharset;
    }

    string selectedUmask = _get_named_option!"umask"(umask, cs_opts);
    if (selectedUmask !is null && selectedUmask.length > 0)
    {
        mount_cs_opts ~= "umask=" ~ selectedUmask;
    }

    foreach(option; cs_opts)
    {
        auto splittedOpts = option.split(",");
        foreach(oneOpt; splittedOpts)
            mount_cs_opts = filteroutOverridenOpts(oneOpt, mount_cs_opts);
    }

    if (verbose >= VbLevel.More)
        mount_opts ~= "--verbose";

    if (fake)
        mount_opts ~= "--fake";


    // TODO get configuration and get mount options from configuration.

    if (mount_cs_opts.length)
        mount_opts ~= ["-o", mount_cs_opts.join(",")];

    return mount_opts;
}

version(unittest)
{
    import std.format : _f = format;
    import std.stdio : stderr;
    import std.typecons : tuple;
    import dutil.src : srcln;
    import dutil.trx : immbkv;

    private auto bkupOptions()
    {
        immutable res
            = tuple(immbkv(verbose), immbkv(fake), immbkv(exec_dirs),
                     immbkv(passphrase_file),
                     immbkv(force_readonly_or_readwrite),
                     immbkv(atimes),
                     immbkv(exec),
                     immbkv(type),
                     immbkv(charset),
                     immbkv(umask),
                     immbkv(sync),
                     immbkv(options));
        return res;
    }

    private mixin template immutableVars(alias suffix)
    {
        immutable string s = to!string(suffix);

        mixin(_f!"immutable VbLevel verbose%s = verbose;"(s));
        mixin(_f!"immutable bool fake%s = fake;"(s));
        mixin(_f!"immutable string[] exec_dirs%s = exec_dirs.idup;"(s));
        mixin(_f!"immutable string passphrase_file%s = passphrase_file.idup;"
                 (suffix));
        mixin(_f!`immutable string force_readonly_or_readwrite%s
            = force_readonly_or_readwrite.idup;`(s));
        mixin(_f!"immutable string[] atimes%s = atimes.idup;"(s));
        mixin(_f!"immutable bool exec%s = exec;"(s));
        mixin(_f!"immutable string type%s = type.idup;"(s));
        mixin(_f!"immutable string charset%s = charset.idup;"(s));
        mixin(_f!"immutable string umask%s = umask.idup;"(s));
        mixin(_f!"immutable bool sync%s = sync;"(s));
        mixin(_f!"immutable string[] options%s = options.idup;"(s));
    }

    private mixin template assertUnchanged(alias suffix)
    {
        enum string s = to!string(suffix);

        void chk1(alias name)()
        {
            auto var = mixin(name);
            auto bkp = mixin(name ~ s);

            assert(var == bkp,
                    _f!"assertUnchanged!%s : %s is '%s' instead of '%s'"
                       (suffix, name, var, bkp));
        }

        void check()
        {
            chk1!"verbose"();
            chk1!"fake"();
            chk1!"exec_dirs"();
            chk1!"passphrase_file"();
            chk1!"force_readonly_or_readwrite"();
            chk1!"atimes"();
            chk1!"exec"();
            chk1!"type"();
            chk1!"charset"();
            chk1!"umask"();
            chk1!"sync"();
            chk1!"options"();
        }
    }
}

// bkupOptions test
unittest
{
    import core.exception : AssertError;
    import std.conv : to;
    import std.exception : assertThrown;
    import std.format : _f = format;
    import std.traits : isSomeString;

    import dutil.src : unused;

    immutable opts0 = bkupOptions();
    unused(opts0);

    mixin immutableVars!0;
    mixin assertUnchanged!(0) assert0;

    options = [ "changed", "options" ];
    assertThrown!AssertError(assert0.check(), "bad options");

    options = options0.dup;
    assert0.check();

    options = [ "changed", "options" ];
    mixin immutableVars!1;
    mixin assertUnchanged!(1) assert1;
    {
        immutable opts1 = bkupOptions();
        unused(opts1);
        passphrase_file = "/tmp/passphrase";
        assertThrown!AssertError(assert1.check(), "bad passphrase_file");
    }
    assert1.check();

    passphrase_file = "/tmp/passphrase";
    mixin immutableVars!2;
    mixin assertUnchanged!(2) assert2;
    {
        immutable opts2 = bkupOptions();
        charset = "rtf-7";
        assertThrown!AssertError(assert1.check(), "bad charset");
        unused(opts2);
    }
    assert2.check();
}

/// Mount Options unittest without any configuration
unittest
{
    import std.algorithm.comparison : equal;
    import dutil.constvals : VbLevel;
    import dutil.src : unused;
    import fmount.mnt.mountargs : dflt_atimes, ForceReadWrite;

    immutable opts0 = bkupOptions();
    unused(opts0);

    void assertOpts(alias id, string file=__FILE__, size_t line=__LINE__, X...)
                   (string fileSystem, string[] expected, lazy X expressions)
    {
        static foreach(expr; expressions)
            expr();

        auto mount_opts = _get_mount_opts(fileSystem);

        assert(equal(mount_opts, expected),
               _f!"assertOpts!%s :\n%s: mount_opts are %s"
                  (id, srcln(file, line), mount_opts));
    }

    foreach(lvl; [ VbLevel.None, VbLevel.Warn, VbLevel.Info ] )
    {
        verbose = lvl;
        assertOpts!0("", [ "-o", "user,noatime" ]);
    }

    foreach(lvl; [ VbLevel.More, VbLevel.Dbug ] )
    {
        verbose = lvl;
        assertOpts!1("", [ "--verbose", "-o", "user,noatime" ]);
    }

    options = [ "users" ];
    assertOpts!"users"("", [ "--verbose", "-o", "noatime,users" ]);
    options = [];

    fake = true;
    assertOpts!"fake"("", [ "--verbose", "--fake", "-o", "user,noatime" ]);
    fake = false;

    force_readonly_or_readwrite = ForceReadWrite.RO;
    assertOpts!"ro"("", [ ForceReadWrite.RO, "--verbose",
                            "-o", "user,noatime" ]);
    force_readonly_or_readwrite = ForceReadWrite.RW;
    assertOpts!"rw"("", [ ForceReadWrite.RW, "--verbose",
                            "-o", "user,noatime" ]);
    force_readonly_or_readwrite = ForceReadWrite.None;

    atimes = dflt_atimes ~ [ "relatime" ];
    assertOpts!"relatime"("", [ "--verbose", "-o", "user,noatime,relatime" ]);

    atimes = dflt_atimes ~ [ "diratime", "relatime" ];
    assertOpts!"diratime,relatime"("", [ "--verbose", "-o",
                                         "user,noatime,diratime,relatime" ]);
    atimes = dflt_atimes ~ [ "atime" ];
    assertOpts!"atime"("", [ "--verbose", "-o", "user,atime" ]);

    atimes = dflt_atimes ~ [ "atime", "diratime" ];
    assertOpts!"atime,diratime"("", [ "--verbose", "-o", "user,diratime" ]);
    atimes = dflt_atimes.dup;

    exec = true;
    assertOpts!"exec"("", [ "--verbose", "-o", "user,noatime,exec" ]);
    exec = false;

    type = "btrfs";
    assertOpts!"type"("", [ "--types", "btrfs", "--verbose",
                            "-o", "user,noatime" ]);
    type = "";

    charset = "utf-16";
    assertOpts!"charset"("", [ "--verbose",
                               "-o", "user,noatime,iocharset=utf-16" ]);
    type = "ntfs";
    assertOpts!"ntfs,charset(1/2)"("",
                                   [ "--types", "ntfs",
                                     "--verbose",
                                     "-o", "user,noatime,nls=utf-16" ]);
    type = "";
    assertOpts!"ntfs,charset(2/2)"("ntfs",
                                   [ "--verbose",
                                     "-o", "user,noatime,nls=utf-16" ]);
    charset = "";

    umask = "027";
    assertOpts!"umask"("", [ "--verbose",
                             "-o", "user,noatime,umask=027" ]);
    umask = "";

    sync = true;
    assertOpts!"sync"("", [  "--verbose",
                             "-o", "user,noatime,sync" ]);
    sync = false;

    atimes = dflt_atimes ~ [ "diratime" ];
    options = [ "relatime" ];
    assertOpts!"diratime,opt=relatime"("",
                                       [ "--verbose", "-o",
                                         "user,noatime,diratime,relatime" ]);

    atimes = dflt_atimes ~ [ "diratime" ];
    options = [ "nodiratime,relatime" ];
    assertOpts!"diratime,opt=nodiratime,relatime"
        ("", [ "--verbose", "-o",
               "user,noatime,nodiratime,relatime" ]);
    atimes = dflt_atimes.dup;

    // Note: such a call will be rejected by mount.
    force_readonly_or_readwrite = ForceReadWrite.RO;
    options = [ "rw" ];
    assertOpts!"--read-only,rw"
        ("", [ ForceReadWrite.RO, "--verbose", "-o",
               "user,noatime,rw" ]);
    force_readonly_or_readwrite = ForceReadWrite.None;

    sync = true;
    options = [ "async" ];
    assertOpts!"--sync,async"("", [ "--verbose", "-o", "user,noatime,async" ]);
    sync = false;

    charset = "utf-16";
    options = [ "iocharset=utf-32" ];
    assertOpts!"charset,iocharset"("", [ "--verbose", "-o",
                                         "user,noatime,iocharset=utf-32" ]);
    charset = "utf-16";
    options = [ "nls=utf-32" ];
    type = "ntfs";
    assertOpts!"ntfs,charset,nls"("", [ "--types", "ntfs", "--verbose", "-o",
                                        "user,noatime,nls=utf-32" ]);
    charset = "";
    type = "";

    umask = "077";
    options = [ "umask=072" ];
    assertOpts!"umask,umask=072"("", [ "--verbose",
                                       "-o", "user,noatime,umask=072" ]);
    umask = "";
    options = [];
}

/// TODO Mount Options unittest with system configuration
/// TODO Mount Options unittest with user configuration
/// TODO Mount Options unittest with both system and user configurations.

/**
 * Mount one single unencrypted disk. No 'already mounted' check is done.
 */
private void _do_mount_nocrypt(string exec_prog,
                               string disk,
                               string mountpoint)
{
    import std.conv : to;

    string[] mount_opts;
    auto fstab_mountpoint = get_fstab_mountpoint(disk);
    string mp = get_expected_mountpoint(disk, mountpoint);

    if (fstab_mountpoint !is null && fstab_mountpoint.length > 0)
    {
        mp = to!string(fstab_mountpoint);

        if (mp != mountpoint)
            warnf("Using fstab mountpoint '%s' instead of '%s'",
                  fstab_mountpoint, mountpoint);
    }
    else
    {
        mount_opts = _get_mount_opts(dev_fs(disk));
    }

    ensure_mntdir_exists(mp);
    scope(failure) remove_automatically_created_dir(mp);

    auto args = [exec_prog] ~ mount_opts ~ [dev_path(disk), mp];
    runCommand(args);
}


