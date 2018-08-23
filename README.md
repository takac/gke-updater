# Updater

### Running locally

```
export PROJECT_ID=$(gcloud config get-value project -q)
export CLUSTER_NAME=< CLUSTER NAME HERE >
```
Run against your cluster from your local machine, must have `gcloud` installed.


```
./updater.sh $PROJECT_NAME $CLUSTER_NAME
```

### Install into GKE

To run on your cluster you will need to create a service account that has
privileges to read and write to compute resources and read GKE. This only needs
to be run once.

```
export PROJECT_ID="$(gcloud config get-value project -q)"
export GOOGLE_APPLICATION_CREDENTIALS=$PWD/updater-svc-acc.json
export SVC_ACCOUNT=updater-svc-acc

gcloud iam service-accounts create updater-svc-acc
gcloud iam service-accounts keys create updater-svc-acc.json \
    --iam-account updater-svc-acc@$PROJECT_ID.iam.gserviceaccount.com
# TODO Reduce privileges!
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:${SVC_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/owner
```
Create a Kubernetes `secret` from the json svc account.

```
kubectl create secret generic updater-svc-acc-key \
    --from-file=key.json=$GOOGLE_APPLICATION_CREDENTIALS
```

Deploy node killer as a job to the cluster.

```
kubectl create configmap updater.sh --from-file=updater.sh
kubectl apply -f job.yml
```

Delete node killer job and the config map:
```
kubectl delete job updater
kubectl delete configmap updater.sh
```
