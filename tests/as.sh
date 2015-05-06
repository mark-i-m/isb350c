#!/bin/bash

echoerr() {
    echo $1;
    echo "Usage: ./as.sh filename outfile";
    exit 1;
}

findlabel() {
    # pass in the name of the label
    INSCOUNT=0
    while read line2
    do
        PIECES=($line2)
        case ${PIECES[0]} in
            *: )
                if [[ "@${PIECES[0]}" = "$1:" ]]; then
                    LABELPC=$((INSCOUNT))
                    LABELPC=`echo "obase=16; $LABELPC" | bc`
                    while [[ ${#LABELPC} -lt "$3" ]]
                    do # must have $3 hex digits
                        LABELPC="0$LABELPC"
                    done
                    break ;
                else
                    LABELPC=''
                fi
                ;;
            '//' ) # comments
                continue ;
                ;;
            '' ) # blank lines
                continue ;
                ;;
            *  ) # instructions/data
                INSCOUNT=$((INSCOUNT+1))
                ;;
        esac
    done < $2

    if [[ -z "$LABELPC" ]]; then
        echoerr "Label not found: $1"
    fi
}

if [[ $# -lt 2 ]] ; then
    echoerr "Missing filename(s)"
fi

if ! [[ -f $1 ]] ; then
    echoerr "File not found: $1"
fi

rm -f $2
touch $2

PC=0
DATASECTION=0

while read line
do
    PARTS=($line)

    OP=${PARTS[0]} # case insensitive
    A=${PARTS[1]}
    B=${PARTS[2]}
    C=${PARTS[3]}

    [ -z "$OP" ] && continue # skip empty lines

    case $OP in
        'mov'|'movi'|'imov' )
            if [[ -z "$A" ]]; then
                echoerr "MOV without i field"
            fi
            if [[ -z "$B" ]]; then
                echoerr "MOV without t field"
            fi

            OPCODE="0"

            case $A in
                [0-9a-fA-F]|[0-9a-fA-F][0-9a-fA-F] )
                    I=$A
                    if [[ ${#I} -eq "1" ]] ; then # must have 2 hex digits
                        I="0$I"
                    fi
                    ;;
                @* )
                    findlabel "$A" "$1" 2
                    I=$LABELPC
                    ;;
                * )
                    echoerr "INVALID MOV: $line"
                    ;;
            esac

            T=$B

            INSOUT="${OPCODE}${I}${T}"
            ;;
        'add' )
            if [[ -z "$A" ]]; then
                echoerr "ADD without a field"
            fi
            if [[ -z "$B" ]]; then
                echoerr "ADD without b field"
            fi
            if [[ -z "$C" ]]; then
                echoerr "ADD without t field"
            fi

            OPCODE="1"
            INSOUT="${OPCODE}${A}${B}${C}"
            ;;
        'jmp' )
            if [[ -z "$A" ]]; then
                echoerr "JMP without j field"
            fi

            OPCODE="2"

            case $A in
                [0-9a-fA-F]|[0-9a-fA-F][0-9a-fA-F]|[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F] )
                    J=$A
                    if [[ ${#J} -eq 1 ]] ; then # must have 3 hex digits
                        J="0$J"
                    fi
                    if [[ ${#J} -eq 2 ]] ; then # must have 3 hex digits
                        J="0$J"
                    fi
                    ;;
                @* )
                    findlabel "$A" "$1" 3
                    J=$LABELPC
                    ;;
                * )
                    echoerr "INVALID JMP: $line"
                    ;;
            esac

            INSOUT="${OPCODE}${J}"
            ;;
        'hlt' | 'halt' )
            OPCODE="3"
            INSOUT="${OPCODE}000"
            ;;
        'ld' )
            if [[ -z "$A" ]]; then
                echoerr "LD without i field"
            fi
            if [[ -z "$B" ]]; then
                echoerr "LD without t field"
            fi

            OPCODE="4"

            case $A in
                [0-9a-fA-F]|[0-9a-fA-F][0-9a-fA-F] )
                    I=$A
                    if [[ ${#I} -eq "1" ]] ; then # must have 2 hex digits
                        I="0$I"
                    fi
                    ;;
                @* )
                    findlabel "$A" "$1" 2
                    I=$LABELPC
                    ;;
                * )
                    echoerr "INVALID LD: $line"
                    ;;
            esac

            T=$B

            INSOUT="${OPCODE}${I}${T}"
            ;;
        'ldr' )
            if [[ -z "$A" ]]; then
                echoerr "LDR without a field"
            fi
            if [[ -z "$B" ]]; then
                echoerr "LDR without b field"
            fi
            if [[ -z "$C" ]]; then
                echoerr "LDR without t field"
            fi

            OPCODE="5"
            INSOUT="${OPCODE}${A}${B}${C}"
            ;;
        'jeq' )
            if [[ -z "$A" ]]; then
                echoerr "JEQ without a field"
            fi
            if [[ -z "$B" ]]; then
                echoerr "JEQ without b field"
            fi
            if [[ -z "$C" ]]; then
                echoerr "JEQ without d field"
            fi

            OPCODE="6"
            INSOUT="${OPCODE}${A}${B}${C}"
            ;;
        'st' )
            if [[ -z "$A" ]]; then
                echoerr "ST without S field"
            fi
            if [[ -z "$B" ]]; then
                echoerr "ST without A field"
            fi

            OPCODE="7"

            case $A in
                [0-9a-fA-F]|[0-9a-fA-F][0-9a-fA-F] )
                    S=$A
                    if [[ ${#S} -eq "1" ]] ; then # must have 2 hex digits
                        S="0$S"
                    fi
                    ;;
                @* )
                    findlabel "$A" "$1" 2
                    S=$LABELPC
                    ;;
                * )
                    echoerr "INVALID ST: $line"
                    ;;
            esac

            INSOUT="${OPCODE}${B}${S}"
            ;;
        'data:' ) # data section label
            DATASECTION=1
            continue ;
            ;;
        ?*: ) # labels
            continue ;
            ;;
        '//' ) # comments
            continue ;
            ;;
        '' ) # blank lines
            continue ;
            ;;
        * )
            if [[ $DATASECTION -eq 0 ]]; then
                echoerr "Unknown instruction: $OP"
            fi
            INSOUT=$OP
            ;;
    esac

    PC_HEX=`echo "obase=16; $PC" | bc`
    echo -e "${PC_HEX}\t${INSOUT}\t${line}"
    echo "$INSOUT" >> $2
    PC=$((PC+1))
done < $1

echo "Assembled $1 to $2"
