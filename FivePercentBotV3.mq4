//+------------------------------------------------------------------+
//|                                                        robot.mq4 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//| 
//+------------------------------------------------------------------+
#property strict
#property description "BOT 5 PERCENT BOT v.1.0"
#property description "Copy right (C) by SHLFOREX TEAM"
#property description "Develop by Nguyen Tat Thanh"
#property description "Mobile: 098 664 8910"
#property description "====Ha Noi03-2020==="
#define SLIPPAGE              3

enum ENUM_STOP_LOST_TYPE{BASE_PRICE=0,MID_BASE_PRICE, PRE_H4};
enum ENUM_POSITION_TYPE {LONG_ONLY, SHORT_ONLY, LONG_And_SHORT};
enum ENUM_BREAK_OUT_TYPE {NONE,LONG,SHORT};
ENUM_TIMEFRAMES OPEN_ORDER_ON_TIME_FRAME = PERIOD_H1;//Trading time frame

input string SettingPosition="";//"==>>Setting position<=="
input ENUM_POSITION_TYPE PositionType = LONG_And_SHORT;//Positions
input string SettingRiskManagement="";//"==>>Setting risk management<=="
input double MAX_RISK_PER_TRADE = 20;//Max risk per trade(R$)

string SetingTimeForTrading = "";// "==>>Setting time for trading<=="
int START_TIME_TRADING = 8;//Start time(0-23)H
int END_TIME_TRADING = 20; //End time(0-23)H

string SetingBasePrice= "";// "==>>Setting calculate base price<=="
int BASE_CANDLES = 8;//Range candle (number) 

input string SetingTradingInfo = "";// "==>>Setting trading<=="
input bool IS_OPEN_BY_MARKET = true;//Open order type (Market|Limmit)( true| Market - False| Limmit)

input double DEFAULT_WIN_RISK_FACTOR = 1;//Default win risk factor F=TP/SL
input double FIBO = 23;//Open order in fibo of candle(1-100) 
int MAX_BREAK_OUNT_INDEX = 3;//Candle break out to open order (after that cancel order) 

input string SettingStoplost="";//"==>>Setting stop loss<=="
input ENUM_STOP_LOST_TYPE STOP_LOST_TYPE = MID_BASE_PRICE;// Stoploss type 
double DELTA_STOP_LOST = 5;// Delta stoplost pips

input string SettingDevelop="";//"==>>Setting view base and break out<=="
input bool off_Draw = true;//Off Base price and break out
input bool off_open_order = false;// Off open order
string SettingBreakEvent ="";//"==>>Setting break event<=="
bool IS_SET_BREAK_EVENT = false;// Set break event (TRUE)

string SetingDailyTrading = "";// "==>>Setting daily trading<==";
bool ReverseFialOrder = false;// Reverse order type when fail
int MAX_ORDER_PER_DAY = 1;// Max order perday (0-N)(0 unlimited)

string SetingAutoRisk= "";// "==>>Setting auto calculate risk per trade<==";
bool AUTO_LOT_SIZE = false;// Auto calculate 
double MAX_RISK_PER_TRADE_PERCENT = 0.5;// Max risk per trade percent (R%)

int MaxValue = 2147483647;
int MagicNumber =0;
double price = 0;
double priceSL = 0;
double priceTP = 0;  

double minStopLevel = 0;
color clColor=clrRed;
double LotSizeStart = 0;
string firstOrderComment ="FP.3.1.3";

double basePriceHigh = 0;
double basePriceLow = 0;
double breakOutHighPrice = 0;
double breakOutLowPrice =0;

int breakOutIndex = -1;
int startBaseIndex = 0;

ENUM_ORDER_TYPE failOrderType = OP_BUYLIMIT;
double winRiskFactor = 0;

enum ENUM_FIBO_TYPE{FB_UP, FB_DOWN};
int ticketOpen = -1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//---   
     winRiskFactor = DEFAULT_WIN_RISK_FACTOR;   
     EventSetTimer(2);
//---
     return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//--------------------------------------------------------------------
    EventKillTimer();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//--------------------------------------------------------------------  
  if(Year() > 2020)
  {
   Comment("End time: 2020 must update new ");
   return;
  } 

   AutoTrade();  
}
//+------------------------------------------------------------------+



void OnTimer(){
 if(Year() > 2020)
  {
   Comment("End time: 2020 must update new ");
   return;
  }
}

void AutoTrade()
{ 
   if(IsTradeAllowed() == false) 
   return;
   
    // Default pre candle  
   CheckBasePrice();   
   ticketOpen = GetOpeningTicket();
   if(!IS_OPEN_BY_MARKET)
     CloseTrade();
     
    if(IsStopTrading()) 
     return;
   if(!IsTradingTime()) 
   return; 
    OpenFirtOrder();  
}

bool IsTradingTime(){
   if(END_TIME_TRADING <= 0 || START_TIME_TRADING <= 0)
   return true;
  
   int hour = TimeHour(iTime(_Symbol,OPEN_ORDER_ON_TIME_FRAME,0));
   
   if(hour >= END_TIME_TRADING || hour < START_TIME_TRADING ) 
    {
      Comment("Stop TradingTime:"+hour);
     return false;  
    }
   return true;
}

void CloseTrade()
{
    int hour = TimeHour(iTime(_Symbol,OPEN_ORDER_ON_TIME_FRAME,0));
   
    if(!OrderSelect(ticketOpen,SELECT_BY_TICKET, MODE_TRADES))
      return;
   
    int openHour = TimeHour(OrderOpenTime());
    
    if(hour - openHour < 2) 
    return;
    
      switch(OrderType())
      {
         case OP_BUY: 
         if(OrderStopLoss()!=0) 
          return;
            OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), SLIPPAGE, clrGreen);                
            break;
         case OP_SELL:
           if(OrderStopLoss()!=0) 
            return;
            OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), SLIPPAGE, clrRed);                 
            break;            
         case OP_BUYSTOP:
         case OP_SELLSTOP:
         case OP_BUYLIMIT:
         case OP_SELLLIMIT:
            OrderDelete(OrderTicket(), clrGray);  
            break;
         default:   
            break;           
      } 
      ticketOpen = 0;
}

void OpenFirtOrder()
{   
   if(ticketOpen > 0) 
   {     
      Comment("Order opened: "+ ticketOpen);
      return;
   } 
    
   string comment = firstOrderComment;
    
   ENUM_ORDER_TYPE signalTrade = GetOrderType();

   if(signalTrade == OP_BUYSTOP || breakOutHighPrice == 0 || breakOutLowPrice == 0)
   {   
    Print("Stoping open order signalTrade = "+signalTrade+" breakOutHighPrice: "+ breakOutHighPrice+" breakOutLowPrice: "+ breakOutHighPrice);
    return;
    }  
    
    price = 0;
    
    if(signalTrade == OP_BUYLIMIT)
    {      
      price = GetFiboLevel(breakOutHighPrice,breakOutLowPrice,FIBO,FB_DOWN);
      comment +="\nOP_BUYLIMIT";
    }else if(signalTrade == OP_SELLLIMIT)
    {
      price = GetFiboLevel(breakOutHighPrice,breakOutLowPrice,FIBO,FB_UP);;
      comment +="\nOP_SELLLIMIT";
    }else if(signalTrade == OP_BUY)
    {
       price = Ask;
       signalTrade = OP_BUY;
        comment +="\nOP_BUY";
     }
     else if(signalTrade == OP_SELL)
     {
       comment +="\nOP_SELL";
       price = Bid;
       signalTrade = OP_SELL;
     }
        
     //Calculate stoploss
    CalculateSL(signalTrade,winRiskFactor,price,DELTA_STOP_LOST,basePriceHigh,basePriceLow);
  
   double distanceR = GetPipsFrom2Price(price,priceSL);
       
   // Lot trade
   double lost_trade = MAX_RISK_PER_TRADE;
   
   if(AUTO_LOT_SIZE)
   {
    lost_trade =  AccountBalance()*MAX_RISK_PER_TRADE_PERCENT/100;
   }
     
   // Calculate lot size             
   LotSizeStart = GetLotSizeOrder(distanceR,lost_trade);
 
  int slipPage = SLIPPAGE;
  
  //preparing slippage for 5 digit broker
  if (Digits == 3 || Digits == 5) 
  slipPage *= 10;
     
  if(LotSizeStart < 0.01 ) 
  {
     Comment("Cancel open order: LotSizeStart ="+ LotSizeStart +" < 0.01");
     return;
  }
  
  RefreshRates();
  // Reset ticket
  
  int ticket = OrderSend(_Symbol,signalTrade,LotSizeStart,price,slipPage,priceSL,priceTP,firstOrderComment,MagicNumber,0,clColor);  
  
  if(ticket<0)
  {      
      Print("Error: ", GetLastError()+" slipPage: "+slipPage+" price: "+ Ask+" - LotSizeStart: "+ LotSizeStart +" priceSL: " + priceSL +" priceTP: " + priceTP);
  } else
  {
   Print(_Symbol+" - OPEN Sucssess ticketOpen: "+ticketOpen+"\n price: "+ price+" - LotSizeStart: "+ LotSizeStart +" priceSL: " + priceSL +" priceTP: " + priceTP);
  }  
}

// Set SL_TP
void CalculateSL(ENUM_ORDER_TYPE orderType,double factor,double currentPrice,double deltaPips, double priceHigh,double priceLow)
{   
   // Reset 
   priceSL = 0;
   priceTP = 0;
   
   if(price <= 0)
   {
      Comment("Can't set Stop loss - Takeprofit => Price open order is zero");
      return;
   }
   
   double distanBase = 0;   
         
   if(STOP_LOST_TYPE == MID_BASE_PRICE)
   {
      double midPrice = CalAvgPrice(priceHigh,priceLow);
      
         // Distance SL 
      distanBase = GetPipsFrom2Price(midPrice,currentPrice) + deltaPips;
                 
      if(orderType == OP_BUYLIMIT || orderType == OP_BUY)
      {
        priceSL = currentPrice - distanBase *GetPipValue();
                
        priceTP = currentPrice + factor*distanBase*GetPipValue();
        
      }else if(orderType == OP_SELLLIMIT || orderType == OP_SELL)
      {  
        priceSL = currentPrice + distanBase*GetPipValue();
        
        priceTP = currentPrice - factor*distanBase*GetPipValue();
      }
      
      Comment("MID_BASE_PRICE Digits= "+Digits+"\n currentPrice:"+currentPrice+" priceSL="+priceSL +" priceTP:"+ priceTP +" basePriceHigh:"+ priceHigh +" basePriceLow:"+ priceLow+ " midPrice: "+ midPrice+" distanBase: "+ distanBase);
      
      return;
      
   }else if(STOP_LOST_TYPE == PRE_H4)
   {
      double h4Price = 0;      
     if(orderType == OP_BUYLIMIT || orderType == OP_BUY)
      {
         h4Price = iLow(_Symbol,PERIOD_H4,1);
        
         // Distance SL 
         distanBase = GetPipsFrom2Price(h4Price,currentPrice) + deltaPips;         
         
         priceSL = currentPrice  - distanBase*GetPipValue();
        
        priceTP = currentPrice + factor*distanBase*GetPipValue();
        
      }else if(orderType == OP_SELLLIMIT || orderType == OP_SELL)
      {
        h4Price = iHigh(_Symbol,PERIOD_H4,1);
         // Distance SL 
         distanBase = GetPipsFrom2Price(h4Price,currentPrice) + deltaPips;         
        
        priceSL = currentPrice + distanBase*GetPipValue();
               
        priceTP = currentPrice - factor*distanBase*GetPipValue();        
      }
      Comment("PRE_4 Digits= "+Digits+"\n currentPrice:"+currentPrice+" priceSL="+priceSL +" priceTP:"+ priceTP +" basePriceHigh:"+ priceHigh +" basePriceLow:"+ priceLow+" distanBase: "+ distanBase);
       return;
   }else if(STOP_LOST_TYPE == BASE_PRICE) // Default Base_price
   {
     double basePrice = 0;
      if(orderType == OP_BUYLIMIT || orderType == OP_BUY)
      {
        // Distance SL 
         distanBase = GetPipsFrom2Price(priceLow,currentPrice) + deltaPips;         
        
        priceSL = currentPrice - distanBase*GetPipValue();
        
        priceTP = currentPrice + factor*distanBase*GetPipValue();
        
      }else if(orderType == OP_SELLLIMIT || orderType == OP_SELL)
      {       
        // Distance SL 
         distanBase = GetPipsFrom2Price(priceHigh,currentPrice) + deltaPips;         
        
        priceSL = currentPrice + distanBase*GetPipValue();
        
        
        priceTP = currentPrice - factor*distanBase*GetPipValue();
      }
      
      Comment("BASE_PRICE Digits= "+Digits+"\n currentPrice:"+currentPrice+" priceSL="+priceSL +" priceTP:"+ priceTP +" basePriceHigh:"+ priceHigh +" basePriceLow:"+ priceLow+" distanBase: "+ distanBase);
       return;
   }  
}

void SetTPSL(){

   if(ticketOpen < 0) 
   return;
  
  if(!OrderSelect(ticketOpen,SELECT_BY_TICKET,MODE_TRADES)) return;
  
  if(OrderStopLoss()!= 0)
  {
   // Print("Can't set SL");
    return;
  }
  
  double stopLossPrice = 0;
  double takeProfitPrice = 0;
  double delta = 0;
    
  if(OrderType() == OP_SELL)
  {  
      delta = GetPipsFrom2Price(OrderOpenPrice(), basePriceLow)*GetPipValue();
      delta = OrderOpenPrice() < basePriceLow? -delta: delta; 
      stopLossPrice =  basePriceHigh + delta;
         
      takeProfitPrice = OrderOpenPrice() - winRiskFactor*GetPipsFrom2Price(basePriceHigh,basePriceLow)*GetPipValue();      
  }else if(OrderType() == OP_BUY)
  {  
      delta = GetPipsFrom2Price(OrderOpenPrice(), basePriceHigh)*GetPipValue();
      delta = OrderOpenPrice() > basePriceHigh? delta: -delta;
      stopLossPrice =  basePriceLow + delta;
      takeProfitPrice = OrderOpenPrice() + winRiskFactor*GetPipsFrom2Price(basePriceHigh,basePriceLow)*GetPipValue();
  }
  
  int ticket = OrderModify(OrderTicket(),OrderOpenPrice(),stopLossPrice,takeProfitPrice,NULL,NULL);
  if(ticket < 0)
  {
    Print(Symbol()+" - SetTPSLError: "+ GetLastError());
  }
}

static datetime today;
bool IsNewDay()
{
   if (today != iTime (_Symbol, PERIOD_D1, 0))
   {
      today = iTime (_Symbol, PERIOD_D1, 0);
      return true;
   }
   return false;   
}

void CheckBasePrice()
{
   if(IsNewDay())
   {
      basePriceHigh = 0;
      basePriceLow = 0;  
      startBaseIndex = 0; 
      breakOutIndex = 0;
   }  
   
   if(basePriceHigh <=0 || basePriceLow<= 0)
   {  
      startBaseIndex = GetStartDayIndex(OPEN_ORDER_ON_TIME_FRAME);     
      GetBasePriceByDay(startBaseIndex,OPEN_ORDER_ON_TIME_FRAME,BASE_CANDLES);     
   }     
   
}


ENUM_ORDER_TYPE GetOrderType()
{   
   ENUM_ORDER_TYPE orderType = OP_BUYSTOP;
   string comment ="";  
   double fibo = 0;
         
    if(basePriceHigh <= 0 || basePriceLow <= 0)
    {
       Comment("Waiting for break out candle: basePriceHigh:"+basePriceLow+" <= 0 ||basePriceLow: "+basePriceLow+"  <= 0 ||Ask: "+Ask+" >= basePriceLow && Bid <= basePriceHigh");
       return orderType;
    }         
  
   ENUM_BREAK_OUT_TYPE breakOutType = GetBreakOutType(OPEN_ORDER_ON_TIME_FRAME,basePriceHigh, basePriceLow);
  
  if(off_open_order)
  {
   Comment("off_open_order");
    return orderType;
  }
     
  if(breakOutIndex > MAX_BREAK_OUNT_INDEX)
  { 
     Comment("No break out to oenpen order breakOutIndex: "+ breakOutIndex +" > MAX_BREAK_OUNT_INDEX: "+ MAX_BREAK_OUNT_INDEX);
    return orderType;  
  
  }
     
   if(breakOutType == NONE) 
   {
     Comment("No break out candle can't open new order");
     return orderType;   
   } 
   
    comment ="Waitting for signal open order";
    
   // BUY
   if(breakOutType == LONG)
   {
      if(IS_OPEN_BY_MARKET)
      {
        // Open by Fibo
         if(FIBO > 0)
         {
            fibo = GetFiboLevel(breakOutHighPrice,breakOutLowPrice, FIBO, FB_DOWN);         
            if(Ask <= fibo)
            {
               orderType = OP_BUY;
               comment+="OP_BUY";
            }
         }
         else
         {
            orderType = OP_BUY;
            comment="OP_BUY";
         }   
      }else
      {
        orderType = OP_BUYLIMIT;     
        comment="OP_BUYLIMIT";
      }   
   }
   // SELL
   else if(breakOutType == SHORT)
   {      
      if(IS_OPEN_BY_MARKET)
      {
         if(FIBO > 0)
         {
            fibo = GetFiboLevel(breakOutHighPrice,breakOutLowPrice, FIBO, FB_UP);         
            if(Ask <= fibo)
            {
               orderType = OP_SELL;
               comment="OP_SELL";
            }
         }
         else
         {
            orderType = OP_SELL;
             comment="OP_SELL";
         }
      }
      else
      {
        orderType = OP_SELLLIMIT;
        comment="OP_SELLLIMIT";
      }
   } 
   
    if(PositionType != LONG_And_SHORT)
    {
       if(PositionType == LONG_ONLY && (orderType == OP_SELL || orderType == OP_SELLLIMIT))
       {
         orderType = OP_BUYSTOP;
          comment="NONE";
       } 
       else if(PositionType == SHORT_ONLY && (orderType == OP_BUY || orderType == OP_BUYLIMIT))
       {
         orderType = OP_BUYSTOP;
          comment="NONE";
       } 
    }
    
      
  Comment("breakOutLowPrice: "+breakOutLowPrice+" breakOutIndex: " +breakOutIndex+ "\n basePriceHigh: "+ basePriceHigh +" basePriceLow: "+ basePriceLow + "\ncomment:" + comment); 
  
  return orderType;   
}

ENUM_BREAK_OUT_TYPE GetBreakOutType(ENUM_TIMEFRAMES timeFrame,string baseHighPrice, double baseLowPrice)
{
   ENUM_BREAK_OUT_TYPE trend = NONE;
   // Reset breakout index
   breakOutIndex = 0;
   double close = 0;
   double open = 0;  
   double lowPrice;
   double highPrice;     
      
   while(true)
    {       
       breakOutIndex ++;   
         
       close = iClose(_Symbol,timeFrame,breakOutIndex);
       open = iOpen(_Symbol,timeFrame,breakOutIndex);      
       
       lowPrice = iLow(_Symbol,timeFrame,breakOutIndex);
       highPrice = iHigh(_Symbol,timeFrame,breakOutIndex);
         
         // Break out Up
        if( close > open && close > baseHighPrice && open  < baseHighPrice && open > baseLowPrice)// && lowPrice > baseLowPrice)
        {  
          breakOutHighPrice = highPrice;
          breakOutLowPrice = lowPrice;
          
          trend = LONG;          
          DrawBreakOut(breakOutIndex, 1);   
                 
        }      // Break out down
         else if(close < open && close < baseLowPrice &&  open > baseLowPrice && open <  baseHighPrice)// && highPrice < baseHighPrice)
        { 
          trend = SHORT;
          breakOutHighPrice = highPrice;
          breakOutLowPrice = lowPrice;         
          DrawBreakOut(breakOutIndex, -1);          
        } 
        
       if(trend != NONE)
       { 
          break;
       }
       if(breakOutIndex > MAX_BREAK_OUNT_INDEX)
       { 
          breakOutIndex = 0;
          break;
       }
   }       
   
   return trend;
}

void GetBasePriceByDay(int startBaseIndex, ENUM_TIMEFRAMES timeFrame, int baseCounter)
{    
      int endBaseIndex = startBaseIndex -  baseCounter + 1;      
      basePriceHigh = 0;
      basePriceLow = 0;      
      
      if(endBaseIndex > 0)
      {      
         int indexHigh = iHighest(_Symbol,timeFrame,MODE_HIGH,baseCounter,endBaseIndex);      
         int indexLow =  iLowest(_Symbol,timeFrame,MODE_LOW,baseCounter,endBaseIndex);
     
         basePriceHigh = iHigh(_Symbol,timeFrame,indexHigh);
         basePriceLow = iLow(_Symbol,timeFrame,indexLow);
         
         DrawBox(iTime(_Symbol,timeFrame,startBaseIndex),basePriceHigh,iTime(_Symbol,timeFrame,endBaseIndex),basePriceLow);
      }
      
      Comment("StartBaseIndex:"+startBaseIndex+" EndBaseIndex:"+endBaseIndex+ "\nbasePriceHigh: "+ basePriceHigh +" basePriceLow: "+ basePriceLow); 
}


// Lay ve cay nen H1 bat dau cua ngay 0: ngay hien tai 
int GetStartDayIndex(ENUM_TIMEFRAMES timeFrame)
{    
   int startIndex = 0;   
   while(true)
   {      
        if(TimeHour(iTime(_Symbol,timeFrame,startIndex)) < TimeHour(iTime(_Symbol,timeFrame,startIndex + 1)))
        { 
         break;
        }
      startIndex++;
   }
   
   Comment("startIndex: "+ startIndex +" timeFrame: "+ timeFrame);  
   return startIndex;
 }

int GetOpeningTicket()
{
  int orderTicket = -1;
  for(int i=0;i<OrdersTotal();i++)
      {
         if(!OrderSelect(i,SELECT_BY_POS, MODE_TRADES))
          continue;
          
          if(OrderSymbol()!= _Symbol)
            continue;                     
            orderTicket = OrderTicket();                          
      }
  return orderTicket;
}


void Clean()
{
   // Remove old data
   if(ticketOpen > 0)
   {
    // Delete all arrow
     for( int i=ObjectsTotal()-1;i>=0;i--)
     {
        ObjectDelete(ObjectName(i));
     }
   }
}


//+------------------------------------------------------------------+
//| Get StopTradingByWinRiskToday                                    |
//| minWinPercent per day                                            |
//+------------------------------------------------------------------+
bool IsStopTrading()
{  
   if(MAX_ORDER_PER_DAY > 0 && OrdersHistoryTotal() > 0)
   { 
        int totals = CountOrderOfDayByType(0); 
        // If has win stop| If has loss > max open stop           
        if(totals >= MAX_ORDER_PER_DAY )
         {
           Comment("StopTrading total trading in day = "+ (totals) +" > MAX_ORDER_PER_DAY:= "+  MAX_ORDER_PER_DAY);           
          return true;     
        }
    }
        
   return false;
}


//Type -1 > Profit <0
// Type 1 > Profit >0
int CountOrderOfDayByType(int typeCount)
{  
 if(OrdersHistoryTotal() <= 0) 
  return 0;
  
  int year = 0;
  int month = 0;
  int day = 0; 
  int countOrder = 0;
  int index = 0;
  
  int closed_orders=0;
   datetime today_midnight=TimeCurrent()-(TimeCurrent()%(PERIOD_D1*60));
   for(int x=OrdersHistoryTotal()-1; x>=0; x--)
   {
      if(!OrderSelect(x,SELECT_BY_POS,MODE_HISTORY))
       continue;
      
      if(OrderCloseTime()>=today_midnight && OrderSymbol() == _Symbol)
      {
         failOrderType = OrderType();             
          // Loss
           if(typeCount == -1)
           {
                if(failOrderType == OP_BUY && OrderOpenPrice() > OrderClosePrice()
                || failOrderType == OP_SELL && OrderOpenPrice() < OrderClosePrice())
               {                  
                  countOrder++;
               }
           }// Win
           else if(typeCount == 1)
           {
              if(failOrderType == OP_BUY && OrderOpenPrice() < OrderClosePrice()
               || failOrderType == OP_SELL && OrderOpenPrice() > OrderClosePrice())
               {                  
                  countOrder++;
               }
           }else
           {
               if(failOrderType == OP_BUY || failOrderType == OP_SELL || failOrderType == OP_BUYLIMIT || failOrderType == OP_SELLLIMIT )
               {                  
                  countOrder++;
               }
           }
      }
      else if(OrderCloseTime() < today_midnight)
      {
         break;
      }
    }
  
    //Print("countOrder: "+ countOrder);
    return countOrder;
}

//+------------------------------------------------------------------+
//| Get spread symbol                                                |
//+------------------------------------------------------------------+
double GetSpread()
{
double spred = MarketInfo(_Symbol,MODE_SPREAD)/10;
 //  Print("Spread: "+ spred);
   return spred;
}

//+------------------------------------------------------------------+
//| Get pips value                                                   |
//+------------------------------------------------------------------+
double GetPipValue()
{
//  return GetPipValueNew();
  
 double PointValue =0;

  if (MarketInfo(_Symbol, MODE_POINT) == 0.00001) PointValue = 0.0001;
         else if (MarketInfo(_Symbol, MODE_POINT) == 0.001) PointValue = 0.01;
         else PointValue = MarketInfo(_Symbol, MODE_POINT);
  return  PointValue;
}

datetime NewCandleTime;// = TimeCurrent();
bool IsNewCandle(ENUM_TIMEFRAMES timeFrame){
   if(NewCandleTime == iTime(Symbol(),timeFrame,0)) 
   return false;
   else{
      NewCandleTime=iTime(Symbol(),timeFrame,0);
      return true;
   }
}

//+------------------------------------------------------------------+
//| Get pips bettwen 2 prices                                        |
//+------------------------------------------------------------------+
int GetPipsFrom2Price(double priceHigh, double priceLow)
{
   //return GetPipsFrom2PriceNew(priceHigh, priceLow);
   if(priceHigh == 0 || priceLow == 0) return 0;  
   return  MathRound(MathAbs(NormalizeDouble(priceHigh - priceLow,Digits)/(Point*10)));
}

//+------------------------------------------------------------------+
//| Convert Atr to pips                                              |
//+------------------------------------------------------------------+
int GetAtrToPipsByPeriod(int timeFrame , int period, int shift)
{
   int pips = 0;
   double atr = iATR(_Symbol, timeFrame,period,shift);
   int digist = MarketInfo(_Symbol, MODE_DIGITS);    
   double pows = pow(10,digist-1*(Digits==3 || Digits==5));
   pips = MathRound(atr*pows);
   return pips; 
} 

//+------------------------------------------------------------------+
//| Get drawdown balance                                              |
//+------------------------------------------------------------------+
double DrawDownBalance()
{ 
// Balance drawdowns
   double balance = AccountBalance();
   double enquity = AccountEquity();
   double drawdown = EMPTY_VALUE;
   double increaseBlance = EMPTY_VALUE;  
   //Calculate increase balance
   increaseBlance = MathAbs(AccountEquity() - AccountBalance())/AccountBalance();
   // Calculate DrawDown  
   drawdown = MathAbs(AccountEquity() - AccountBalance())/AccountEquity();
   
   return NormalizeDouble(drawdown,2);
}


double GetLotSizeOrder(double distance,double loss){
   double lotSize = 0;   
   if(distance == 0){
   Comment("Lotsize zero - distance: "+ distance);
   return 0;
   }   
     
   lotSize = loss/(10*distance);
    
   
   if(lotSize <0.01) {
    Comment("Lotsize < 0.01 - distance: "+ distance );
     lotSize = 0;
   }
   
   lotSize = NormalizeDouble(lotSize,2); 
   return lotSize;
}

double GetMaxR(double draw_down, int number_orders)
{
   return AccountBalance()*draw_down/(100* number_orders); 
}


//+------------------------------------------------------------------+
//|Get market trend                                                  |
//+------------------------------------------------------------------+
double GetFiboLevel( double highPrice, double lowPrice, double lev, ENUM_FIBO_TYPE fiboType ){

   double ling = MathAbs( highPrice - lowPrice);
   double pLev = ( ling / 100 ) * lev;
   
   return ( fiboType == FB_DOWN ) ? NormalizeDouble( highPrice - pLev, Digits ) : NormalizeDouble( lowPrice + pLev, Digits) ;
}

double GetProfit(){
double totalProfits=0;   
  
      if(OrderSelect(ticketOpen,SELECT_BY_TICKET, MODE_TRADES))
      {              
       totalProfits = (OrderProfit()+OrderSwap()+OrderCommission());                      
      }
   
  Comment("Profit: "+ totalProfits); 
return totalProfits;
}

double CalAvgPrice(double highPrice, double lowPrice){
return (highPrice + lowPrice)/2;
}

double GetAvgAtrD(int shift)
{
 //  return GetAtrToPipsByPeriod(PERIOD_D1,5,1);
   return GetPipsFrom2Price(iHigh(_Symbol,PERIOD_D1,shift),iLow(_Symbol,PERIOD_D1,shift));
}

// Type 1 breakout up
// Type -1 breakout down
void DrawBreakOut(int index, int type)
{   
   if(off_Draw)
   return;
 
   string name = "ARW_";
   if(type ==1)
   {
      name +="UP_"+ iTime(_Symbol,OPEN_ORDER_ON_TIME_FRAME,index);
   }else
   {
    name +="DOWN_"+ iTime(_Symbol,OPEN_ORDER_ON_TIME_FRAME,index);
   }   
   
   double value = type ==1? iHigh(_Symbol,OPEN_ORDER_ON_TIME_FRAME,index) + 5*GetPipValue(): iLow(_Symbol,OPEN_ORDER_ON_TIME_FRAME,index) - 5*GetPipValue();
   color cl = type ==1? Blue: Red;
   
   ObjectCreate(name, OBJ_ARROW, 0, Time[index],value); //draw an up arrow
   ObjectSet(name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSet(name, OBJPROP_ARROWCODE, type ==1? SYMBOL_ARROWUP: SYMBOL_ARROWDOWN);
   ObjectSet(name, OBJPROP_COLOR,cl);
}



void DrawBox(datetime time1, double price1, datetime time2, double price2)
{
   if(off_Draw)
   return;
   
   string name = "Rectangle_"+time1;
   ObjectCreate(name, OBJ_RECTANGLE, 0, time1, price1, time2, price2); 
   ObjectSet(name, OBJPROP_COLOR, Blue);
   ObjectSet(name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSet(name, OBJPROP_WIDTH, 2);
}

// Thuat toan xac dinh trend theo base price 
// Base 3 day lien tiep

double GetPipValueNew()
{
   double pip =Point ;  
  if(Digits == 3 || Digits == 5)
    pip *=10;
    return pip;
}

//+------------------------------------------------------------------+
//| Get pips bettwen 2 prices                                        |
//+------------------------------------------------------------------+
int GetPipsFrom2PriceNew(double priceHigh, double priceLow)
{
   if(priceHigh == 0 || priceLow == 0) return 0;  
   return  MathRound(MathAbs(NormalizeDouble(priceHigh - priceLow,Digits)/GetPipValue()));
}
