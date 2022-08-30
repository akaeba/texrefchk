#!/bin/bash
# **********************************************************************
#  @copyright:  Copyright 2022
#  @license:    GPLv3
#  @credits:    AKAE
#
#  @author:     Andreas Kaeberlein
#  @maintainer: Andreas Kaeberlein
#  @email:      andreas.kaeberlein@web.de
#
#  @file:       texrefchk.sh
#  @date:       2022-08-06
#
#  @brief:      checks labels and references for consistency
#
#               extracts all labels from *.tex files in the search dir
#               and checks for non unique labels and for existence of
#               referenced labels.
#                 ./texrefchk.sh --texdir=./tex/myProject
# **********************************************************************



# ----------------------------------------------------------------------
# Help Variables
#
SCP_VERSION="0.1.0"                                 # Version
SCP_PATH_ABS=$(dirname "$(readlink -f "$0")")       # get scripts absolute path
SCP_PATH_WORK_ABS=$(pwd)                            # absolute path to work dir
SCP_TEX_LABEL_FILE="texrefchk.label"                # stores extracted labels from tex sources
SCP_TEX_REF_FILE="texrefchk.ref"                    # stores extracted references from tex sources
SCP_TEX_REF_KEY="autoref{ nameref{ ref{ hyperref["  # reference keys to search for, backslash for tex command and closing bracket is automatically added
SCP_TEX_LABEL_NOT_UNIQ="non_unique_labels.txt"      # file with non unique labels
SCP_TEX_REF_NOT_DEF="non_defined_references.txt"    # non defined references
SCP_ERO_END=0                                       # if set, abnormal end
# ----------------------------------------------------------------------



# ----------------------------------------------------------------------
# Extracts keys from fiven tex files
#   Positional Arguments:
#     $1: file
#     $2: key
texKeyExtract(){
    # local variables
    local tex;  # buffer of tex file
    local key;  # extract content surrounded by this
    local bkto; # bracket open
    local bktc; # bracket close
    # preprocess file
    IFS=;               # delete line break settings
    tex=$(cat ${1});    # load file
    tex=$(echo ${tex} | sed 's/\\%//g')     # remove all masked comments '\%'
    tex=$(echo ${tex} | grep -o '^[^%]*');  # filter all comments out
    # prepare key
    key=${2}                # second command line argument
    specifier=${key: -1};   # get last character
    key=${key:: -1};        # drop last character
    if [ '{' == ${specifier} ] || [ '[' == ${specifier} ]; then # process 'key' with '{' or '['
        # build bracket ops
        case ${specifier} in
            '{')
                bkto="{";
                bktc="}";
                ;;
            '[')
                bkto="\\["; # mask operator in SED
                bktc="\\]";
                ;;
            *)
                return;
                ;;
        esac;
        # process tex file
        tex=$(echo ${tex} | grep -o -E "(^|\\\)${key}${bkto}[^][]*${bktc}");    # tex       -> key{xxxx}
        tex=$(echo ${tex} | sed "s/^[^:]*${bkto}//g");                          # key{xxxx} -> xxxx}
        tex=$(echo ${tex} | sed "s/${bktc}.*//");                               # xxxx}     -> xxxx
    elif [ '=' == ${specifier} ]; then
        tex=$(echo ${tex} | grep -o '\label=[^][]*');   # tex                  -> key=xxxx, key2=value
        tex=$(echo ${tex} | sed 's/,\].*//');           # key=xxxx, key2=value ->  key=xxxx
        tex=$(echo ${tex} | sed 's/^.*=//');            # key=xxxx             -> xxxx
    fi;

    # trim trailing/leading blanks
    tex=${tex##*( )};   # leading
    tex=${tex%%*( )};   # trailing
    # return values
    unset IFS;
    echo ${tex}
}
# ----------------------------------------------------------------------



# ----------------------------------------------------------------------
# User message
#
echo "[ INFO ]    texrefchk started"
echo "              Version : v${SCP_VERSION}"
echo "              Script  : ${SCP_PATH_ABS}"
# ----------------------------------------------------------------------



# ----------------------------------------------------------------------
# Process required flags
#

arg_texdir="."  # tex root
arg_verbose=0   # advanced outputs
arg_stopOnEro=0 # stop on first error

# iterate over arguments
for i in `seq 1 $#`; do
    # expand
    eval expArg=$(echo \$\{${i}\})
    # decide
    if [ $(echo ${expArg} | grep -o "\-\-verbose") ]; then
        arg_verbose=1
    elif [ $(echo ${expArg} | grep -o "\-\-stoponerror") ]; then
        arg_stopOnEro=1
    elif [ $(echo ${expArg} | grep -o "\-\-texdir") ]; then
        arg_texdir=${expArg#*=} # ${var#*SubStr} # will drop begin of string up to first occur of `SubStr`; https://stackoverflow.com/questions/918886/how-do-i-split-a-string-on-a-delimiter-in-bash
    else
        echo "[ FAIL ]    Unrecognized option: '${expArg}'"
        exit 1
    fi
done
# ----------------------------------------------------------------------



# ----------------------------------------------------------------------
# Assemble Paths to tex Files
#
# relative path
if [ "." = $(echo ${arg_texdir} | cut -c1) ]; then  # relative path, 'cut -c1' extracts first character
    texdir=${SCP_PATH_WORK_ABS}/${arg_texdir}
else
    texdir=${arg_texdir}
fi
# check if dir exists
if [ ! -d ${texdir} ]; then
    echo "[ FAIL ]    Tex dir does not exist";
    echo "              Path: '${texdir}'";
    exit 1
fi
# user message
echo "              Tex-Dir : ${texdir}"
# ----------------------------------------------------------------------



# ----------------------------------------------------------------------
# List Texfiles for check
#
IFS=$'\n'   # set for split
texFiles=($(find ${texdir} -type f -name "*\.tex" | sed -n "s|^${texdir}/||p")) # split into array, IFS setting required, https://unix.stackexchange.com/questions/104800/find-output-relative-to-directory
unset IFS;  # restore old bash line break settings
if [ ${arg_verbose} -eq 1 ]; then
    for i in "${texFiles[@]}"; do
        echo "DEBUG: Tex-File: '${i}'"
    done
fi
echo "[ INFO ]    Found Tex Files ${#texFiles[@]}"
# ----------------------------------------------------------------------



# ----------------------------------------------------------------------
# Extract Labels
#
# create empty file
if [ -f "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_FILE}" ]; then
    rm -f "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_FILE}"
fi
touch "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_FILE}"
# Get: \label{xxxxx}
labelcnt=0
for file in "${texFiles[@]}"; do
    # https://unix.stackexchange.com/questions/232657/delete-till-first-occurrence-of-colon-using-sed
    # https://stackoverflow.com/questions/56688546/how-to-grep-an-exact-string-with-slash-in-it
    labels=($(cat ${texdir}/${file} | grep -o -E "(^|\\\)label{[^][]*}" | sed 's/^[^:]*{//g' | sed 's/}.*//')); # label{xxxx} -> xxxx} -> xxxx
    for label in "${labels[@]}"; do
        # count labels
        labelcnt=$((labelcnt+1))
        # add to label file
        echo "${label} % ${file}" >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_FILE}"
        # debug
        if [ ${arg_verbose} -eq 1 ]; then
            echo "DEBUG: file=${file} label=${label}"
        fi
    done
done
# Get: label=xxxxx
for file in "${texFiles[@]}"; do
    labels=($(cat ${texdir}/${file} | grep -o '\label=[^][]*' | sed 's/^.*=//' | sed 's/,\].*//')); # label=xxxx -> xxxx
    for label in "${labels[@]}"; do
        # count labels
        labelcnt=$((labelcnt+1))
        # add to label file
        echo "${label} % ${file}" >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_FILE}"
        # debug
        if [ ${arg_verbose} -eq 1 ]; then
            echo "DEBUG: file=${file} label=${label}"
        fi
    done
done
echo "[ INFO ]    Found Labels ${labelcnt}"
# ----------------------------------------------------------------------



# ----------------------------------------------------------------------
# Check for non uniqe labels
#
nonUniqLabels=($(cat "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_FILE}" | sed 's/ % .*//' | sort | uniq -d -i))
if [ ! -z ${nonUniqLabels} ]; then
    # check for ero file
    if [ -f "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_NOT_UNIQ}" ]; then
        rm -f "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_NOT_UNIQ}"
    fi
    touch "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_NOT_UNIQ}"
    # mark for abnormal end
    SCP_ERO_END=$((SCP_ERO_END | 1))
    echo "[ FAIL ]    Found ${#nonUniqLabels[@]} non unique labels"
    # get issued files
    for nonUniqLabel in "${nonUniqLabels[@]}"; do
        # console
        echo "              ${nonUniqLabel}"    # print to console
        # file
        echo ${nonUniqLabel} >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_NOT_UNIQ}"
        printf -- '-%.0s' `eval echo {1..${#nonUniqLabel}}` >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_NOT_UNIQ}"
        printf '\n' >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_NOT_UNIQ}"
        # get file location
        #   https://unix.stackexchange.com/questions/186543/how-to-grep-exact-word-with-only-space-as-word-separator
        uniqFiles=($(cat "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_FILE}" | grep -E "(^| )${nonUniqLabel}( |$)" | uniq | sed 's/^.* % //'));    # sed deleted after ' % '
        for uniqFile in "${uniqFiles[@]}"; do
            echo "                ${uniqFile}"  # print to console
            echo "  ${uniqFile}" >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_NOT_UNIQ}"
        done
        echo "" >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_NOT_UNIQ}"
    done
fi
if [ 1 -eq ${arg_stopOnEro} ] && [ 1 -eq ${SCP_ERO_END} ]; then
    echo "[ FAIL ]    texrefchk ended with errors :-("
    exit 1
fi
# ----------------------------------------------------------------------


# ----------------------------------------------------------------------
# Extract references
#
# create empty file
if [ -f "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_FILE}" ]; then
    rm -f "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_FILE}"
fi
touch "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_FILE}"
# Iterate Over keys
refcnt=0
for key in ${SCP_TEX_REF_KEY}; do
    # generate grep selector
    bracket_open=${key: -1} # get last character from string
    bracket_close=$(printf "\x$(printf %x $(($(printf '%d' "'${bracket_open}")+2)))");  # in ascii table is closing bracket to chars after opening bracket
    key=${key:: -1}         # drop last character
    # Debug
    if [ ${arg_verbose} -eq 1 ]; then
        echo "DEBUG: Selector: \\${key}${bracket_open} ${bracket_close}"
    fi
    # mask control sequence
    if [ '[' == ${bracket_open} ]; then
        bracket_open="\\${bracket_open}"
        bracket_close="\\${bracket_close}"
    fi;
    # iterate over files
    for file in "${texFiles[@]}"; do
        # https://unix.stackexchange.com/questions/232657/delete-till-first-occurrence-of-colon-using-sed
        # https://stackoverflow.com/questions/56688546/how-to-grep-an-exact-string-with-slash-in-it
        refs=($(cat ${texdir}/${file} | grep -o -E "(^|\\\)${key}${bracket_open}[^][]*${bracket_close}" | sed "s/^[^:]*${bracket_open}//g" | sed "s/${bracket_close}.*//")); # label{xxxx} -> xxxx} -> xxxx
        for ref in "${refs[@]}"; do
            # count references
            refcnt=$((refcnt+1))
            # add to ref file
            echo "${ref} % ${file}" >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_FILE}"
            # debug
            if [ ${arg_verbose} -eq 1 ]; then
                echo "DEBUG: file=${i} ref=${j}"
            fi
        done
    done
done
echo "[ INFO ]    Found References ${refcnt}"
# ----------------------------------------------------------------------



# ----------------------------------------------------------------------
# Check against listed labels
#
#   https://stackoverflow.com/questions/4168371/how-can-i-remove-all-text-after-a-character-in-bash
uniqRefs=($(cat "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_FILE}" | sed 's/ % .*//' | uniq));  # sed deleted after ' % '
nonRefs=()  # empty array
# cross check found references against define labels
for ref in "${uniqRefs[@]}"; do
    if [ -z $(cat "${SCP_PATH_WORK_ABS}/${SCP_TEX_LABEL_FILE}" | grep -o -E "(^| )${ref}( |$)") ]; then
        nonRefs+=(${ref})   # in case of no match add to undefined list
    fi
done
if [ ! -z "${nonRefs}" ]; then
    # some flags
    SCP_ERO_END=$((SCP_ERO_END | 1))
    echo "[ FAIL ]    Found ${#nonRefs[@]} references without label"
    # check for ero file
    if [ -f "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_NOT_DEF}" ]; then
        rm -f "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_NOT_DEF}"
    fi
    touch "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_NOT_DEF}"
    # get issued files
    for nonRef in "${nonRefs[@]}"; do
        # console
        echo "              ${nonRef}"  # print to console
        # file
        echo ${nonRef} >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_NOT_DEF}"
        printf -- '-%.0s' `eval echo {1..${#nonRef}}` >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_NOT_DEF}"
        printf '\n' >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_NOT_DEF}"
        # get file location
        #   https://unix.stackexchange.com/questions/186543/how-to-grep-exact-word-with-only-space-as-word-separator
        nonRefFiles=($(cat "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_FILE}" | grep -E "(^| )${nonRef}( |$)" | uniq | sed 's/^.* % //'));  # sed deleted after ' % '
        for nonRefFiles in "${nonRefFiles[@]}"; do
            echo "                ${nonRefFiles}"   # print to console
            echo "  ${nonRefFiles}" >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_NOT_DEF}"
        done
        echo "" >> "${SCP_PATH_WORK_ABS}/${SCP_TEX_REF_NOT_DEF}"
    done
fi;
if [ 1 -eq ${arg_stopOnEro} ] && [ 1 -eq ${SCP_ERO_END} ]; then
    echo "[ FAIL ]    texrefchk ended with errors :-("
    exit 1
fi
# ----------------------------------------------------------------------



# ----------------------------------------------------------------------
# Normal End?
#
if [ 1 -eq ${SCP_ERO_END} ]; then
    echo "[ INFO ]    Summary:"
    echo "              Non Unique Labels : ${#nonUniqLabels[@]}"
    echo "              Broken References : ${#nonRefs[@]}"
    echo "[ FAIL ]    texrefchk ended with errors :-("
    exit 1
fi
echo "[ INFO ]    Summary:"
echo "              TeX files  : ${#texFiles[@]}"
echo "              Labels     : ${labelcnt}"
echo "              References : ${refcnt}"
echo "            analyzed with no broken references and non unique labels"
echo "[ OKAY ]    texrefchk ended normally :-)"
exit 0
# ----------------------------------------------------------------------
