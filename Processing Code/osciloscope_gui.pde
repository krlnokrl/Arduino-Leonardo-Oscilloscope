import processing.serial.*;


Serial port;  // Create object from Serial class
int val;      // Data received from the serial port
int[] values;
float zoom;
int c =0;
PGraphics pg;


int rising, falling;


void setup() 
{
  size(1080, 720);
  pg = createGraphics(1030, 512);
  // Open the port that the board is connected to and use the same speed (115200 bps)
  port = new Serial(this, Serial.list()[0], 115200);
  println(Serial.list()[0]);
  values = new int[width];
  zoom = 1.0f;
  smooth();
}

int getY(int val) {
  return (int)(height - val / 255.0f * (height - 1));
}

void getValues() {
  int value = -1;
  while (port.available() > 0) {
    try{
      String str = port.readStringUntil('\n');
      value = Integer.parseInt(str.trim());
      pushValue(value);
      println(value);
    }catch(Exception e){} 
  }
}

void pushValue(int value) {
  for (int i=0; i<width-1; i++)
    values[i] = values[i+1];
  values[width-1] = value;
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
}

void drawGrid() {
  pg.strokeWeight(1);
  pg.stroke(255, 0, 0,100);
  for(int i=1;i<8; i++){
    pg.line(0, i*pg.height/8, pg.width, i*pg.height/8);
    pg.text((8-i)*5.0/8 + "V", 0, i*pg.height/8);
  }
  pg.stroke(0,255, 0,100);
  for(int i=1;i<8; i++){
    pg.line(i*pg.width/8, 0, i*pg.width/8, pg.height);
  }
  pg.text((20.48/zoom)/8 + "ms/div", pg.width/8, 10);

  if(rising>0){
    pg.stroke(255, 200, 0);
    pg.line(0, 512-(rising*2), pg.width, 512-(rising*2));
  }
  if(falling>0){
    pg.stroke(255, 0, 200);
    pg.line(0, 512-(falling*2), pg.width, 512-(falling*2));
  }

}

void keyReleased() {
  switch (key) {
    case '+':
      zoom *= 1.5f;
      println(zoom);
      if ( (int) (width / zoom) <= 1 )
        zoom /= 1.5f;
      break;
    case '-':
      zoom /= 1.5f;
      if (zoom < 1.0f)
        zoom *= 1.5f;
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
    int tresh_r = 255 -((mouseY-80)/2);
    if(tresh_r>0 && tresh_r<255){
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
    int tresh_f = 255 -((mouseY-80)/2);
    if(tresh_f>0 && tresh_f<255){
      println(tresh_f);
      falling = tresh_f;
      port.write("f"+falling);
    }
    break;
  }
}

void draw()
{
  getValues();
  pg.beginDraw();
  pg.background(0);
  drawLines();
  drawGrid();

  pg.endDraw();
  image(pg, 0, 80); 
}
