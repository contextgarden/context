# Example setup file for ConTeXt distribution
#
# Author:  Hans Hagen
# Patches: Arthur R. & Mojca M.
# (t)csh version: Alan B.
#
# Usage :
#   source setuptex.csh [texroot]
#
# On the first run also execute:
#   mktexlsr
#   texexec --make --alone

echo "We are considering removing setuptex.csh in case that nobody uses it."
echo "If you still use this file please drop us some mail at"
echo "    gardeners (at) contextgarden (dot) net"
echo "If we don't get any response, we will delete it in near future."

#
# PLATFORM
#

# we will try to guess the platform first
# (needs to be kept in sync with first-setup.sh and mtxrun)
# if yours is missing, let us know

set system=`uname -s`
set cpu=`uname -m`

switch ( $system )
  # linux
  case Linux:
    switch ( $cpu )
      case i*86:
        set platform="linux"
        breaksw
      case x86_64:
      case ia64:
        set platform="linux-64"
        breaksw
      case ppc:
      case ppc64:
        set platform="linux-ppc"
        breaksw
      default:
        set platform="unknown"
    endsw
    breaksw
  # Mac OS X
  case Darwin:
    switch ( $cpu )
      case i*86:
        set platform="osx-intel"
        breaksw
      case x86_64:
        set platform="osx-64"
        breaksw
      case ppc*:
      case powerpc:
      case power*:
      case Power*:
        set platform="osx-ppc"
        breaksw
      default:
        set platform="unknown"
    endsw
    breaksw
  # FreeBSD
  case FreeBSD:
  case freebsd:
    switch ( $cpu )
      case i*86:
        set platform="freebsd"
        breaksw
      case x86_64:
        set platform="freebsd"
        breaksw
      case amd64:
        set platform="freebsd-amd64"
        breaksw
      default:
        set platform="unknown"
    endsw
    breaksw
  # OpenBSD
  case OpenBSD:
    switch ( $cpu )
      case i*86:
        set platform="openbsd"
        breaksw
      case amd64:
        set platform="openbsd-amd64"
        breaksw
      default:
        set platform="unknown"
    endsw
    breaksw
  # cygwin
  case CYGWIN:
    switch ( $cpu )
      case i*86:
        set platform="cygwin"
        breaksw
      case x86_64:
      case ia64:
        set platform="cygwin-64"
        breaksw
      default:
        set platform="unknown"
    endsw
    breaksw
  # SunOS/Solaris
  case SunOS:
    switch ( $cpu )
      case sparc:
        set platform="solaris-sparc"
        breaksw
      case i86pc:
        set platform="solaris-intel"
      default:
        set platform="unknown"
    endsw
    breaksw
  # Other
  default:
    set platform="unknown"
endsw

if ( $platform == "unknown" ) then
  echo Error: your system \"$system $cpu\" is not supported yet.
  echo Please report to the ConTeXt mailing-list (ntg-context@ntg.nl).
endif

#
# PATH
#

# this resolves to path of the setuptex script
# We use $0 for determine the path to the script, except for bash and (t)csh where $0
# always is bash or (t)csh.

# but one can also call
# . setuptex path-to-tex-tree

# first check if any path has been provided in the argument, and try to use that one
if ( $# > 0 ) then
	setenv TEXROOT $1
else
	# $_ should be `history -h 1` but doesn't seem to work...
	set cmd=`history -h 1`
	if ( $cmd[2]:h == $cmd[2]:t ) then
		setenv TEXROOT $cwd
	else
		setenv TEXROOT $cmd[2]:h
	endif
	unset cmd
endif
cd $TEXROOT; setenv TEXROOT $cwd; cd -

if ( -f "$TEXROOT/texmf/tex/plain/base/plain.tex" ) then
	echo Setting \"$TEXROOT\" as TEXROOT.
else
	echo \"$TEXROOT\" is not a valid TEXROOT path.
	echo There is no file \"$TEXROOT/texmf/tex/plain/base/plain.tex\".
	echo Please provide a proper tex root (like \"source setuptex /path/tex\")
	unsetenv TEXROOT
	exit
endif

unsetenv TEXINPUTS MPINPUTS MFINPUTS

# ConTeXt binaries have to be added to PATH
setenv TEXMFOS $TEXROOT/texmf-$platform
setenv PATH $TEXMFOS/bin:$PATH
# TODO: we could set OSFONTDIR on Mac for example

# setenv CTXMINIMAL yes
