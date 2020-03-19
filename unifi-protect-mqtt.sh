#!/bin/bash

# Unifi Video Vars
UNIFI_MOTION_LOG=/srv/unifi-protect/logs/events.cameras.log

# MQTT Vars
MQTT_SERVER="10.0.1.X"
MQTT_PORT="1883"
MQTT_TOPIC_BASE="homeassistant"

AUTODISCOVERY_COMPONENT="binary_sensor"
AUTODISCOVERY_NODE_ID="camera_motion"

MQTT_ON_PAYLOAD="ON"
MQTT_OFF_PAYLOAD="OFF"

# MQTT User/Pass Vars, only use if needed
#MQTT_USER="YOUR_USERNAME"
#MQTT_PASS="YOUR_PASSWORD"
#MQTT_ID="yourid"  ## To make it work with hassio

PREVIOUS_MESSAGE=""

# --------------------------------------------------------------------------------
# Script starts here

# Check if a username/password is defined and if so create the vars to pass to the cli
if [[ -n "$MQTT_USER" && -n "$MQTT_PASS" ]]; then
  MQTT_USER_PASS="-u $MQTT_USER -P $MQTT_PASS"
else
  MQTT_USER_PASS=""
fi

# Check if a MQTT_ID has been defined, needed for newer versions of Home Assistant
if [[ -n "$MQTT_ID" ]]; then
  MQTT_ID_OPT="-I $MQTT_ID"
else
  MQTT_ID_OPT=""
fi

# Set up binary sensor auto-discovery
CAM_NAMES=`grep "verbose: motion." /srv/unifi-protect/logs/events.cameras.log | awk -F 'verbose: motion.' '{print $2}' | awk -F '[' '{print $1}' | cut -d ' ' -f2- | sort -u | sed -r 's/[^a-zA-Z0-9\-]+/_/g' | sed -r 's/[^a-zA-Z0-9]$//g' | sed s/" "/_/g | tr '[:upper:]' '[:lower:]' | sort -u`

for CAM_NAME in $CAM_NAMES
do
    echo "Setting up auto-discovery configuration for $CAM_NAME"
    CONFIG_TOPIC=$MQTT_TOPIC_BASE/$AUTODISCOVERY_COMPONENT/$AUTODISCOVERY_NODE_ID/$CAM_NAME/config
    STATE_TOPIC=$MQTT_TOPIC_BASE/$AUTODISCOVERY_COMPONENT/$AUTODISCOVERY_NODE_ID/$CAM_NAME/state
    CONFIG_PAYLOAD="{\"name\":\"${CAM_NAME}_${AUTODISCOVERY_NODE_ID}\",\"device_class\":\"motion\",\"state_topic\":\"${STATE_TOPIC}\"}"

    mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT $MQTT_USER_PASS -r $MQTT_ID_OPT -t $CONFIG_TOPIC -m "$CONFIG_PAYLOAD" &
done

# Capture motion from the log file
while inotifywait -e modify $UNIFI_MOTION_LOG; do
    LAST_MESSAGE=`grep "verbose: motion." $UNIFI_MOTION_LOG | tail -n1 `

    if [[ "$PREVIOUS_MESSAGE" == "$LAST_MESSAGE" ]]; then
        echo " same skipping: $PREVIOUS_MESSAGE"
    else
        echo "PREVIOUS_MESSAGE: $PREVIOUS_MESSAGE"
        echo "LAST_MESSAGE: $LAST_MESSAGE"

        PREVIOUS_MESSAGE="$LAST_MESSAGE"

        LAST_CAM=`echo $LAST_MESSAGE | awk -F 'verbose: motion.' '{print $2}' | awk -F '[' '{print $1}' | cut -d ' ' -f2- | xargs | sed s/" "/_/g |  tr '[:upper:]' '[:lower:]' | sed -r 's/[^a-zA-Z0-9\-]+/_/g'`
        LAST_EVENT=`echo $LAST_MESSAGE | awk -F 'verbose: motion.' '{print $2}' | awk -F ' ' '{print $1}'`
        STATE_TOPIC=$MQTT_TOPIC_BASE/$AUTODISCOVERY_COMPONENT/$AUTODISCOVERY_NODE_ID/$LAST_CAM/state

        if [[ $LAST_EVENT == "start" ]]; then
            echo " * Motion started on $LAST_CAM"
            # mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT $MQTT_USER_PASS -r $MQTT_ID_OPT -t $MQTT_TOPIC_BASE/$LAST_CAM -m "$MQTT_ON_PAYLOAD" &
            mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT $MQTT_USER_PASS -r $MQTT_ID_OPT -t $STATE_TOPIC -m "$MQTT_ON_PAYLOAD" &
        else
            echo " * Motion stopped on $LAST_CAM"
            # mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT $MQTT_USER_PASS -r $MQTT_ID_OPT -t $MQTT_TOPIC_BASE/$LAST_CAM -m "$MQTT_OFF_PAYLOAD" &
            mosquitto_pub -h $MQTT_SERVER -p $MQTT_PORT $MQTT_USER_PASS -r $MQTT_ID_OPT -t $STATE_TOPIC -m "$MQTT_OFF_PAYLOAD" &
        fi
    fi
done
