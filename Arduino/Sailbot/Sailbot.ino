#include <Wire.h>
#include "I2Cdev.h"
#include "RTIMUSettings.h"
#include "RTIMU.h"
#include "RTFusionRTQF.h"
#include "CalLib.h"
#include <RFduinoBLE.h>
#include <Servo.h>

RTIMU *imu;                                           // the IMU object
RTFusionRTQF fusion;                                  // the fusion object
RTIMUSettings settings;                               // the settings object

enum SBTSailbotModelHeader {
  SBTSailbotModelHeaderBoatState = 1,
  SBTSailbotModelHeaderAutomaticControl,
  SBTSailbotModelHeaderManualControl,
  SBTSailbotModelHeaderConfiguration,
  SBTSailbotModelHeaderWindDirection,
};

enum SBTSailbotModelState {
  SBTSailbotModelStateConnected = 1,
  SBTSailbotModelStateDisconnected,
  SBTSailbotModelStateCalibratingIMU,
  SBTSailbotModelStateNoIMU,
  SBTSailbotModelStateWindNotCalibrated,
  SBTSailbotModelStateManualControl,
  SBTSailbotModelStateAutomaticControl,
  SBTSailbotModelStateRecoveryMode,
};

#define DATA_PACKET_SEND_INTERVAL  500
#define  SERIAL_PORT_SPEED  9600

unsigned long lastDataPacketSent;

char state;
char remoteState;
int failedIMUReadCount;
bool calibratedWind;
float windDirection;
float heading;
float rudder;
float sheet;
float compassOffset;

Servo tillerServo;
Servo sheetServo;

void setup() {
  Serial.begin(SERIAL_PORT_SPEED);
  Wire.begin();
  remoteState = SBTSailbotModelStateManualControl;
  windDirection = -1.0;
  compassOffset = M_PI;
  calibratedWind = false;
  imu = RTIMU::createIMU(&settings);                        // create the imu object

  Serial.print("ArduinoIMU starting using device ");
  Serial.println(imu->IMUName());
  int errcode;
  if ((errcode = imu->IMUInit()) < 0) {
    Serial.print("Failed to init IMU: "); Serial.println(errcode);
  }

  if (imu->getCalibrationValid())
    Serial.println("Using compass calibration");
  else
    Serial.println("No valid compass calibration data");

  tillerServo.attach(2);
  sheetServo.attach(3);

  RFduinoBLE.advertisementInterval = 675;
  RFduinoBLE.advertisementData = "Sailbot";
  RFduinoBLE.begin();

  lastDataPacketSent = millis();
}

void loop() {
  unsigned long now = millis();

  if (imu->IMURead()) {
    failedIMUReadCount = 0;
    fusion.newIMUData(imu->getGyro(), imu->getAccel(), imu->getCompass(), imu->getTimestamp());

    // Determine local state
    if (!imu->IMUGyroBiasValid()) {
      state = SBTSailbotModelStateCalibratingIMU;
    } else if (!calibratedWind) {
      state = SBTSailbotModelStateWindNotCalibrated;
    } else {
      state = remoteState;
    }

    // Update rudder and sheet
    if (state == SBTSailbotModelStateAutomaticControl) {

    } else if (state == SBTSailbotModelStateRecoveryMode) {

    }
  } else {
    failedIMUReadCount++;
    if (failedIMUReadCount > 50) {
      state = SBTSailbotModelStateNoIMU;
    }
  }

  // Communicate with remote
  if ((now - lastDataPacketSent) >= DATA_PACKET_SEND_INTERVAL) {
    lastDataPacketSent = now;
    if (state != SBTSailbotModelStateCalibratingIMU && state != SBTSailbotModelStateNoIMU) {
      const RTVector3& vec = fusion.getFusionPose();
      float rawHeading = vec.z();
      // Convert range to 0 to 2 * M_PI
      if (rawHeading < 0)
        heading = rawHeading + 2 * M_PI;
      else
        heading = rawHeading;
      // Apply compass offset
      if (heading > compassOffset)
        heading -= compassOffset;
      else
        heading += compassOffset;
    }
    char buffer[10];
    buffer[0] = SBTSailbotModelHeaderBoatState;
    buffer[1] = state;
    memcpy(&buffer[2], &heading, sizeof(heading));
    memcpy(&buffer[6], &windDirection, sizeof(heading));
    memcpy(&buffer[10], &rudder, sizeof(rudder));
    memcpy(&buffer[14], &sheet, sizeof(sheet));

    RFduinoBLE.send((char*)&buffer, 2 + 4 * sizeof(float));
    Serial.print("Heading: "); Serial.print(heading);
    Serial.print(" Wind direction: "); Serial.println(windDirection);
  }
}

void RFduinoBLE_onConnect() {
  Serial.println("Bluetooth connect");
}

void RFduinoBLE_onDisconnect() {
  Serial.println("Bluetooth disconnect");
}

void RFduinoBLE_onReceive(char * data, int len) {

  SBTSailbotModelHeader command = (SBTSailbotModelHeader)data[0];

  switch (command) {
    case SBTSailbotModelHeaderAutomaticControl: {
        remoteState = SBTSailbotModelStateAutomaticControl;
        int heading;
        memcpy(&heading, &data[1], sizeof(heading));
        Serial.print("Automatic heading: "); Serial.println(heading);
        break;
      }
    case SBTSailbotModelHeaderManualControl: {
        remoteState = SBTSailbotModelStateManualControl;

        int remoteRudder;
        memcpy(&remoteRudder, &data[1], sizeof(remoteRudder));
        rudder = (float)remoteRudder;

        int remoteSheet;
        memcpy(&remoteSheet, &data[1 + 4], sizeof(remoteSheet));
        sheet = (float)remoteSheet;

        tillerServo.write(((rudder / 10.0) + M_PI / 2.0) * 180.0 / M_PI);
        sheetServo.write((sheet / 10.0) * 60 + 90);
        Serial.print("Manual control: "); Serial.println(rudder);
        break;
      }
    case SBTSailbotModelHeaderWindDirection: {
        int newWindDirection;
        memcpy(&newWindDirection, &data[1], sizeof(newWindDirection));
        if (newWindDirection < 0) {
          windDirection = heading;
        } else {
          windDirection = (float)newWindDirection;
        }
        calibratedWind = true;
        state = SBTSailbotModelStateManualControl;
        Serial.print("Set wind direction: "); Serial.println(newWindDirection);
      }
    default:
      break;
  }
}

