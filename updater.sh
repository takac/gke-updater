#!/bin/bash
set -eu

# set -x

PROJECT_NAME=${1:-$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" -H "Metadata-Flavor: Google")}
CLUSTER=${2:-$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/cluster-name" -H "Metadata-Flavor: Google")}

# gcloud config set project $PROJECT_NAME

echo "$(date): Welcome to k8s updater! Target Project: $PROJECT_NAME, Cluster: $CLUSTER"

ZONE=$(gcloud --format 'value(zone)' container clusters list --filter 'name='$CLUSTER)
ZONE_CONFIG=$(gcloud --format 'value[](validMasterVersions, defaultClusterVersion)' container get-server-config --zone "$ZONE" 2> /dev/null)

TOP_ZONE_VERSION=$(awk 'BEGIN{RS="\t"; FS=";"} NR == 1{ print $1 }' <<< "$ZONE_CONFIG")
DEFAULT_ZONE_VERSION=$(awk 'BEGIN{RS="\t"; FS=";"} NR==2{ print $1 }' <<< "$ZONE_CONFIG")


CLUSTER_CONFIG=$(gcloud --format 'value[](currentMasterVersion, currentNodeVersion)' container clusters describe --zone $ZONE "$CLUSTER")
MASTER_VERSION=$(awk 'BEGIN{ RS="\t" } NR==1{ print $0 }' <<< "$CLUSTER_CONFIG")
NODE_VERSION=$(awk 'BEGIN{ RS="\t" } NR == 2 { print $0 }' <<< "$CLUSTER_CONFIG")

MASTER_BEHIND=$(awk 'BEGIN{RS="\t"} NR == 1{ gsub(";", "\n", $0); print $0 }' <<< "$ZONE_CONFIG" | awk '/'$MASTER_VERSION'/{print NR-1}' )
DEFAULT_VERSION_RANK=$(awk 'BEGIN{RS="\t"} NR == 1{ gsub(";", "\n", $0); print $0 }' <<< "$ZONE_CONFIG" | awk '/'$DEFAULT_ZONE_VERSION'/{print NR-1}')


echo "Cluster Node version: $NODE_VERSION"
echo "Cluster Master version: $MASTER_VERSION"
echo
echo "Top zone version: $TOP_ZONE_VERSION"
echo "Default zone version: $DEFAULT_ZONE_VERSION"
echo
echo "Cluster version rank: $MASTER_BEHIND"
echo "Default version rank: $DEFAULT_VERSION_RANK"
echo

if [[ "${MASTER_BEHIND}" < "${DEFAULT_VERSION_RANK}" ]]; then
    echo "Already on latest! Good job."
else
    echo "Upgrading masters"
    gcloud container clusters upgrade $CLUSTER -q --master --zone=$ZONE

    echo "Upgrading nodes"
    gcloud container clusters upgrade $CLUSTER -q --zone=$ZONE
fi
