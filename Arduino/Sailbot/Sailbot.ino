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

#define MAX_RUDDER 10.0

unsigned long lastDataPacketSent;
unsigned long timeOnTackSequence;
unsigned long lastAutomaticUpdate;

char state;
char remoteState;
int failedIMUReadCount;
bool calibratedWind;
float windDirection;
float heading;
float automaticHeading;
float rudder;
float sheet;
float tackAngle;
unsigned long tackTime;

Servo tillerServo;
Servo sheetServo;

void setup() {
  Serial.begin(SERIAL_PORT_SPEED);
  Wire.begin();
  remoteState = SBTSailbotModelStateManualControl;
  windDirection = -1.0;
  tackAngle = 90.0 * M_PI / 180.0;
  tackTime = 20.0 * 1000.0; // 20 seconds
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
  lastAutomaticUpdate = millis();
}

void setRudder(float newAngle) {
  if (newAngle < 0 && newAngle < -MAX_RUDDER) {
    newAngle = -MAX_RUDDER;
  } else if (newAngle > 0 && newAngle > MAX_RUDDER) {
    newAngle = MAX_RUDDER;
  }
  rudder = newAngle;

  tillerServo.write(((rudder / MAX_RUDDER) + M_PI / 2.0) * 180.0 / M_PI);
}

void loop() {
  while (RFduinoBLE.radioActive)
    ;

  unsigned long now = millis();

  if (imu->IMURead()) {
    failedIMUReadCount = 0;
    fusion.newIMUData(imu->getGyro(), imu->getAccel(), imu->getCompass(), imu->getTimestamp());

    // Determine local state
    if (!imu->IMUGyroBiasValid()) {
      state = SBTSailbotModelStateCalibratingIMU;
    } else if (!calibratedWind) {
      state = SBTSailbotModelStateWindNotCalibrated;
    } else if (state != SBTSailbotModelStateRecoveryMode) {
      state = remoteState;
    }

    // Update rudder and sheet
    if (state == SBTSailbotModelStateAutomaticControl) {
      timeOnTackSequence += now - lastAutomaticUpdate;
      if (timeOnTackSequence > tackTime * 2)
        timeOnTackSequence = 0;
      float rudderAngle;
      float angleToWind = angleSubtractf(windDirection, automaticHeading);
      if (abs(angleToWind) < tackAngle / 2.0) {
        float tack = angleToWind > 0 ? tackAngle / 2.0 : -tackAngle / 2.0;
        if (timeOnTackSequence > tackTime)
          tack = -tack;
        rudderAngle = angleSubtractf(angleSubtractf(windDirection, tack), heading);
      } else {
        rudderAngle = angleSubtractf(automaticHeading, heading);
      }
      lastAutomaticUpdate = now;
      setRudder(40.0 * rudderAngle / M_PI);

    } else if (state == SBTSailbotModelStateRecoveryMode) {

    }
  } else {
    Serial.print("Failed IMU: ");
    Serial.println(imu->IMUName());
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
    }
    char buffer[18];
    buffer[0] = SBTSailbotModelHeaderBoatState;
    buffer[1] = state;
    memcpy(&buffer[2], &heading, sizeof(heading));
    memcpy(&buffer[6], &windDirection, sizeof(windDirection));
    memcpy(&buffer[10], &rudder, sizeof(rudder));
    memcpy(&buffer[14], &sheet, sizeof(sheet));

    RFduinoBLE.send((char*)&buffer, 2 + 4 * sizeof(float));
    Serial.print("heading: "); Serial.print(heading);
    Serial.print(" automaticHeading: "); Serial.print(automaticHeading);
    Serial.print(" windDirection: "); Serial.print(windDirection);
    Serial.print(" rudder: "); Serial.print(rudder);
    Serial.print(" sheet: "); Serial.print(sheet);
    Serial.print(" timeOnTackSequence: "); Serial.print(timeOnTackSequence);
    Serial.print(" tackTime: "); Serial.println(tackTime);
  }
}

void RFduinoBLE_onConnect() {
  state = SBTSailbotModelStateConnected;
  Serial.println("Bluetooth connect");
}

void RFduinoBLE_onDisconnect() {
  state = SBTSailbotModelStateRecoveryMode;
  Serial.println("Bluetooth disconnect");
}

void RFduinoBLE_onReceive(char * data, int len) {

  SBTSailbotModelHeader command = (SBTSailbotModelHeader)data[0];

  switch (command) {
    case SBTSailbotModelHeaderAutomaticControl: {
        remoteState = SBTSailbotModelStateAutomaticControl;
        int newHeading;
        timeOnTackSequence = 0; // reset time on current tack
        lastAutomaticUpdate = millis();
        memcpy(&newHeading, &data[1], sizeof(newHeading));
        automaticHeading = ((float)newHeading) * M_PI / 180.0;
        Serial.print("Automatic heading: "); Serial.println(automaticHeading);
        break;
      }
    case SBTSailbotModelHeaderManualControl: {
        remoteState = SBTSailbotModelStateManualControl;

        int remoteRudder;
        memcpy(&remoteRudder, &data[1], sizeof(remoteRudder));
        rudder = (float)remoteRudder;
        setRudder(rudder);

        int remoteSheet;
        memcpy(&remoteSheet, &data[1 + 4], sizeof(remoteSheet));
        sheet = (float)remoteSheet;

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
          windDirection = ((float)newWindDirection)  * M_PI / 180.0;
        }
        calibratedWind = true;
        state = SBTSailbotModelStateManualControl;
        Serial.print("Set wind direction: "); Serial.println(newWindDirection);
      }
    default:
      break;
  }
}

float angleSubtractf(float angleOne, float angleTwo) {
  return atan2f(sinf(angleOne - angleTwo), cosf(angleOne - angleTwo));
}

