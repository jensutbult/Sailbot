Sailbot
=======

The goal of this project is to create an automated sailboat using a RFduino and an iPhone. Communication between
the boat and iPhone is done over Bluetooth BLE. It uses a LSM9DS0 sensor to keep track of its heading and the boats
relation to the current wind direction. The boat does not utilize a wind sensor, instead the current wind direction is
recorded when you start sailing. Wind direction can be changed from the iPhone app if there is a wind shift. There is
also a manual control mode where you can control rudder and sheet as on a normal RC sailboat.

Sensor fusion is done with the excellent library https://github.com/richards-tech/RTIMULib-Arduino

###Current status

This is work in progress. It might never get finished.
