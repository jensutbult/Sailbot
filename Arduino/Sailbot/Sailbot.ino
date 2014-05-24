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
  SBTSailbotModelHeaderState = 1,
  SBTSailbotModelHeaderBoatHeading,
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

Servo tillerServo;
Servo sheetServo;

void setup() {
  Serial.begin(SERIAL_PORT_SPEED);
  Wire.begin();
  remoteState = SBTSailbotModelStateManualControl;
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
    if (state == SBTSailbotModelStateCalibratingIMU) {
      char buffer[2];
      buffer[0] = SBTSailbotModelHeaderState;
      buffer[1] = SBTSailbotModelStateCalibratingIMU;
      RFduinoBLE.send((char*)&buffer, 2);
    } else if (state == SBTSailbotModelStateNoIMU) {
      char buffer[2];
      buffer[0] = SBTSailbotModelHeaderState;
      buffer[1] = SBTSailbotModelStateNoIMU;
      RFduinoBLE.send((char*)&buffer, 2);
    } else {
      const RTVector3& vec = fusion.getFusionPose();
      char buffer[10];
      buffer[0] = SBTSailbotModelHeaderBoatHeading;
      buffer[1] = state;
      float heading = vec.z();
      memcpy(&buffer[2], &heading, sizeof(heading));
      RFduinoBLE.send((char*)&buffer, sizeof(float) + 2);
    }
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
        Serial.print("Selected heading "); Serial.println(heading);
        break;
      }
    case SBTSailbotModelHeaderManualControl: {
        remoteState = SBTSailbotModelStateManualControl;
        int rudder;
        memcpy(&rudder, &data[1], sizeof(rudder));
        int sheet;
        memcpy(&sheet, &data[1 + 4], sizeof(sheet));
        tillerServo.write(((rudder / 10.0) + M_PI / 2.0) * 180.0 / M_PI);
        sheetServo.write((sheet / 10.0) * 60 + 90);
        Serial.print("Manual Control "); Serial.println(rudder);
        break;
      }
    default:
      break;
  }
}

