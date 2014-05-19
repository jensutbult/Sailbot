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
  SBTSailbotModelHeaderBoatHeading = 1,
  SBTSailbotModelHeaderAutomaticControl,
  SBTSailbotModelHeaderManualControl,
  SBTSailbotModelHeaderConfiguration,
  SBTSailbotModelHeaderWindDirection,
};

#define DATA_PACKET_SEND_INTERVAL  250
#define  SERIAL_PORT_SPEED  9600

unsigned long lastDataPacketSent;

Servo tillerServo;
Servo sheetServo;

void setup() {
  Serial.begin(SERIAL_PORT_SPEED);
  Wire.begin();
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
    fusion.newIMUData(imu->getGyro(), imu->getAccel(), imu->getCompass(), imu->getTimestamp());
    if ((now - lastDataPacketSent) >= DATA_PACKET_SEND_INTERVAL) {
      lastDataPacketSent = now;
      if (!imu->IMUGyroBiasValid()) {
        Serial.println("Calculating gyro bias - don't move IMU!");
        return;
      }

      const RTVector3& vec = fusion.getFusionPose();

      char buffer[10];
      buffer[0] = SBTSailbotModelHeaderBoatHeading;
      float heading = vec.z();
      memcpy(&buffer[1], &heading, sizeof(heading));

      RFduinoBLE.send((char*)&buffer, sizeof(float) + 1);
    }
  }
}


void RFduinoBLE_onConnect() {
  Serial.println("Bluetooth connect");
}

void RFduinoBLE_onDisconnect() {
  Serial.println("Bluetooth disconnect");
}

void RFduinoBLE_onReceive(char *data, int len) {

  SBTSailbotModelHeader command = (SBTSailbotModelHeader)data[0];

  switch (command) {
    case SBTSailbotModelHeaderAutomaticControl: {
        float heading;
        memcpy(&heading, &data[1], sizeof(heading));
        Serial.print("Selected heading "); Serial.println(heading);
        break;
      }
    case SBTSailbotModelHeaderManualControl: {
        int rudder;
        memcpy(&rudder, &data[1], sizeof(rudder));
        int sheet;
        memcpy(&sheet, &data[1 + 4], sizeof(sheet));
        tillerServo.write(((rudder / 10.0) + M_PI / 2.0) * 180.0 / M_PI);
        sheetServo.write((sheet / 10.0) * 60 + 90);
        break;
      }
    default:
      break;
  }
}

