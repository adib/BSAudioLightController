# Time Light Tester

Tester app and driver of the [Time-a-Light](http://www.time-a-light.com) traffic light device.

## Setup

1. Add TimeLightTester as a subproject of your Xcode project.
2. Add everything inside the `AudioLightController` folder to your target.

## Usage

1. Include `BSAudioLightController.h` into your controller
2. Hook up user defaults key `BSAudioLightEnabledPrefKey` with your UI and store boolean value `YES` to enable it or `NO` otherwise.
3. Setup this class as a singleton object (or create only one instance of it). 
4. Call `audioLightItem: setActive:` to activate or de-activate the signal lights or buzzer.

Note that the signal audio will only go through the headphone jack since this is the way the device is meant to be used.

Please take a look at the example tester and play around with to get a feel how to use the driver and how the device works.

## Device API

Time-a-light takes in commands as square wave tones from the audio jack. 

Signal | Left Channel | Right Channel
-------|--------------|--------------
Green  | 1000 Hz      | -
Yellow | 2000 Hz      | - 
Red    | 3000 Hz      | -
Buzzer | -            | 1500 Hz

 
As of this writing only one light or the buzzer can be active at one time due to Time-a-light's hardware constraints.

## License

This project is licensed under the BSD license. Please let me know (adib@cutecoder.org) if you use it for something interesting.

Please note that I'm publishing this library as open source as a courtesy since I'm also using it myself in one of my apps. However I won't be able to provide much support for it in case of API changes, etc.

Sasmito Adibowo  
http://cutecoder.org

   