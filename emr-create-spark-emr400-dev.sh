#!/usr/bin/env bash

if [ "$#" -ne 2 ]; then
    echo "usage: create-emr400-spark.sh <worker count> <instance type>"
    exit
fi

WORKER_COUNT=$1
INSTANCE_TYPE=$2

read SPOT_AVAILABILITY_ZONE CURRENT_SPOT_PRICE <<< $(echo $(aws --output json --region us-east-1 ec2 describe-spot-price-history --instance-type "${INSTANCE_TYPE}" --product-description "Linux/UNIX" --no-paginate --start-time `date +20%y-%m-%dT%H:%M:%SZ` | jq '.SpotPriceHistory[0:] | map(select(.AvailabilityZone!="us-east-1e")) | sort_by(.SpotPrice) | .[0].AvailabilityZone,.[0].SpotPrice'))
SPOT_AVAILABILITY_ZONE="${SPOT_AVAILABILITY_ZONE%\"}" ; SPOT_AVAILABILITY_ZONE="${SPOT_AVAILABILITY_ZONE#\"}"  # strip quotes
CURRENT_SPOT_PRICE="${CURRENT_SPOT_PRICE%\"}" ; CURRENT_SPOT_PRICE="${CURRENT_SPOT_PRICE#\"}"  # strip quotes
BID_PRICE=$(echo 10*$CURRENT_SPOT_PRICE | bc | cut -c1,2,3,4)

aws emr --output "json" --region us-east-1 create-cluster \
--release-label emr-4.0.0 \
--name 'Kostas EMR 4.0.0 Spark cluster' \
--applications Name=Spark \
--configurations file://spark-config-emr400.json \
--tags env="Dev" product="KnowledgeGraph" workflow="ad-hoc" role="mapreduce" \
--service-role EMR_DefaultRole \
--ec2-attributes "InstanceProfile=EMR_EC2_DefaultRole,KeyName=adt-shared-dev,AvailabilityZone=${SPOT_AVAILABILITY_ZONE}" \
--instance-groups \
Name=MasterGroup,InstanceGroupType=MASTER,InstanceCount=1,InstanceType="${INSTANCE_TYPE}",BidPrice="${BID_PRICE}" \
Name=WorkerGroup,InstanceGroupType=CORE,InstanceCount="${WORKER_COUNT}",InstanceType="${INSTANCE_TYPE}",BidPrice="${BID_PRICE}" \
--visible-to-all-users \
--no-auto-terminate \
--log-uri s3://adt-adhoc/kostas/logs/
