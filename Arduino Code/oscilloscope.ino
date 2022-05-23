
//sample length
#define MEM_LEN 1024


//speed up ADC
#define ADC_TIME_104  ADCSRA=(ADCSRA&0xF80)|0x07   
#define ADC_TIME_52   ADCSRA=(ADCSRA&0xF80)|0x06   
#define ADC_TIME_26   ADCSRA=(ADCSRA&0xF80)|0x05   
#define ADC_TIME_13   ADCSRA=(ADCSRA&0xF80)|0x04  

//state variables for triggering modes
bool trigger = false;

bool trigger_c = false;
bool trigger_o = false;

bool trigger_r = false;
bool trigger_f = false;


uint8_t mem[MEM_LEN];

uint8_t tresh = 0;

void setup() {
  Serial.begin(115200);
  pinMode(A0, INPUT);
  ADC_TIME_13;
  while(!Serial);
}

void loop() {

	//serial control
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    int val = Serial.read();
    if(cmd=='t'){
      trigger=true;
    }
    if(cmd=='c'){
      trigger_c=true;
    }
    if(cmd=='o'){
      trigger_o=true;
    }
    if(cmd=='s'){
      trigger_c=false;
      trigger_o=false;
    }
    if(cmd=='r'){
      trigger_r=!trigger_r;
      tresh = val;
    }
    if(cmd=='f'){
      trigger_f=!trigger_f;
      tresh = val;
    }
  }
  
  //triggering modes
  if(trigger_c || trigger_o){
    uint8_t act = analogRead(A0);
	uint8_t prev = analogRead(A0);
    if(trigger_r&&(act>tresh)&&(prev<tresh)){
      trigger = true;
      trigger_o = false;
    }
    if(trigger_f&&(act<tresh)&&(prev>tresh)){
      trigger = true;
      trigger_o = false;
    }
    prev = act;
    
  }
  
  //sample
  if(trigger){
    for(int i=0; i< MEM_LEN; i++)
      mem[i] = analogRead(A0);
    for(int i=0; i< MEM_LEN; i++)
      Serial.println(mem[i]);
    trigger = false;
   
  }

  

}