#!/bin/sh

# This script outputs an appropriate init.c, given the .mod files.

MERCURY_MOD_LIB_DIR=${MERCURY_MOD_LIB_DIR:-@LIBDIR@/modules}
MERCURY_MOD_LIB_MODS=${MERCURY_MOD_LIB_MODS:-@LIBDIR@/modules/*.mod}

defentry=NULL
while getopts w: c
do
	case $c in
	w)	defentry="\"$OPTARG\"";;
	\?)	echo "Usage: mod2init -[wentry] modules ..."
		exit 1;;
	esac
	shift `expr $OPTIND - 1`
done

files="$* $MERCURY_MOD_LIB_MODS"
modules="`sed -n '/^BEGIN_MODULE(\(.*\)).*$/s//\1/p' $files`"
echo "/*";
echo "** This code was automatically generated by mod2init.";
echo "** Do not edit.";
echo "**"
echo "** Input files:"
for file in $files; do 
	echo "** $file"
done
echo "*/";
echo "";
echo '#include <stddef.h>';
echo '#include "init.h"';
echo "";
echo "const char *default_entry = $defentry;";
echo "";
for mod in $modules; do
	echo "extern void $mod(void);";
done
echo "";
echo "void init_modules(void)";
echo "{";
for mod in $modules; do
	echo "	$mod();";
done
echo "}";
