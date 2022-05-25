import processing.serial.*;

void computeDft(int[] in, double[] outmag) {
    int n = in.length;
    for (int k = 0; k < n/3; k++) {  // For each output element
      double sumreal = 0;
      double sumimag = 0;
      for (int t = 0; t < n; t++) {  // For each input element
        double angle = 2 * Math.PI * t * k / n;
        sumreal += in[t]/1024.0 * Math.cos(angle) * Math.sin(angle);
        sumimag += -in[t]/1024.0 * Math.sin(angle) * Math.cos(angle);
      }
      outmag[k] = Math.sqrt(sumreal*sumreal+sumimag*sumimag);
    }
  }


float sampleMax = 255;  //10 bit resolution
float voltageMax = 6.6; // 3.3v max 6.6 with a 1/2 voltage divider
int sampleLen = 2048;  //1024/2048 samples buffer
float usSamp = 3.34;//1.67;    //4uS/sample
int clockDiv = 1;

Serial port;  // Create object from Serial class
int val;      // Data received from the serial port
int[] values;
double[] fftout;
float zoom;
float zoomVoltage;

PGraphics pg;
PGraphics spectogram;

int rising, falling;

int sDragX,sDragY, eDragX, eDragY, specX;

void setup() 
{
  size(1080, 900);
  pg = createGraphics(1024, 512);
  spectogram = createGraphics(1024, 256);
  // Open the port that the board is connected to and use the same speed (9600 bps)
  port = new Serial(this, Serial.list()[1],250000);
  println(Serial.list());
  values = new int[sampleLen+1];
  fftout = new double[sampleLen+1];
  zoom = 1.0f;
  zoomVoltage = 5.0f;
  smooth();
}

int getY(int val) {
  float vh = (val/sampleMax) * (voltageMax/zoomVoltage);
  return (int)(pg.height*(1-vh));
}

void getValues() {
  while (port.available() > 0) {
    try{
        pushValue(port.read());
    }catch(Exception e){} 
  }
}

void pushValue(int value) {
  for (int i=0; i<sampleLen-1; i++)
    values[i] = values[i+1];
  values[sampleLen-1] = value;
}

void drawLines() {
  pg.stroke(255);
  pg.strokeWeight(2);
  int displayWidth = (int) (pg.width / zoom);
  int k = values.length - displayWidth;
  int x0 = 0;
  int y0 = getY(values[k]);
  for (int i=1; i<displayWidth; i++) {
    k++;
    int x1 = (int) (i * (pg.width-1) / (displayWidth-1));
    int y1 = getY(values[i]);
    pg.line(x0, y0, x1, y1);
    //point(x0,y0);
    x0 = x1;
    y0 = y1;
  }
  spectogram.stroke(255,200,0);
  spectogram.strokeWeight(1);
  computeDft(values, fftout);
  for (int i=1; i<spectogram.width; i++) {
    spectogram.line(i,spectogram.height,i,(int)((1-fftout[i/2]/20)*spectogram.height));  
  }
  
  
}

void drawGrid() {
  pg.strokeWeight(1);
  pg.stroke(255, 0, 0,100);
  for(int i=1;i<8; i++){
    pg.line(0, i*pg.height/8, pg.width, i*pg.height/8);
    pg.text((8-i)*zoomVoltage/8 + "V", 0, i*pg.height/8);
  }
  pg.stroke(0,255, 0,100);
  for(int i=1;i<8; i++){
    pg.line(i*pg.width/8, 0, i*pg.width/8, pg.height);
  }
  pg.text((usSamp*pg.width/zoom)/8 + "uS/div", pg.width/8, 10);
  
  float vSampl = Math.round((1-(mouseY-80.0)/pg.height) * zoomVoltage*100)/100.0;
  float tSampl = Math.round(((mouseX+0.0)/pg.width) * usSamp*pg.width/zoom*100)/100.0;
  pg.text(vSampl + "V / " + tSampl + "uS" , 7*pg.width/8, 10); 
  
  pg.stroke(255, 200, 0);

  if(rising>0){
    pg.stroke(255, 200, 0);
    float lh = (rising/sampleMax) * (voltageMax/zoomVoltage);
    pg.line(0, (1-lh)*pg.height, pg.width, (1-lh)*pg.height);
  }
  if(falling>0){
    pg.stroke(255, 0, 200);
    float lh = (falling/sampleMax) * (voltageMax/zoomVoltage);
    pg.line(0, (1-lh)*pg.height, pg.width, (1-lh)*pg.height);
  }
  pg.strokeWeight(1);
  pg.stroke(0, 100, 255, 100);
  pg.line(sDragX,0, sDragX, pg.height);
  pg.line(0,sDragY, pg.width, sDragY);
  pg.strokeWeight(3);
  pg.point(sDragX,sDragY);
  pg.strokeWeight(1);
  pg.stroke(0, 200, 255, 100);
  pg.line(eDragX,0, eDragX, pg.height);
  pg.line(0,eDragY, pg.width, eDragY);
  pg.strokeWeight(3);
  pg.point(eDragX,eDragY);
  pg.strokeWeight(1);
  vSampl = Math.round((sDragY-eDragY+0.0)/pg.height * zoomVoltage*100)/100.0;
  tSampl = Math.round((sDragX-eDragX+0.0)/pg.width * usSamp*pg.width/zoom*100)/100.0;
  pg.text(vSampl + "V / " + tSampl + "uS" , eDragX, eDragY);
  int l = (int)(1000000/ usSamp / spectogram.width/2);
  spectogram.stroke(255);
  spectogram.strokeWeight(1);
  spectogram.text(specX*l+ "Hz", specX, 10);
  spectogram.line(specX,0,specX, spectogram.height);
}

void mousePressed() {
  sDragX = mouseX; 
  sDragY = mouseY-80;
  specX = mouseX;
}

void mouseReleased() {
  eDragX = mouseX; 
  eDragY = mouseY-80; 
}

void keyReleased() {
  switch (key) {
    case '+':
      zoom += 0.5f;
      if ( (int) (pg.width / zoom) <= 1 )
        zoom -= -0.5f;
      break;
    case '-':
      zoom -= 0.5f;
      if (zoom < 0.5f)
        zoom = 0.5f;
      break;
    case '*':
      zoomVoltage /= 1.2f;
      if (zoomVoltage < 0.5f)
        zoomVoltage = 0.5f;
      break;
    case '/':
      zoomVoltage *= 1.2f;
      if (zoomVoltage > 10.0f)
        zoomVoltage = 10.0f;
      break;
    case 't':
      port.write("t0");
      println("trigger");
      break;
    case 'c':
      port.write("c0");
      break;
    case 'o':
      port.write("o0");
      break;
    case 's':
      port.write("s0");
      break;
    case 'r':
    if(rising>0){
      rising =-1;
      port.write("r0");
      break;
    }
    int tresh_r = (int)((1-(mouseY-80.0)/pg.height) * zoomVoltage/voltageMax * sampleMax);
    if(tresh_r>0 && tresh_r<sampleMax){
      println(tresh_r);
      rising = tresh_r;
      port.write("r"+rising);
    }
    break;
    case 'f':
    if(falling>0){
      falling =-1;
      port.write("f0");
      break;
    }
    int tresh_f = (int)((1-(mouseY-80.0)/pg.height) * zoomVoltage/voltageMax * sampleMax);
    if(tresh_f>0 && tresh_f<sampleMax){
      println(tresh_f);
      falling = tresh_f;
      port.write("f"+falling);
    }
    break;
    case 'b':
      clockDiv = (clockDiv%3+1);
      port.write("b"+clockDiv);
      usSamp = 0.835 * pow(2,(3-clockDiv));
    break;
  }
}

void draw()
{
  getValues();
  pg.beginDraw();
  spectogram.beginDraw();
  spectogram.background(0);
  pg.background(0);
  drawLines();
  drawGrid();
  spectogram.endDraw();
  pg.endDraw();
  image(pg, 0, 80);
  image(spectogram, 0, 600);

}
