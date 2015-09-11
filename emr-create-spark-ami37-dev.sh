#!/usr/bin/env bash
WORKER_COUNT=2
INSTANCE_TYPE=m3.2xlarge

read SPOT_AVAILABILITY_ZONE CURRENT_SPOT_PRICE <<< $(echo $(aws --output json --region us-east-1 ec2 describe-spot-price-history --instance-type "${INSTANCE_TYPE}" --product-description "Linux/UNIX" --no-paginate --start-time `date +20%y-%m-%dT%H:%M:%SZ` | jq '.SpotPriceHistory[0:] | map(select(.AvailabilityZone!="us-east-1e")) | sort_by(.SpotPrice) | .[0].AvailabilityZone,.[0].SpotPrice'))
SPOT_AVAILABILITY_ZONE="${SPOT_AVAILABILITY_ZONE%\"}" ; SPOT_AVAILABILITY_ZONE="${SPOT_AVAILABILITY_ZONE#\"}"  # strip quotes
CURRENT_SPOT_PRICE="${CURRENT_SPOT_PRICE%\"}" ; CURRENT_SPOT_PRICE="${CURRENT_SPOT_PRICE#\"}"  # strip quotes
BID_PRICE=$(echo 10*$CURRENT_SPOT_PRICE | bc | cut -c1,2,3,4)

aws emr --output "json" --region us-east-1 create-cluster \
--ami-version 3.7 \
--name 'Kostas AMI 3.7 Spark cluster' \
--applications Name=Ganglia \
--tags env="Dev" product="KnowledgeGraph" workflow="ad-hoc" role="mapreduce" \
--service-role EMR_DefaultRole \
--ec2-attributes "InstanceProfile=EMR_EC2_DefaultRole,KeyName=adt-shared-dev,AvailabilityZone=${SPOT_AVAILABILITY_ZONE}" \
--instance-groups \
  Name=MasterGroup,InstanceGroupType=MASTER,InstanceCount=1,InstanceType="${INSTANCE_TYPE}",BidPrice="${BID_PRICE}" \
  Name=WorkerGroup,InstanceGroupType=CORE,InstanceCount="${WORKER_COUNT}",InstanceType="${INSTANCE_TYPE}",BidPrice="${BID_PRICE}" \
--visible-to-all-users \
--no-auto-terminate \
--log-uri "s3://adt-adhoc/kostas/logs/" \
--bootstrap-actions \
  Name=InstallSpark,Path=s3://support.elasticmapreduce/spark/install-spark,Args=["-v","1.4.0.b"] \
  Name=ConfigureSpark,Path=s3://support.elasticmapreduce/spark/configure-spark.bash,Args=["spark.executor.memory=11g","spark.driver.memory=2g","spark.local.dir=/mnt/spark,/mnt1/spark"] \
  Name=StartSpark,Path=s3://support.audiencereport/spark/start-spark-ami-3.7.0.sh \
  Name=SyncExecutorLogs,Path=s3://support.audiencereport/spark/sync-executor-logs.sh,Args=["-l","s3://adt-adhoc/kostas/logs/"]
