# tests for miscellaneous builtins not tested elsewhere
set +p
set +o posix

ulimit -c 0 2>/dev/null

# check that break breaks loops
for i in a b c; do echo $i; break; echo bad-$i; done
echo end-1
for i in a b c; do echo $i; break 1; echo bad-$i; done
echo end-2
for i in a b c; do
	for j in x y z; do
		echo $i:$j
		break
		echo bad-$i
	done
	echo end-$i
done
echo end-3

# check that break breaks nested loops
for i in a b c; do
	for j in x y z; do
		echo $i:$j
		break 2
		echo bad-$i
	done
	echo end-$i
done
echo end

# check that continue continues loops
for i in a b c; do echo $i; continue; echo bad-$i ; done
echo end-1
for i in a b c; do echo $i; continue 1; echo bad-$i; done
echo end-2
for i in a b c; do
	for j in x y z; do
		echo $i:$j
		continue
		echo bad-$i-$j
	done
	echo end-$i
done
echo end-3

# check that continue breaks out of nested loops
for i in a b c; do
	for j in x y z; do
		echo $i:$j
		continue 2
		echo bad-$i-$j
	done
	echo end-$i
done
echo end

# check that `eval' re-evaluates arguments, but `builtin' and `command' do not
AVAR='$BVAR'
BVAR=foo

echo $AVAR
builtin echo $AVAR
command echo $AVAR
eval echo \$AVAR
eval echo $AVAR

# test out eval with a temp environment
AVAR=bar eval echo \$AVAR
BVAR=xxx eval echo $AVAR

unset -v AVAR BVAR

# test umask
mask=$(umask)
umask 022
umask
umask -S
umask -S u=rwx,g=rwx,o=rx >/dev/null # 002
umask
umask -S
umask -p
umask -p -S
umask 0
umask -S
umask ${mask}	# restore original mask

# builtin/command without arguments should do nothing.  maybe someday they will
builtin
command

# test enable
enable -ps

enable -aps ; enable -nps

enable -n test
case "$(type -t test)" in
builtin)	echo oops -- enable -n test failed ;;
*)	echo enable -n test worked ;;
esac

enable test
case "$(type -t test)" in
builtin)	echo enable test worked ;;
*)	echo oops -- enable test failed ;;
esac

# test options to exec
(exec -a specialname ${THIS_SH} -c 'echo $0' )
(exec -l -a specialname ${THIS_SH} -c 'echo $0' )
# test `clean' environment.  if /bin/sh is bash, and the script version of
# printenv is run, there will be variables in the environment that bash
# sets on startup.  Also test code that prefixes argv[0] with a dash.
(export FOO=BAR ; exec -c -l printenv ) | grep FOO
(FOO=BAR exec -c printenv ) | grep FOO

(export FOO=BAR ; exec printenv ) | grep FOO
(FOO=BAR exec printenv ) | grep FOO

# ok, forget everything about hashed commands
hash -r
hash

# this had better succeed, since command -p guarantees we will find the
# standard utilties
command -p hash rm

# check out source/.

# sourcing a zero-length-file had better not be an error
rm -f /tmp/zero-length-file
cp /dev/null /tmp/zero-length-file
. /tmp/zero-length-file
echo $?
rm /tmp/zero-length-file

AVAR=AVAR

. ./source1.sub
AVAR=foo . ./source1.sub

. ./source2.sub
echo $?

set -- a b c
. ./source3.sub

# make sure source with arguments does not change the shell's positional
# parameters, but that the sourced file sees the arguments as its
# positional parameters
echo "$@"
. ./source3.sub x y z
echo "$@"

# but if the sourced script sets the positional parameters explicitly, they
# should be reflected in the calling shell's positional parameters.  this
# also tests one of the shopt options that controls source using $PATH to
# find the script
echo "$@"
shopt -u sourcepath
. source4.sub
echo "$@"

# this is complicated when the sourced scripts gets its own positional
# parameters from arguments to `.'
set -- a b c
echo "$@"
. source4.sub x y z
echo "$@"

# test out cd and $CDPATH
${THIS_SH} ./builtins1.sub

# test behavior of `.' when given a non-existant file argument
${THIS_SH} ./source5.sub

# test bugs in sourcing non-regular files, fixed post-bash-3.2
${THIS_SH} ./source6.sub

# test bugs with source called from multiline aliases and other contexts
${THIS_SH} ./source7.sub

# in posix mode, assignment statements preceding special builtins are
# reflected in the shell environment.  `.' and `eval' need special-case
# code.
set -o posix
echo $AVAR
AVAR=foo . ./source1.sub
echo $AVAR

AVAR=AVAR
echo $AVAR
AVAR=foo eval echo \$AVAR
echo $AVAR

AVAR=AVAR
echo $AVAR
AVAR=foo :
echo $AVAR
set +o posix

# but assignment statements preceding `export' are always reflected in 
# the environment
foo="" export foo
declare -p foo
unset foo

# assignment statements preceding `declare' should be displayed correctly,
# but not persist after the command
FOO='$$' declare -p FOO
declare -p FOO
unset FOO

# except for `declare -x', which should be equivalent to `export'
FOO='$$' declare -x FOO
declare -p FOO
unset FOO

# test out kill -l.  bash versions prior to 2.01 did `kill -l num' wrong
sigone=$(kill -l | sed -n 's:^ 1) *\([^ 	]*\)[ 	].*$:\1:p')

case "$(kill -l 1)" in
${sigone/SIG/})	echo ok;;
*)	echo oops -- kill -l failure;;
esac

# kill -l and trap -l should display exactly the same output
sigonea=$(trap -l | sed -n 's:^ 1) *\([^ 	]*\)[ 	].*$:\1:p')

if [ "$sigone" != "$sigonea" ]; then
	echo oops -- kill -l and trap -l differ
fi

# POSIX.2 says that exit statuses > 128 are mapped to signal names by
# subtracting 128 so you can find out what signal killed a process
case "$(kill -l $(( 128 + 1)) )" in
${sigone/SIG/})	echo ok;;
*)	echo oops -- kill -l 129 failure;;
esac

# out-of-range signal numbers should report the argument in the error
# message, not 128 less than the argument
kill -l 4096

# kill -l NAME should return the signal number
kill -l ${sigone/SIG/}

# test behavior of shopt xpg_echo
${THIS_SH} ./builtins2.sub

# test behavior of declare -g
${THIS_SH} ./builtins3.sub

# test behavior of using declare to create variables without assigning values
${THIS_SH} ./builtins4.sub

# test behavior of set and unset array variables
${THIS_SH} ./builtins5.sub

# test behavior of unset builtin with -f and -v options
${THIS_SH} ./builtins6.sub

# this must be last -- it is a fatal error
exit status

echo after bad exit
