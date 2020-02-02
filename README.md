# unifi-protect-mqtt

# Deprecated

I highly recommend using this instead, it doesn't involve messing with your gateway at all:
<https://github.com/terafin/mqtt-unifi-protect-bridge>

# Introduction

Thanks to: mzac, for the unifi video version of this here: https://github.com/mzac/unifi-video-mqtt

This script can run on your Unifi Protect server and push MQTT messages to a broker when motion is detected.

This can be useful for systems like Homeassistant that are lacking motion detection integration with Unifi Protect.

# Reference
Unifi Protect writes to */srv/unifi-protect/logs/events.cameras.log* and it ouputs logs like this.  This script parses this log:
```
2019-01-11T15:35:36.653Z - verbose: motion.start Main [802AA84EXXXX @ 10.0.1.X] 1547220936627
2019-01-11T15:35:43.117Z - verbose: motion.stop Main [802AA84EXXXX @ 10.0.1.X] 1547220945050
{ clockBestMonotonic: 42814557,
  clockBestWall: 1547220936734,
  clockMonotonic: 42827321,
  clockWall: 1547220943050,
  edgeType: 'stop',
  eventId: 12,
  eventType: 'motion',
  levels: { '1': 25 },
  motionHeatmap: 'heatmap_00000012.png',
  motionSnapshot: 'motionsnap_00000012.jpg' }
```

# Requirements
* Unifi CloudKey G2+
* MQTT Client
* MQTT Server
* Inotify Tools

# Installation

The installation should be done on your Cloud Key G2

```
apt update
apt install -y inotify-tools mosquitto-clients git
cd /tmp
git clone https://github.com/terafin/unifi-video-mqtt.git /tmp/unifi-protect-mqtt
cd /tmp/unifi-protect-mqtt
cp unifi-protect-mqtt.sh /usr/local/bin
chmod a+x /usr/local/bin/unifi-protect-mqtt.sh
cp unifi-protect-mqtt.service /etc/systemd/system
systemctl daemon-reload
systemctl enable unifi-protect-mqtt
```

# IMPORTANT!!!
Before starting the service, make sure to edit */usr/local/bin/unifi-protect-mqtt.sh* with your specific
settings:

```
# MQTT Vars
MQTT_SERVER="192.168.x.x"
MQTT_PORT="1883"
MQTT_TOPIC_BASE="/camera/motion"

MQTT_ON_PAYLOAD="ON"
MQTT_OFF_PAYLOAD="OFF"

# MQTT User/Pass Vars, only use if needed
#MQTT_USER="username"
#MQTT_PASS="password"
#MQTT_ID="yourid"  ## To make it work with hassio

```

Test it to make sure it works:
```
bash /usr/local/bin/unifi-protect-mqtt.sh
```

Create some motion on your camera and subscribe to your MQTT server and see if you see motion:

```
root@pi3:~# mosquitto_sub -h 192.168.x.x -t "camera/motion/#" -v
/camera/motion/front_door on
/camera/motion/front_door off
```

Once all changes are done, go ahead and start the daemon
```
systemctl start unifi-protect-mqtt
```
