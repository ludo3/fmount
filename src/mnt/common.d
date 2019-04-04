// Written in the D programming language.

/**
Functions common to mount, unmount and/or format commands.

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
module mnt.common;

import core.stdc.errno : ENOENT, ENOTDIR, EPERM;
import std.algorithm : canFind, map, startsWith;
import std.array : array, split;
import std.conv : to;
import std.file : dirEntries, exists, FileException, isDir, mkdir, readText,
                  remove, rmdir, SpanMode, write;
import std.path : bn=baseName, dn=dirName, isAbsolute;
import std.process : ProcessException;
import std.regex : matchFirst, regex;
import std.string : format;
import std.traits : isSomeString;

import appconfig;
import appargs : fake, verbose;
import constvals : how_to_run_as_root, VbLevel;
import dev : dev_path, dev_link_paths, get_dm_and_raw_dev, is_removable, is_usb;
import dutil.exceptions : printThChain;
import osutil : assertDirExists, jn;
import ui : dbug, dbugf, error, errorf, info_, trace, tracef, warn,
            WithPrefix;


// TODO use args.get_conf_dir(verbose, test), create a config file .fmountrc,
//      put default_options into it

/// The default hardcoded mount options.
enum default_options = "noatime,noexec";


/**
 * Retrieve the expected path to the mount directory for device `dev`.
 * Params:
 *     S         = A string type.
 *     dev       = A path to a block device.
 *     mountname = The name of the directory where the device will be mounted.
 */
S get_expected_mountpoint(S)(S dev, S mountname)
if (isSomeString!S)
{
    if (isAbsolute(mountname))
        return mountname;

    S root = getRoot();
    return jn(root, mountname);
}


/**
 * The names for files used to mark automatically created directories.
 *
 * Such markup files are used for automatic deletion when the directories are
 * not needed any more.
 */
private enum CreatedBy : string
{
    /// The directory has been created by fmount.
    Fmount = ".created_by_fmount",

    /// The directory has been created by pmount (for compatibility).
    Pmount = ".created_by_pmount"
}


/**
 * Ensure that a directory exists. The parent directory must exist.
 *
 * If the directory is created automatically then it is marked with an empty
 * file named `CreatedBy.Fmount`.
 *
 * Params:
 *     S    = A string type.
 *     path = The path to a directory to be checked or created.
 */
void ensure_mntdir_exists(S)(S path)
if (isSomeString!S)
{
    assertDirExists(dn(path));

    if ( !exists(path) )
    {
        trace("Creating directory ", path);
        if (!fake)
            mkdir(path);

        auto autocreated_file = jn(path, CreatedBy.Fmount);
        dbug("Creating file ", autocreated_file);
        if (!fake)
            autocreated_file.write("");
    }
    else if ( !isDir(path) )
    {
        throw new FileException(path, ENOTDIR);
    }
}


/**
 * Remove an automatically created directory.
 *
 * The directory is removed if it only contains one of the empty files
 * `CreatedBy.Fmount` or `CreatedBy.Pmount`.
 */
void remove_automatically_created_dir(S)(S path)
if (isSomeString!S)
{
    auto autocreated = false;
    string[] entries;
    if (exists(path) && isDir(path))
    {
        try
        {
            entries = map!("a.name")(dirEntries(path, SpanMode.shallow)).array;
        }
        catch(Exception ex)
        {
            if (verbose >= VbLevel.More)
                printThChain(ex);
        }
    }

    if ((entries !is null) && entries.length == 1)
    {
        immutable entryName = bn(entries[0]);
        if (entryName == CreatedBy.Fmount
            || entryName == CreatedBy.Pmount)
        {
            autocreated = true;
            auto autocreated_file = entries[0];

            dbug("Removing ", autocreated_file);
            if (!fake)
            {
                try
                {
                    remove(autocreated_file);
                }
                catch(FileException)
                {
                    // removal silently failed.
                }
            }
        }
    }

    if (autocreated)
    {
        trace("Removing directory ", path);
        if (!fake)
            rmdir(path);
    }
}


/// Matches one `mountpoint` line in `/proc/mounts` .
private immutable _MpRx =
    regex(`^(?P<dev>\S+)\s+(?P<mp>\S+)\s+(?P<fs>\S+)\s+.*$`);

/**
 * Check whether a device is mounted and return the associated matcher.
 */
private auto
_get_mountpoint_match(string device, string mountpoints_path="/proc/mounts")
{
    // Regex note : cannot create static captures.
    /// Unmatching `mountpoint` line.
    auto _NoMpMatch = "".matchFirst(_MpRx);

    // Check whether the device is a mounted dmcrypt partition.
    device = get_dm_and_raw_dev(device)[0];

    immutable devpaths = ([dev_path(device)] ~ dev_link_paths(device)).idup;

    string mountpoints = readText(mountpoints_path);
    foreach (string line; mountpoints.split("\n"))
    {
        foreach (string dp; devpaths)
        {
            if (startsWith(line, dp))
            {
                auto match = line.matchFirst(_MpRx);
                if (!match.empty)
                    return match;

                // no match
                return _NoMpMatch;
            }
        }
    }

    // no match
    return _NoMpMatch;
}


/**
 * Retrieve a named capture from an `_MpRx` `matchFirst`.
 */
private string _get_procmounts_namedCap(string name,
                                        string device,
                                        string dflt = "")
{
    assert(canFind(["dev", "mp", "fs"], name),
                   format!"Invalid mountpoint attribute '%s'."(name));

    if (device is null || device.length == 0)
        return dflt;

    auto match =  _get_mountpoint_match(device);
    if (!match.empty)
        return match[name];

    return dflt;
}

/**
 * Find the filesystem of a mounted device, if any.
 *
 * If the device is encrypted then the mountpoint is found through the device
 * mapper.
 *
 * Params:
 *     device = The path to a block device.
 *     dflt   = the default filesystem value to be returned.
 */
string get_filesystem(string device, string dflt = "")
{
    return _get_procmounts_namedCap("fs", device, dflt);
}


/**
 * Find the mountpoint of the device, if any.
 *
 * If the device is encrypted then the mountpoint is found through the device
 * mapper.
 *
 * Params:
 *     device = The path to a block device.
 *     dflt   = the default filesystem value to be returned.
 */
string find_mountpoint(string device, string dflt="")
{
    return _get_procmounts_namedCap("mp", device, dflt);
}


/**
 * Check that the requested device is not in `/etc/fstab`, in which case custom
 * options must be disabled, letting `mount` and `umount` work as usual.
 *
 * Params:
 *     S      = A string type.
 *     device = A path to a block device.
 *     prog   = The program name.
 */
bool is_in_fstab(S)(S device)
if (isSomeString!S)
{
    auto mp = get_fstab_mountpoint(device);
    return mp !is null && mp.length > 0;
}

/**
 * Check that the requested device is not in `/etc/fstab`, in which case custom
 * options must be disabled, letting `mount` and `umount` work as usual.
 *
 * Params:
 *     S      = A string type.
 *     device = A path to a block device.
 *     prog   = The program name.
 */
S get_fstab_mountpoint(S)(S device)
if (isSomeString!S)
{
    import std.functional : toDelegate;
    import constvals : FSTAB_PATH;

    alias devPath = dev_path!S;
    alias devLinkPaths = dev_link_paths!S;

    return _fstab_mp!S(device,
                       FSTAB_PATH,
                       toDelegate(&devPath),
                       toDelegate(&devLinkPaths));
}

private S _fstab_mp(S)(S device, string fstab_path,
                       S delegate(S dev_or_lnk) getPath,
                       S[] delegate(S dev, S[] dirs = []) getLnkPaths)
if (isSomeString!S && isSomeString!(typeof(fstab_path)))
{
    import std.algorithm.searching : startsWith;
    import std.path : dn=dirName;
    import std.regex : regex, matchFirst;
    import std.stdio: File;
    import std.string : toLower, toUpper;
    import std.range.primitives : ElementType;
    import std.traits: Unqual;

    import constvals : FSTAB_ATTR_PATT, FSTAB_DEVPATH_PATT;

    alias Char = Unqual!(ElementType!S);

    Char[] buf;
    auto fstab = File(fstab_path);
    auto attrRx = regex(to!(Char[])(FSTAB_ATTR_PATT));
    auto pathRx = regex(to!(Char[])(FSTAB_DEVPATH_PATT));

    while (fstab.readln(buf))
    {
        auto m = matchFirst(buf, attrRx);
        if (m)
        {
            auto attrName = m["name"];
            immutable string fstDirName = "by-" ~ to!string(attrName).toLower();
            auto fstLinkName = m["attr"];

            foreach (path; [getPath(device)] ~ getLnkPaths(device))
            {
                immutable string dir_name = bn(dn(path));
                immutable string name = bn(path);

                if (dir_name == fstDirName && name == to!string(fstLinkName))
                {
                    S mp = to!S(m["mp"]);
                    tracef("%s (%s=%s) is in %s => %s",
                           device, attrName, fstLinkName, fstab_path, mp);
                    return mp;
                }
            }
        }
        else
        {
            m = matchFirst(buf, pathRx);
            if (m)
            {
                immutable fstDevPath = to!S(m["devPath"]);
                foreach (path; [getPath(device)] ~ getLnkPaths(device))
                {
                    if (path == fstDevPath)
                    {
                        S mp = to!S(m["mp"]);

                        if (path == device)
                            tracef("%s is in %s => %s", device, fstab_path, mp);
                        else
                            tracef("%s(%s) is in %s => %s",
                                   device, path, fstab_path, mp);

                        return mp;
                    }
                }
            }
        }
    }

    dbugf("%s is not in %s", device, fstab_path);
    return "";
}

unittest
{
    import std.format : _f = format;
    import std.regex : matchFirst;
    import appargs : verbose;
    import constvals : FSTAB_ATTR_PATT, FSTAB_DEVPATH_PATT, VbLevel;
    import dutil.file : MaybeTempFile;
    import dutil.src : srcln, unused;
    import osutil : removeIfExists;
    import ui : dbug;

    //verbose = VbLevel.Dbug;

    immutable attrLine = "UUID=076373AA55FCD80F /mnt/fstab_test    ntfs    " ~
        "nodiratime,relatime,user,noauto     0       2\n";
    immutable pathLine = "/dev/disk/by-uuid/076373AA55FCD80F " ~
        "/mnt/fstab_test    ntfs    nodiratime,relatime,user,noauto" ~
        "     0       2\n";

    auto mA = matchFirst(attrLine, FSTAB_ATTR_PATT);
    auto mP = matchFirst(pathLine, FSTAB_DEVPATH_PATT);

    assert(mA);
    assert(mA["name"] == "UUID");
    assert(mA["attr"] == "076373AA55FCD80F");
    assert(mA["mp"] == "/mnt/fstab_test");

    assert(mP);
    assert(mP["devPath"] == "/dev/disk/by-uuid/076373AA55FCD80F");
    assert(mP["mp"] == "/mnt/fstab_test");

    dbug("fstab unittests ok, to be improved");


    string mockPath(alias string path)(string) { return path; }

    template mockLnkPaths(lnks...)
    {
        static foreach(i, lnk; lnks)
        {
            static assert(!is(lnk), _f!"lnks[%d] is %s"( i, lnk.stringof));
            static assert(isSomeString!(typeof(lnk)),
                          _f!"typeof(lnks[%d]) is not some string: %s"
                             (i, lnk.stringof));
        }

        string[] mockLnkPaths(string dev, string[] dirs = [])
        {
            unused(dev);
            unused(dirs);

            static if (lnks.length == 1)
                return [lnks[0]];
            else
                return lnks.array;
        }
    }

    void test_fstab(alias expectedMountPoint,
                    alias fstabContent,
                    alias devPath,
                    alias devOrLnkPaths,
                    string file=__FILE__,
                    size_t line=__LINE__)()
    if (isSomeString!(typeof(expectedMountPoint)) &&
        isSomeString!(typeof(fstabContent)) &&
        isSomeString!(typeof(devPath)))
    in
    {
        import std.format : _f=format;
        import std.typecons: isTuple, Tuple;

        alias LnkType = typeof(devOrLnkPaths);
        static if (!isSomeString!LnkType)
        {
            static assert(isTuple!(LnkType),
                          _f!"devOrLnkPaths type is '%s' instead of tuple"
                             (LnkType.stringof));
            static foreach(i; 0..LnkType.Types.length)
                static assert(isSomeString!(LnkType.Types[i]),
                    _f!("Among '%s': devOrLnkPaths[%d] type is '%s' instead of"
                      ~ " some string")(LnkType.Types.stringof, i,
                                        LnkType.Types[i].stringof));
        }
    }
    do
    {
        auto tempfstab = MaybeTempFile("fstab", ".tmp");
        tempfstab.writeln(fstabContent);
        tempfstab.flush();

        static if (isSomeString!(typeof(devOrLnkPaths)))
            string mp =
                _fstab_mp(devPath, tempfstab.name,
                          &mockPath!devPath,
                          &mockLnkPaths!(devOrLnkPaths));
        else
            string mp =
                _fstab_mp(devPath, tempfstab.name,
                          &mockPath!devPath,
                          &mockLnkPaths!(devOrLnkPaths.expand));

        assert(mp == expectedMountPoint,
               _f!"fstab mountpoint is '%s'\nfstab tested here:\n@%s(%d)"
                 (mp, file, line));
    }

    test_fstab!("/mnt/myUsbKey", `
ID=usb-Innostor_Innostor_000000000000000176-0:0-part1    /mnt/myUsbKey`,
        "/dev/sdc1",
        "/dev/disk/by-id/usb-Innostor_Innostor_000000000000000176-0:0-part1")
        ();

    test_fstab!("/mnt/RemovableDisk",
                "LABEL=UserDisk    /mnt/RemovableDisk",
                "/dev/sdc1",
                "/dev/disk/by-label/UserDisk")
        ();

    test_fstab!("/mnt/MyDisk",
                "PARTUUID=UserDisk    /mnt/MyDisk",
                "/dev/sdc1",
                "/dev/disk/by-partuuid/UserDisk")
        ();

    test_fstab!("/mnt/MyDiskByPath",
                "PATH=UsrDisk    /mnt/MyDiskByPath",
                "/dev/sdb1",
                "/dev/disk/by-path/UsrDisk")
        ();

    test_fstab!("/mnt/InternalDrive",
                "UUID=076373AA55FCD80F    /mnt/InternalDrive",
                "/dev/sda3",
                "/dev/disk/by-uuid/076373AA55FCD80F")
        ();

    // mismatch
    test_fstab!("",
                "UUID=SimpleNTFS    /mnt/anotherUsbKey",
                "/dev/sde2",
                "/dev/disk/by-label/SimpleNTFS")
        ();

    // mismatch
    test_fstab!("",
                "LABEL=076373AA55FCD80F    /mnt/yetAnotherUsbKey",
                "/dev/sdg7",
                "/dev/disk/by-uuid/076373AA55FCD80F")
        ();

    test_fstab!("/mnt/eightthDisk",
                "NEWKEY=someValue1234567    /mnt/eightthDisk",
                "/dev/sdh4",
                "/dev/disk/by-newkey/someValue1234567")
        ();

    // mismatch
    test_fstab!("",
                "NEWKEY=someValue1234567    /mnt/yetAnotherUsbKey2",
                "/dev/sde12",
                "/dev/disk/by-label/someValue1234567")
        ();

    // mismatch
    test_fstab!("",
                "LABEL=someValue1234567    /mnt/yetAnotherUsbKey3",
                "/dev/sdg7",
                "/dev/disk/by-newkey/someValue1234567")
        ();

    test_fstab!("/mnt/ninethDisk",
                "/dev/sdi2    /mnt/ninethDisk",
                "/dev/sdi2",
                "/dev/disk/by-anything/xxxxxxx")
        ();

    test_fstab!("/mnt/tenthDisk",
                "/dev/disk/by-label/disk10    /mnt/tenthDisk",
                "/dev/sdj0",
                "/dev/disk/by-label/disk10")
        ();

    // mismatch
    test_fstab!("",
                "/dev/sdk1    /mnt/eleventhDisk",
                "/dev/sdk11",
                "/dev/disk/by-anything/xxxxxxx")
        ();

    // mismatch
    test_fstab!("",
                "/dev/disk/by-uuid/01234567EA    /mnt/eleventhDisk",
                "/dev/sdl12",
                "/dev/disk/by-uuid/01234567FD")
        ();
}

/**
 * Check that the program is run as root, either from sudo or super, or with
 * setuid bit set.
 *
 * Params:
 *     S      = A string type.
 *     device = A path to a block device.
 *     prog   = The program name.
 */
void check_user(S)(S device, S prog)
if (isSomeString!S)
{
    import core.sys.posix.unistd : geteuid;
    import std.process : environment;

    import osutil : getRealUserAndGroup;

    auto euid = geteuid();

    //FIXME to be tested with sudo and super.
    auto real_user = getRealUserAndGroup();

    if (euid == 0)
    {
        string sudoCmd = environment.get("SUDO_COMMAND");
        string superCmd = environment.get("SUPERCMD");

        if (sudoCmd)
            tracef("Running sudo command '%s'.", sudoCmd);
        else if (superCmd)
            tracef("Running super command '%s'.", superCmd);

        bool removable = is_removable(device);
        bool usb = is_usb(device);

        if (removable || usb)
        {
            if (verbose >= VbLevel.More)
            {
                auto r_or_u = "";
                auto op_permitted =
                    ("%s device %s: "
                   ~ "Operation permitted for real_user='%s' as "
                   ~ "effective_user='root'.");
                if (usb)
                    r_or_u = "usb";
                if (removable)
                {
                    if (r_or_u.length > 0)
                        r_or_u ~= " ";
                    r_or_u ~= "removable";
                }
                tracef(op_permitted, r_or_u, device, real_user);
            }

            return;
        }
        else
        {
            // TODO check configuration : allow or disallow fixed devices
            //                            at system level.

            // if the user is really root, only warn about fixed device;
            // otherwise the action is forbidden.
            warn("The device ", device, " is not removable.");
            if (real_user == "root:root")
                return;
        }
    }
    else
    {
        errorf("%s cannot be run as '%s'.", prog, real_user);
        error!(WithPrefix.No)(how_to_run_as_root);
    }

    throw ProcessException.newFromErrno(EPERM);
}

