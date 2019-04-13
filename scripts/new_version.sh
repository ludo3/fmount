#!/bin/bash

script="`readlink -f "$0"`"
scriptdir="`dirname "$script"`"
base="`dirname "$scriptdir"`"

cd "$base"

set -ueo pipefail
EINVAL=22  # Invalid argument

usage()
{
  local name="`basename "$0"`"
  echo 'Usage: $name [Options...] <version>'
  echo ""
  echo 'Options:'
  echo '  -h, --help   Print this message and exit.'
  echo '  -d, --debug  Print debug informations: variable values, run command.'
  echo '  -n, --nogit  Do not modify the git repository.'
  echo '  -t, --test   Do not modify any file; implies "--nogit".'
  echo ""
  echo '<version>  The version to be created.'
  echo ""
  echo 'Examples:'
  echo '    ./scripts/tag_version.sh 3.7.3'
  echo '    ./scripts/tag_version.sh 3.7.4-alpha1'
}

rungit()
{
  if [ "$debug" = "yes" ]; then
    echo git "$@"
  fi
  if [ "$git" = "yes" ]; then
    git "$@"
  fi
}

debug=no
git=yes
test=no
VER=""

if [ $# -eq 0 ]; then
  usage >&2
  exit $EINVAL
fi

options=$(getopt -o hdnt -l help,debug,nogit,test -- "$@")
if [ $? -ne 0 ]; then
  echo "Invalid options." >&2
  exit $EINVAL
fi

eval set -- "$options"

while [ $# -gt 0 ]; do
  case "$1" in
    ("-h" | "--help")
      # On usage request, dump it to stdout.
      usage
      exit
      ;;

    ("-d" | "--debug")
      debug=yes
      ;;

    ("-n" | "--nogit")
      git=no
      ;;

    ("-t" | "--test")
      git=no
      test=yes
      ;;

    ("--")
      # do nothing
      /bin/true
      ;;

    (*)
      if [ -n "$VER" ]; then
        {
          echo "Cannot replace version '$VER' with '$1'."
          echo ""
          usage
        } >&2
        exit $EINVAL
      else
        VER="$1"
      fi
      ;;
  esac
  shift
done

if ! [[ $VER =~ ^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)[0-9]+)?$ ]]; then
  echo "Invalid version format '$VER'" >&2
  exit $EINVAL
fi

BASE=`echo ${VER} | cut -d - -f 1`
SUFFIX=`echo $VER | cut -d - -f 2 -s`

MAJOR=`echo ${BASE} | cut -d . -f 1`
MINOR=`echo ${BASE} | cut -d . -f 2`
PATCH=`echo ${BASE} | cut -d . -f 3`
VERSION_KIND="release"
KIND_NUM=0
if [ -n "$SUFFIX" ]; then
  VERSION_KIND="`echo "${SUFFIX}" | sed 's,[0-9]*,,g'`"
  KIND_NUM="`echo "${SUFFIX}" | sed 's,[a-z]*,,g'`"
fi
echo ""

if [ "$debug" = "yes" ]; then
  echo "debug is $debug"
  echo "git is $git"
  echo "BASE is $BASE"
  echo "SUFFIX is $SUFFIX"
  echo ""
  echo "MAJOR is $MAJOR"
  echo "MINOR is $MINOR"
  echo "PATCH is $PATCH"
  echo "VERSION_KIND is $VERSION_KIND"
  if [ "$VERSION_KIND" != "release" ]; then
    echo "KIND_NUM is $KIND_NUM"
  fi
fi

#FIXME version structure in src/fmount/version.d
sedscript="`mktemp new_version-sedscript-XXXXXXXXXXXXXXXXXXX.sed`"
trap "rm -f -- \"${sedscript}\"" EXIT
cat >"$sedscript" << END
s,\(enum\s\+MAJOR\s*=\s*\)[0-9]\+\s*;,\1$MAJOR;,
s,\(enum\s\+MINOR\s*=\s*\)[0-9]\+\s*;,\1$MINOR;,
s,\(enum\s\+PATCH\s*=\s*\)[0-9]\+\s*;,\1$PATCH;,
s,\(enum\s\+VersionKind\s\+KIND\s*=\s*VersionKind\.\)[a-z]\+\s*;,\1$VERSION_KIND;,
s,\(enum\s\+KIND_NUM\s*=\s*\)[0-9]\+\s*;,\1$KIND_NUM;,
END

if [ "$debug" = "yes" ]; then
  echo sedscript "$sedscript" :
  cat "$sedscript" | sed 's,^,    ,'
  echo ""
  echo "sed --in-place -f \"$sedscript\" src/fmount/appver.d"
fi

inplace="--in-place"
[ "$test" = "yes" ] && inplace=""

sed $inplace -f "$sedscript" src/fmount/appver.d

rungit --no-pager diff
rungit add src/fmount/appver.d
rungit commit --message "Version $VER"
rungit tag --sign --message "$VER" "$VER"

