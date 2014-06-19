#!/bin/bash
# time-suspend.sh


############################
# DECLARATION VARIABLES
############################
verbose=false
action="suspend"
suffix=("s" "m" "h" "d")
mesures=("seconds" "minutes" "hours" "days")
default_sfx=1
default_number=30
default="$default_number${suffix[$default_sfx]}"
tempo=$default


###########################
# FONCTIONS
##########################

# montre l'aide
showhelp()
{
    local i

    echo -e "\nOptions :"
    echo -e "\t-h : print this help and exit"
    echo -e "\t-v : enable verbose output\n"
    echo -e "\t-r : l'action à la fin du script est 'reboot'"
    echo -e "\t-s : l'action à la fin du script est 'shutdown'"
    echo -e "\t-b : l'action à la fin du script est 'hibernate'"
    echo -e "\t L'action par default est 'suspend' (mise en veille). Si plus d'une option d'action est donné la dérnière est prise en compte\n"
    echo -e "Utilisation du script :"
    echo -e "\t$0 [-options] [number] [suffix]"
    echo -e "\t\t number : le nombre de unités de temps ( $default_number par default )"
    echo -e "\t\t suffix : l'unité de mesure du temps ( ${suffix[$default_sfx]} = ${mesures[$default_sfx]} par default ) "
    echo -e "\t\t\t le suffix doit avoir une des valeurs suivantes :"
    
    for i in ${!suffix[*]}; do
        echo -e "\t\t\t ${suffix[$i]} = ${mesures[$i]}"
    done

    echo -e "\t\tSi aucun argument est donné la valeur par default $default ($default_number ${mesures[$default_sfx]}) est prise en compte\n"

    echo -e "'man sleep' pour plus de details\n"
}

# OPTIONS
verifyOpts()
{
    OPTIND=1 # Reset is necessary if getopts was used previously in the script.  It is a good idea to make this local in a function.
    while getopts ":hvrsb" opt; do
        case $opt in
            h)
                showhelp
                exit 0
                ;;
            v)
                verbose=true
                ;;
            r)
                action="reboot"
                ;;
            s)
                action="shutdown"
                ;;
            b)
                action="hibernate"
                ;;
            \?) 
                echo "Invalid Option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done
}

# fais un echo seulement si $verbose est à true
vecho()
{
    if $verbose; then echo -e "$1"; fi
}

# teste si l'argument $1 est un nombre entier positif
testNumber()
{
    if [[ $1 = +([0-9]) ]]; then
        vecho "$1 est un nombre entier positive"
        return 0
    else
        vecho "$1 n'est pas un nombre entier positive"
        return 1
    fi
}

testSuffix()
{
    local sfx
    for sfx in "${suffix[@]}"; do
        [ "$sfx" = "$1" ] && return 0
    done
    return 1
}

verifyArgs()
{
    # Si le script est appelé sans arguments on execute avec la valeur par default $default
    if [ -z $1 ]; then
        tempo=$default
        echo "La valeur par default $default est prise en compte"
        return 0
    fi

    # Si le premier paramètres n'est pas un nombre entier positif on renvoie une erreur
    testNumber $1
    if [  "$?" != 0 ]; then
        echo "Le premier paramètre doit avoir une valeur numerique positive"
        return 1
    fi

    # Si il y a un seul paramètre on utilise le suffix par default $default_sfx
    if [ $# -eq 1 ]; then
        tempo="$1${suffix[$default_sfx]}"
        echo "La valeur par default ${suffix[$default_sfx]} = ${mesures[$default_sfx]} est prise en compte" 
        return 0
    else
        if [ $# -gt 2 ]; then
            echo "Le nombre d'arguments est $# mais seulement les 2 prèmiers sont pris en compte : $1 et $2"
        fi        

        testSuffix $2
        if [ "$?" != 0 ]; then
            echo "Le suffix $2 n'est pas valide. Le deuxième paramètre doit être une des valeurs suivantes : ${suffix[*]}"
            return 1
        fi

        tempo="$1$2"
        return 0
    fi
}

# extrait number et suffix de tempo ( pour 30m $nmb="30" et $msr="m")
extractArgs()
{
    local prm=$1
    nmb=$(echo $prm | grep -Eo "[[:digit:]]*")
    msr=${prm:(-1)}

    vecho "nmb : $nmb | nmb length : ${#nmb} | sfx : $sfx"
    return 0
}

# Calcule le nombre de seconds à partir d'un nombre et une mesure de temps
calculeSeconds()
{
    let "seconds = $1"

    case $2 in
        s)
            let "seconds = seconds"
            ;;
        m)
            let "seconds *= 60"
            ;;
        h)
            let "seconds *= 60 * 60"
            ;;
        d)
            let "seconds *= 60 * 60 * 24"
            ;;
        \?) 
            echo "Invalid Mesure: $2"
            return 1
            ;;
    esac

    return 0
}

# Affiche le message finale du script
showexitmsg()
{
    echo -e "\n\t L'ordinateur $1 maintenant"
    sleep 0.5
}

# Fait le echo pour showtime
echotime()
{
    clear
    echo -e "\t$seconds seconds avant la fin du script"
}

# Affiche le temps qui s'ecoule
showtime()
{
    extractArgs $1
    calculeSeconds $nmb $msr
    
    while [ $seconds -gt 0 ]; do
        echotime
        sleep 1
        let "seconds -= 1"
    done

    echotime
    return 0
}

# Selon la valeur de $action : met en veille, redemarre, eteint ou hyberne le système
doaction()
{
    echo -e "$action"
    case $action in
        suspend)
            showexitmsg "va être mis en veille"
            dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.Suspend
            ;;
        reboot)
            showexitmsg "va redemarrer"
            dbus-send --system --print-reply --dest="org.freedesktop.ConsoleKit" /org/freedesktop/ConsoleKit/Manager org.freedesktop.ConsoleKit.Manager.Restart
            ;;
        shutdown)
            showexitmsg "va être eteint"
            dbus-send --system --print-reply --dest="org.freedesktop.ConsoleKit" /org/freedesktop/ConsoleKit/Manager org.freedesktop.ConsoleKit.Manager.Stop
            ;;
        hibernate)
            showexitmsg "va être mis en hibernation"
            dbus-send --system --print-reply --dest="org.freedesktop.UPower" /org/freedesktop/UPower org.freedesktop.UPower.Hibernate
            ;;
        \?) 
            echo "Invalid Action: $action"
            return 1
            ;;
    esac
}


##############################
# MOTEUR
#############################

verifyOpts $*
shift "$((OPTIND-1))" # Shift off the options and optional --.

vecho "\$* = $*"
verifyArgs $*
if [ "$?" != 0 ]; then
    showhelp
    exit 1
fi

vecho "tempo = $tempo"
showtime $tempo
doaction

exit 0
