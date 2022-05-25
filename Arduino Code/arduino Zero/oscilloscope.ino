
#define HWORDS 2048
#define ADCPIN A0

#define Serial SerialUSB

uint16_t adcbuf[HWORDS+1];     
uint8_t c = 0;

typedef struct {
    uint16_t btctrl;
    uint16_t btcnt;
    uint32_t srcaddr;
    uint32_t dstaddr;
    uint32_t descaddr;
} dmacdescriptor ;
volatile dmacdescriptor wrb[12] __attribute__ ((aligned (16)));
dmacdescriptor descriptor_section[12] __attribute__ ((aligned (16)));
dmacdescriptor descriptor __attribute__ ((aligned (16)));


static uint32_t chnl = 0;  // DMA channel
volatile uint32_t dmadone;

void DMAC_Handler() {
    // interrupts DMAC_CHINTENCLR_TERR DMAC_CHINTENCLR_TCMPL DMAC_CHINTENCLR_SUSP
    uint8_t active_channel;

    // disable irqs ?
    __disable_irq();
    active_channel =  DMAC->INTPEND.reg & DMAC_INTPEND_ID_Msk; // get channel number
    DMAC->CHID.reg = DMAC_CHID_ID(active_channel);
    dmadone = DMAC->CHINTFLAG.reg;
    DMAC->CHINTFLAG.reg = DMAC_CHINTENCLR_TCMPL; // clear
    DMAC->CHINTFLAG.reg = DMAC_CHINTENCLR_TERR;
    DMAC->CHINTFLAG.reg = DMAC_CHINTENCLR_SUSP;
    __enable_irq();
}

void dma_init() {
    // probably on by default
    PM->AHBMASK.reg |= PM_AHBMASK_DMAC ;
    PM->APBBMASK.reg |= PM_APBBMASK_DMAC ;
    NVIC_EnableIRQ( DMAC_IRQn ) ;

    DMAC->BASEADDR.reg = (uint32_t)descriptor_section;
    DMAC->WRBADDR.reg = (uint32_t)wrb;
    DMAC->CTRL.reg = DMAC_CTRL_DMAENABLE | DMAC_CTRL_LVLEN(0xf);
}

void adc_dma(void *rxdata,  size_t hwords) {
    uint32_t temp_CHCTRLB_reg;

    DMAC->CHID.reg = DMAC_CHID_ID(chnl);
    DMAC->CHCTRLA.reg &= ~DMAC_CHCTRLA_ENABLE;
    DMAC->CHCTRLA.reg = DMAC_CHCTRLA_SWRST;
    DMAC->SWTRIGCTRL.reg &= (uint32_t)(~(1 << chnl));
    temp_CHCTRLB_reg = DMAC_CHCTRLB_LVL(0) |
      DMAC_CHCTRLB_TRIGSRC(ADC_DMAC_ID_RESRDY) | DMAC_CHCTRLB_TRIGACT_BEAT;
    DMAC->CHCTRLB.reg = temp_CHCTRLB_reg;
    DMAC->CHINTENSET.reg = DMAC_CHINTENSET_MASK ; // enable all 3 interrupts
    dmadone = 0;
    descriptor.descaddr = 0;
    descriptor.srcaddr = (uint32_t) &ADC->RESULT.reg;
    descriptor.btcnt =  hwords;
    descriptor.dstaddr = (uint32_t)rxdata + hwords*2;   // end address
    descriptor.btctrl =  DMAC_BTCTRL_BEATSIZE_HWORD | DMAC_BTCTRL_DSTINC | DMAC_BTCTRL_VALID;
    memcpy(&descriptor_section[chnl],&descriptor, sizeof(dmacdescriptor));

    while (ADC->INTFLAG.bit.RESRDY == 0);  
    uint16_t value = ADC->RESULT.reg;      
    ADCsync();                             

    // start channel
    DMAC->CHID.reg = DMAC_CHID_ID(chnl);
    DMAC->CHCTRLA.reg |= DMAC_CHCTRLA_ENABLE;
}

static __inline__ void ADCsync() __attribute__((always_inline, unused));
static void   ADCsync() {
  while (ADC->STATUS.bit.SYNCBUSY == 1); //Just wait till the ADC is free
}


void adc_init(int resolution){
  analogRead(ADCPIN);  // do some pin init  pinPeripheral()
  ADC->CTRLA.bit.ENABLE = 0x00;             // Disable ADC
  ADCsync();
  //ADC->REFCTRL.bit.REFSEL = ADC_REFCTRL_REFSEL_INTVCC0_Val; //  2.2297 V Supply VDDANA
  //ADC->INPUTCTRL.bit.GAIN = ADC_INPUTCTRL_GAIN_1X_Val;      // Gain select as 1X
  ADC->INPUTCTRL.bit.GAIN = ADC_INPUTCTRL_GAIN_DIV2_Val;  // default
  ADC->REFCTRL.bit.REFSEL = ADC_REFCTRL_REFSEL_INTVCC1_Val;
  ADCsync();    //  ref 31.6.16
  ADC->INPUTCTRL.bit.MUXPOS = g_APinDescription[ADCPIN].ulADCChannelNumber;
  ADCsync();
  ADC->AVGCTRL.reg = 0x00 ;       //no averaging
  ADC->SAMPCTRL.reg = 0x00;  ; //sample length in 1/2 CLK_ADC cycles
  ADCsync();
  if(resolution == 0)
    ADC->CTRLB.reg = ADC_CTRLB_PRESCALER_DIV32 | ADC_CTRLB_FREERUN | ADC_CTRLB_RESSEL_8BIT;
  else if(resolution == 1)
    ADC->CTRLB.reg = ADC_CTRLB_PRESCALER_DIV16 | ADC_CTRLB_FREERUN | ADC_CTRLB_RESSEL_8BIT;
  else if(resolution == 2)
    ADC->CTRLB.reg = ADC_CTRLB_PRESCALER_DIV8 | ADC_CTRLB_FREERUN | ADC_CTRLB_RESSEL_8BIT;
  else
    ADC->CTRLB.reg = ADC_CTRLB_PRESCALER_DIV64 | ADC_CTRLB_FREERUN | ADC_CTRLB_RESSEL_8BIT;
  ADCsync();
  ADC->CTRLA.bit.ENABLE = 0x01;
  ADCsync();
}



bool trigger = false;

bool trigger_c = false;
bool trigger_o = false;

bool trigger_r = false;
bool trigger_f = false;


uint8_t tresh_r = 0;
uint8_t tresh_f = 0;

void setup() {
  Serial.begin(250000);
  analogReadResolution(8);
  adc_init(0);
  dma_init();
}

void loop() {
  c = (c+1)%100;
  if (c==0 && Serial.available() > 0) {
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
      tresh_r = val;
    }
    if(cmd=='f'){
      trigger_f=!trigger_f;
      tresh_f = val;
    }
    if(cmd=='b'){
      if(val == '1'){
         adc_init(0);
      }
      if(val == '2'){
         adc_init(1);
      }
      if(val == '3'){
         adc_init(2);
      }
    }
  }
  if(trigger_c || trigger_o){
    adc_dma(adcbuf,2);
    while(!dmadone);
    if(trigger_r&&(adcbuf[0]<=tresh_r)&&(adcbuf[1]>tresh_r)){
      trigger = true;
      trigger_o = false;
    }
    if(trigger_f&&(adcbuf[0]>=tresh_f)&&(adcbuf[1]<tresh_f)){
      trigger = true;
      trigger_o = false;
    }
    
  }
    
  if(trigger){
    adc_dma(adcbuf,HWORDS);
    while(!dmadone);
    char s[32];
    for(int i=0; i<HWORDS; i+=32){
      for(int j=0; j<32; j++){
        s[j]=adcbuf[i+j];
      }

      Serial.write(s, 32);
      Serial.flush();
    }
    trigger = false;
  }

  

}