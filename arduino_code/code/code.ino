#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <Adafruit_NeoPixel.h>

#define SERVICE_UUID        "6d616465-6279-746f-7274-696b39323c33"
#define CHARACTERISTIC_UUID "63616b65-6c61-6268-6172-647761726521"

#define DEVICE_NAME         "Death Blinker BLE"
#define LED_PIN             21
#define NUM_LEDS            1

BLEServer *pServer;
BLEService *pService;
BLECharacteristic *pCharacteristic;

// LED Controller
Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

// State variables
bool isDeviceStarted = false;
uint8_t nLminutes = 0, nLseconds = 0, bLminutes = 0, bLseconds = 0; // Persistent times
unsigned long nlStartTime = 0, blStartTime = 0;
bool nlCompleted = false, blCompleted = false;

uint8_t previousData[5] = {0}; // Adjust size based on maximum data length
bool isFirstRun = true;

// Function declarations
void stopDevice();
void startDevice(uint8_t newNLminutes, uint8_t newNLseconds, uint8_t newBLminutes, uint8_t newBLseconds);
void resetDevice();
void handleLEDStates();
void setLEDColor(uint8_t red, uint8_t green, uint8_t blue, bool pwmblink);

class MyCallback : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) override {
    std::string value = pCharacteristic->getValue();
    
    if (value.length() == 0) {
      Serial.println("No data received");
      return;
    }

    // Log received data
    Serial.print("New Message Received: ");
    for (char c : value) {
      Serial.printf("%02X ", c);
    }
    Serial.println();

    // Process command
    switch (value[0]) {
      case 0xFE: // Stop command
        stopDevice();
        break;

      case 0xF0: // Start command
        if (value.length() >= 5) { // Ensure we have enough bytes
          startDevice(value[1], value[2], value[3], value[4]);
        } else {
          Serial.println("Invalid start command format");
        }
        break;

      case 0xFF: // Reset command
        resetDevice();
        break;

      default:
        Serial.println("Unknown command");
        break;
    }
  }
};

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
  pCharacteristic->setCallbacks(new MyCallback()); // Set the callback here
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  // Initialize LED
  strip.begin();
  strip.show(); // Initialize all pixels to 'off'
  setLEDColor(0, 0, 255, false); // Blue glow for standby
}

void loop() {
  // Handle LED states or any other ongoing tasks
  handleLEDStates();
  delay(10);
}

// New variables to track paused time
unsigned long pausedTime = 0;   // Total time the device was paused
unsigned long pauseStartTime = 0; // When the device was paused

void stopDevice() {
  Serial.println("Device stopped");
  
  if (isDeviceStarted) {
    pauseStartTime = millis(); // Record when the device was paused
  }

  nlCompleted = false;
  blCompleted = false;
  setLEDColor(0, 0, 255, false); // Blue glow for standby
  isDeviceStarted = false; // Mark the device as stopped
}

void startDevice(uint8_t newNLminutes, uint8_t newNLseconds, uint8_t newBLminutes, uint8_t newBLseconds) {
  if (!isDeviceStarted) {
    if (pauseStartTime > 0) {
      // Resume from pause
      pausedTime += millis() - pauseStartTime; // Add the paused duration to the total
      pauseStartTime = 0; // Clear the pause start time

      Serial.println("Device resumed:");
      Serial.print("nLminutes = ");
      Serial.print(nLminutes);
      Serial.print(", nLseconds = ");
      Serial.print(nLseconds);
      Serial.print(", bLminutes = ");
      Serial.print(bLminutes);
      Serial.print(", bLseconds = ");
      Serial.println(bLseconds);
    } else {
      // First start or restart: update times
      nLminutes = newNLminutes;
      nLseconds = newNLseconds;
      bLminutes = newBLminutes;
      bLseconds = newBLseconds;

      nlStartTime = millis();
      pausedTime = 0; // Reset paused time
      nlCompleted = false;
      blCompleted = false;

      Serial.println("Device started with new parameters:");
      Serial.print("nLminutes = ");
      Serial.print(nLminutes);
      Serial.print(", nLseconds = ");
      Serial.print(nLseconds);
      Serial.print(", bLminutes = ");
      Serial.print(bLminutes);
      Serial.print(", bLseconds = ");
      Serial.println(bLseconds);
    }

    isDeviceStarted = true;
  } else {
    Serial.println("Device already started, ignoring new start command");
  }
}

void resetDevice() {
  Serial.println("Device reset");
  isDeviceStarted = false;

  // Clear the stored times
  nLminutes = 0;
  nLseconds = 0;
  bLminutes = 0;
  bLseconds = 0;

  nlCompleted = false;
  blCompleted = false;

  setLEDColor(0, 0, 255, false); // Blue glow for standby
}

bool blStarted = false;
void handleLEDStates() {
  if (!isDeviceStarted) return;

  unsigned long currentTime = millis();
  unsigned long nlDuration = (nLminutes * 60 + nLseconds) * 1000;
  unsigned long blDuration = (bLminutes * 60 + bLseconds) * 1000;

  // Adjust current time by subtracting paused duration
  unsigned long adjustedTime = currentTime - pausedTime;

  if (!nlCompleted && adjustedTime - nlStartTime < nlDuration) {
    setLEDColor(0, 0, 0, true); // Turn off LED (No light)
    return;
  }

  if (!nlCompleted) {
    nlCompleted = true;
    blStartTime = adjustedTime; // Start blinking phase
  }

  if (!blCompleted && adjustedTime - blStartTime < blDuration) {
    setLEDColor(0, 255, 0, true);
    
    return;
  }

  if (!blCompleted) {
    blCompleted = true; // Move to constant light phase
  }

  // Constant light
  setLEDColor(0, 255, 0, false); // Green light (Constant)
}

// Helper function to set LED color
void setLEDColor(uint8_t red, uint8_t green, uint8_t blue, bool pwmBlink = false) {
  static unsigned long lastUpdate = 0;
  static int brightness = 0;
  static int step = 10; // Change in brightness for each step (can be adjusted for speed)
  
  unsigned long currentTime = millis();
  
  if (pwmBlink) {
    // Update brightness at regular intervals
    if (currentTime - lastUpdate > 20) { // Update every 20 ms
      brightness += step;
      if (brightness >= 255 || brightness <= 0) {
        step = -step; // Reverse direction when hitting max or min brightness
      }
      lastUpdate = currentTime;
    }
    if(brightness > 255) {
      brightness = 255;
    }
    if(brightness < 0) {
      brightness = 0;
    }
    // Apply the calculated brightness
    uint8_t scaledRed = (red * brightness) / 255;
    uint8_t scaledGreen = (green * brightness) / 255;
    uint8_t scaledBlue = (blue * brightness) / 255;
    strip.setPixelColor(0, strip.Color(scaledRed, scaledGreen, scaledBlue));
  } else {
    // Directly set the LED color without PWM
    strip.setPixelColor(0, strip.Color(red, green, blue));
  }
  
  strip.show();
}
