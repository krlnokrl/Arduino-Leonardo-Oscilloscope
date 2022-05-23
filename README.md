# Arduino-Leonardo-Oscilloscope
Yet another Arduino Based oscilloscope

## Installation
Upload the Arduino code to your arduino leonardo  
Install processing and run the processing code  
*you might need to modify oscilloscope_gui.pde:20 : Serial.list()[X] to your Arduino serial port*

## Usage
In the processing scope window press:
* T for single trigger
* O for triggering once on edge (r/f)
* R for setting rising edge threshold
* F for setting falling edge threshold
* C for continuous triggering on edge
* S to stop continuous trigger

## Performance
20 μs/sample  
1024 samples/trigger  
~8bit resolution  