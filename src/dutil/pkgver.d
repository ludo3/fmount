// Written in the D programming language.

/**
Version description.

Copyright: Copyright Ludovic Dordet 2018.
License:   $(HTTP www.gnu.org/licenses/gpl-3.0.md,
             GNU GENERAL PUBLIC LICENSE 3.0).
Authors:   Ludovic Dordet
*/
/*
         Copyright Ludovic Dordet 2019.
Distributed under the GNU GENERAL PUBLIC LICENSE, Version 3.0.
   (See accompanying file LICENSE.md or copy at
         http://www.gnu.org/licenses/gpl-3.0.md)
*/
module dutil.pkgver;

import std.conv : to;

private enum char sep = '.';
private enum char pre = '-';

/// Gather version informations.
struct Version
{
    /// Major version number.
    size_t major;

    /// Minor version number.
    size_t minor;

    /// Patch version number.
    size_t patch;

    /// Version kind.
    VersionKind kind;

    /// Number of iterations for the version kind.
    size_t knum;

    /// Describe the version.
    string toString() const
    {
        import std.array : appender;
        auto w = appender!string;
  
        w.put(major.to!string);
        w.put(sep);
        w.put(minor.to!string);
        w.put(sep);
        w.put(patch.to!string);
  
        if (kind != VersionKind.release)
        {
            w.put(pre);
            w.put(kind.to!string);

            if (kind != VersionKind.unreleased)
                w.put(knum.to!string);
        }

        return w.data;
    }

}

/// Version unittest
unittest
{
    import std.algorithm.comparison : equal;
    import std.format : _f = format;

    immutable VersionKind[] kinds = [
        VersionKind.unreleased,
        VersionKind.alpha,
        VersionKind.beta,
        VersionKind.rc
    ];

    foreach(maj; 0..32)
    {
        foreach(min; 0..12)
        {
            foreach(pat; 0..14)
            {
                foreach(k; kinds)
                {
                    foreach (n; 1..16)
                    {
                        immutable ver = Version(maj, min, pat, k, n);
                        immutable exp = _f!"%d.%d.%d-%s%d"(maj, min, pat, k, n);
                        assert(ver.toString == exp);
                    }
                }

                immutable ver = Version(maj, min, pat, VersionKind.release, 0);
                immutable exp = _f!"%d.%d.%d"(maj, min, pat);
                assert(ver.toString == exp);
            }
        }
    }
}

/// The kind of version
enum VersionKind : string
{
    /// Unreleased build, should only be used for test purpose.
    unreleased = "unreleased",

    /// Alpha version, for early user-level testing.
    alpha = "alpha",

    /// Beta version, for many user-level testing.
    beta = "beta",

    /// Release candidate version, for full testing.
    rc = "rc",

    /// Release
    release = "release"
}


/// VersionKind dummy unittest
unittest
{
    import std.algorithm.comparison : equal;

    assert(equal(VersionKind.unreleased.to!string, "unreleased"));
    assert(equal(VersionKind.alpha.to!string, "alpha"));
    assert(equal(VersionKind.beta.to!string, "beta"));
    assert(equal(VersionKind.rc.to!string, "rc"));
    assert(equal(VersionKind.release.to!string, "release"));
}


