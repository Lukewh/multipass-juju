#!/bin/bash

function cecho() {
    text="${1}"
    color="${2}"

    green='\033[0;32m'

    echo -e "${green}${text}\033[0m"
}

function step1() {
    cecho "---------------------------------------------"
    cecho "1. Launch juju multipass instance"
    cecho "---------------------------------------------"

    name=$1

    # Mount the current directory to /home/ubuntu/host
    multipass launch -c 2 -d 15G -m 8G --name $name --mount ${PWD}:/home/ubuntu/host jammy
}

function step2() {
    cecho "---------------------------------------------"
    cecho "2. ssh-keygen"
    cecho "---------------------------------------------"
    name=$1
    multipass exec $name -- ssh-keygen
}

function step3() {
    cecho "---------------------------------------------"
    cecho "3. Initialize LXD"
    cecho "---------------------------------------------"
    name=$1
    multipass exec $name -- lxd init --auto
    multipass exec $name -- lxc network set lxdbr0 ipv6.address none
}

function step4() {
    cecho "---------------------------------------------"
    cecho "4. Set up Juju Snap"
    cecho "---------------------------------------------"
    name=$1
    channel=$2
    arm64=$3
    multipass exec $name -- sudo snap install juju --channel=$channel
    multipass exec $name -- mkdir -p /home/ubuntu/.local/share
    if [[ $arm64 -eq 1 ]]; then
        multipass exec $name -- juju bootstrap
    else
        multipass exec $name -- juju bootstrap
    fi
    echo
    cecho "> Changing admin password, you will use this to login <"
    multipass exec $name -- juju change-user-password admin
}

function step5() {
    cecho "---------------------------------------------"
    cecho "5. Set up the dashboard"
    cecho "---------------------------------------------"
    name=$1
    multipass exec $name -- juju switch controller
    multipass exec $name -- juju deploy juju-dashboard
    multipass exec $name -- juju expose juju-dashboard
    multipass exec $name -- juju relate juju-dashboard controller

    echo "Waiting for the dashboard to be ready..."
    interval=10

    waiting="waiting"

    until [[ $waiting = "" ]]; do
        output=$(multipass exec juju -- juju status)
        lines=(${output//$'\n'/ })

        waiting=$(echo "${lines[@]}" | grep -Eo 'waiting|maintenance')
        sleep $interval
    done
}

function step6() {
    cecho "---------------------------------------------"
    cecho "6. Set up port forwarding"
    cecho "---------------------------------------------"
    name=$1
    output=$(multipass exec juju -- lxc ls)
    lines=(${output//$'\n'/ })

    # Find the first line that contains an IPv4 IP address
    machines=$(echo "${lines[@]}" | grep -Eo 'juju(-[a-zA-Z0-9]*-[a-zA-Z0-9]*)')

    machine_names=(${machines//$'\n'/ })

    multipass exec $name -- lxc config device add "${machine_names[0]}" portforward17070 proxy listen=tcp:0.0.0.0:17070 connect=tcp:127.0.0.1:17070
    multipass exec $name -- lxc config device add "${machine_names[1]}" portforward8080 proxy listen=tcp:0.0.0.0:8080 connect=tcp:127.0.0.1:8080
}

function step7() {
    cecho "---------------------------------------------"
    cecho "7. Deploy postgresql"
    cecho "---------------------------------------------"
    name=$1
    arm64=$2
    multipass exec $name -- juju add-model test
    if [[ $arm64 -eq 1 ]]; then
        multipass exec $name -- juju deploy postgresql --constraints="arch=arm64"
    else
        multipass exec $name -- juju deploy postgresql
    fi
}

function step8() {
    cecho "---------------------------------------------"
    cecho "8. Finished"
    cecho "---------------------------------------------"
    name=$1
    output=$(multipass info $name)
    lines=(${output//$'\n'/ })

    re='IPv4:\s*([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)'
    [[ "${lines[@]}" =~ $re ]]

    ip_address="${BASH_REMATCH[1]}"

    multipass exec $name -- juju switch controller

    echo "Visit: https://${ip_address}:17070 to accept the certificate."
    echo ""
    echo "If you are running the dashboard locally update config.local.js with the following:"
    echo -e "\tcontrollerAPIEndpoint: \"wss://${ip_address}:17070\""
    echo ""
    echo "When the dashboard is ready it will be available at: http://${ip_address}:8080"
}

function installAndRunDotRun() {
    name=$1

    has_dotrun=$(multipass exec $name -- [ -f /home/ubuntu/.local/bin/dotrun ] && echo 1 || echo 0)

    if [[ has_dotrun -eq 0 ]]; then
        cecho "Installing: python3-pip, dotrun and docker."
        multipass exec $name -- sudo apt update
        multipass exec $name -- sudo apt install python3-pip -y
        multipass exec $name -- pip3 install dotrun
        multipass exec $name -- sudo snap install docker
        multipass exec $name -- sudo addgroup --system docker
        multipass exec $name -- sudo adduser ubuntu docker
        multipass exec $name -- newgrp docker
        exit
        multipass exec $name -- sudo snap disable docker
        multipass exec $name -- sudo snap enable docker
        cecho "Done!"
    fi

    cecho "Running dotrun"
    multipass exec $name --working-directory /home/ubuntu/host -- /home/ubuntu/.local/bin/dotrun
}

function setup() {
    echo
    name=$1
    channel=$2
    arm64=$3
    dotrun=$4
    step1 $name
    step2 $name
    step3 $name
    step4 $name $channel $arm64
    step5 $name
    step6 $name
    step7 $name $arm64
    step8 $name
}

help() {
    # Display Help
    echo "Launch a Juju Multipass instance."
    echo
    echo "Syntax: ./multipass.sh [-h|n|c|d]"
    echo "options:"
    echo "-h     Show this help."
    echo "-n     Name of the multipass instance. [default: juju]"
    echo "-c     Juju Channel. [default: latest/beta]"
    echo "-d     Dev - install and run dotrun. EXPERIMENTAL - NOT RECOMMENDED"
    echo ""
}

function yes_or_no {
    while true; do
        read -p "$* [y/n]: " yn
        case $yn in
            [Yy]*) return 0  ;;
            [Nn]*) echo "Aborted" ; return  1 ;;
        esac
    done
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

# Set variables
name="juju"
channel="latest/beta"
arm64=0

if [[ "$(uname -m)" == "arm64" ]]; then
    arm64=1
fi

dotrun=0

############################################################
# Process the input options. Add options as needed.        #
############################################################
# Get the options
while getopts ":hn:c:d" option; do
    case $option in
        h) # display help
            help
            exit;;
        c) # channel
            channel=$OPTARG;;
        n) # Enter a name
            name=$OPTARG;;
        d) # dotrun
            dotrun=1;;
        \?) # Invalid option
            echo "Error: Invalid option"
            exit;;
    esac
done

function main() {
    name=$1
    channel=$2
    arm64=$3
    dotrun=$4

    multipass_instance=$(multipass info $name && echo 1 || echo 0)

    if [[ $multipass_instance -eq 0  ]]; then
        cecho "Creating instance"
        setup $name $channel $arm64
    fi

    if [[ $dotrun -eq 1 ]]; then
        installAndRunDotRun $name
    fi
}

cecho "#############################################"
cecho "#         Multipass Juju Dashboard          #"
cecho "#############################################"
echo

cecho "\tInstance Name: ${name}"
cecho "\tJuju Channel: ${channel}"
if [[ $arm64 -eq 1 ]]; then
    cecho "\tARM64: Yes"
else
    cecho "\tARM64: No"
fi
cecho "\tMount: $(pwd):/home/ubuntu/host"
if [[ $dotrun -eq 1 ]]; then
    cecho "\tDotrun: Yes"
else
    cecho "\tDotrun: No"
fi
echo
yes_or_no "Does this look correct?" && main $name $channel $arm64

