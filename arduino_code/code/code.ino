#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

#define SERVICE_UUID        "6d616465-6279-746f-7274-696b39323c33"
#define CHARACTERISTIC_UUID "63616b65-6c61-6268-6172-647761726521"

#define DEVICE_NAME         "Death Blinker BLE"

BLEServer *pServer;
BLEService *pService;
BLECharacteristic *pCharacteristic;

void setup() {
  Serial.begin(9600);
  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_READ |
                                         BLECharacteristic::PROPERTY_WRITE
                                       );
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

}

uint8_t previousData[5] = {0}; // Adjust size based on maximum data length
bool isFirstRun = true;

void loop() {
  uint8_t* currentData = pCharacteristic->getData();
  int length = pCharacteristic->getLength(); // Assuming this gives the length of data

  if (currentData != nullptr && length > 0) {
    // Compare current data with the previous data
    if (isFirstRun || memcmp(previousData, currentData, length) != 0) {
      Serial.print("New Message: ");
      for (int i = 0; i < length; i++) {
        Serial.print(currentData[i], HEX);
        Serial.print(" ");
      }
      Serial.println();

      // Update the previous data buffer
      memcpy(previousData, currentData, length);
      isFirstRun = false; // Mark that the first run has been processed
    } else {
      Serial.println("Old Message: No change detected");
    }
  } else {
    Serial.println("No data available");
  }

  delay(1000); // Optional delay

}
