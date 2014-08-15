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

#define MANUAL_RESOLUTION 40.0
#define MAX_RUDDER (M_PI/4.0)

// 2 * 42 + 20 = 104
#define SHEET_ARM_LENGTH 42.0
#define SHEET_ARM_TO_EXIT 20.0
#define SHEET_MIN 30.0
#define SHEET_MAX 100.0

unsigned long lastDataPacketSent;
unsigned long timeOnTackSequence;
unsigned long lastAutomaticUpdate;

char state;
char remoteState;
int failedIMUReadCount;
bool calibratedWind;
float windDirection;
float heading;
float heel;
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
  tackAngle = 105.0 * M_PI / 180.0;
  tackTime = 8.0 * 1000.0; // 8 seconds
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
  setRudder(0.0);
  setSheet(1.0);

  RFduinoBLE.advertisementInterval = 675;
  RFduinoBLE.advertisementData = "Sailbot";
  RFduinoBLE.begin();
  RFduinoBLE.txPowerLevel = +4;

  lastDataPacketSent = millis();
  lastAutomaticUpdate = millis();
}

// Rudder is from -1.0 to 1.0
void setRudder(float newRudder) {
  rudder = newRudder;
  // Setting the servo to zero does not work so we add 0.4 radians
  tillerServo.write((-rudder * MAX_RUDDER + MAX_RUDDER + 0.4) * 180.0 / M_PI);
}

// Sheet is from 0.0 to 1.0 where 0 is close hauled
void setSheet(float newSheet) {
  sheet = newSheet;
  float adjustedSheet = (SHEET_MAX - SHEET_MIN) * (1.0 - sheet) + SHEET_MIN;
  sheet = 2.0 * atan(sqrt( (-pow(SHEET_ARM_TO_EXIT, 2.0) + pow(adjustedSheet, 2.0)) / (pow(SHEET_ARM_TO_EXIT, 2.0) + 4.0 * SHEET_ARM_TO_EXIT * SHEET_ARM_LENGTH + 4.0 * pow(SHEET_ARM_LENGTH, 2.0) - pow(adjustedSheet, 2.0)))) * 180.0 / M_PI;
  sheetServo.write(sheet + 10.0);
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
    
    if (state != SBTSailbotModelStateCalibratingIMU && state != SBTSailbotModelStateNoIMU) {
      const RTVector3& vec = fusion.getFusionPose();
      heel = vec.x();
      float rawHeading = vec.z();
      // Convert range to 0 to 2 * M_PI
      if (rawHeading < 0)
        heading = rawHeading + 2 * M_PI;
      else
        heading = rawHeading;
    }

    // Update rudder
    if (state == SBTSailbotModelStateAutomaticControl || state == SBTSailbotModelStateRecoveryMode) {
      timeOnTackSequence += now - lastAutomaticUpdate;
      if (timeOnTackSequence > tackTime * 2)
        timeOnTackSequence = 0;
      float errorAngle;
      float angleToWind = angleSubtractf(windDirection, automaticHeading);
      if (abs(angleToWind) < tackAngle / 2.0) {
        float tack = angleToWind > 0 ? tackAngle / 2.0 : -tackAngle / 2.0;
        if (timeOnTackSequence > tackTime)
          tack = -tack;
        errorAngle = angleSubtractf(angleSubtractf(windDirection, tack), heading);
      } else {
        errorAngle = angleSubtractf(automaticHeading, heading);
      }
      lastAutomaticUpdate = now;
      
      float rudderValue = errorAngle / (M_PI / 8.0); // full rudder at M_PI/8 (cirka 22 degrees)
      rudderValue = constrain(rudderValue, -1.0, 1.0);
      setRudder(rudderValue);
      
      // sheet
      float relativeWind = abs(angleSubtractf(windDirection, automaticHeading));
      float newSheet = (relativeWind - tackAngle / 2.0) / (M_PI - tackAngle / 2.0);
      
      // sheet out if more than 20 degrees heel, max sheet out at 60 degrees is +0.3
      float heelTreshold = deg2rad(20.0);
      if (abs(heel) > heelTreshold) {        
        float sheetOut = normalizeRangef(abs(heel), heelTreshold, deg2rad(60.0));
        newSheet += sheetOut * 0.3;
      }
      newSheet = constrain(newSheet, 0.0, 1.0);
      setSheet(newSheet); // sheet is a value between 0 and 1
    }
  } else {
 //   Serial.print("Failed IMU: ");
 //   Serial.println(imu->IMUName());
    failedIMUReadCount++;
    if (failedIMUReadCount > 50) {
      state = SBTSailbotModelStateNoIMU;
    }
  }

  // Communicate with remote
  if ((now - lastDataPacketSent) >= DATA_PACKET_SEND_INTERVAL) {
    lastDataPacketSent = now;

    char buffer[18];
    buffer[0] = SBTSailbotModelHeaderBoatState;
    buffer[1] = state;
    memcpy(&buffer[2], &heading, sizeof(heading));
    memcpy(&buffer[6], &windDirection, sizeof(windDirection));
    memcpy(&buffer[10], &rudder, sizeof(rudder));
    memcpy(&buffer[14], &sheet, sizeof(sheet));

    RFduinoBLE.send((char*)&buffer, 2 + 4 * sizeof(float));
//    Serial.print("heading: "); Serial.print(heading);
//    Serial.print(" automaticHeading: "); Serial.print(automaticHeading);
//    Serial.print(" windDirection: "); Serial.print(windDirection);
//    Serial.print(" rudder: "); Serial.print(rudder);
//    Serial.print(" sheet: "); Serial.print(sheet);
//    Serial.print(" heel: "); Serial.println(heel);
//    Serial.print(" timeOnTackSequence: "); Serial.print(timeOnTackSequence);
//    Serial.print(" tackTime: "); Serial.println(tackTime);
  }
}

void RFduinoBLE_onConnect() {
  state = SBTSailbotModelStateConnected;
  Serial.println("Bluetooth connect");
}

void RFduinoBLE_onDisconnect() {
  state = SBTSailbotModelStateRecoveryMode;
  timeOnTackSequence = 0; // reset time on current tack
  lastAutomaticUpdate = millis();
  automaticHeading = angleSubtractf(heading, M_PI);
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
//        Serial.print("Automatic heading: "); Serial.println(automaticHeading);
        break;
      }
    case SBTSailbotModelHeaderManualControl: {
        remoteState = SBTSailbotModelStateManualControl;
        // rudder
        int remoteRudder;
        memcpy(&remoteRudder, &data[1], sizeof(remoteRudder));
        setRudder(((float)remoteRudder) / MANUAL_RESOLUTION * 2.0);
        // sheet
        int remoteSheet;
        memcpy(&remoteSheet, &data[1 + 4], sizeof(remoteSheet));
        setSheet(((float)remoteSheet) / MANUAL_RESOLUTION);
        break;
      }
    case SBTSailbotModelHeaderWindDirection: {
        int newWindDirection;
        memcpy(&newWindDirection, &data[1], sizeof(newWindDirection));
        if (newWindDirection < 0) {
          windDirection = heading;
        } else {
          windDirection = ((float)newWindDirection) * M_PI / 180.0;
        }
        calibratedWind = true;
        state = SBTSailbotModelStateManualControl;
//        Serial.print("Set wind direction: "); Serial.println(newWindDirection);
      }
    default:
      break;
  }
}

float angleSubtractf(float angleOne, float angleTwo) {
  return atan2f(sinf(angleOne - angleTwo), cosf(angleOne - angleTwo));
}

float normalizeRangef(float value, float min, float max) {
  return 1.0 - (max - value) / (max - min);
}

float rad2deg(float rad) {
  return rad * 180.0 / M_PI; 
}

float deg2rad(float deg) {
  return deg * M_PI / 180.0; 
}

