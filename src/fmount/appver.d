// Written in the D programming language.

/**
Application version.

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
module fmount.appver;

import dutil.pkgver : Version, VersionKind;

/// The major version number, changed with functional changes.
enum MAJOR = 0;

/// The minor version number, changed with technical changes.
enum MINOR = 0;

/// The patch version number, changed with bug fixes.
enum PATCH = 0;

/// The version kind: unreleased, alpha, beta, rc (release candidate), release.
enum VersionKind KIND = VersionKind.dev;

/// The number of iterations for the version kind (alpha1, alpha2, ...) .
enum KIND_NUM = 0;

/// The full version.
enum Version ver = Version(MAJOR, MINOR, PATCH, KIND, KIND_NUM);

