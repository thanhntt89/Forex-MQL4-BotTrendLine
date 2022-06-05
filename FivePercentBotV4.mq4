//+------------------------------------------------------------------+
//|                                                        robot.mq4 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//| 
//+------------------------------------------------------------------+
#property strict
#property description "BOT 5 PERCENT BOT v.4.0"
#property description "Copy right (C) by SHLFOREX TEAM"
#property description "Develop by Nguyen Tat Thanh"
#property description "Mobile: 098 664 8910"
#property description "====Ha Noi03-2020==="
#define SLIPPAGE              3

enum ENUM_STOP_LOST_TYPE{BASE_PRICE=0,MID_BASE_PRICE, PRE_H4};
enum ENUM_POSITION_TYPE {LONG_ONLY, SHORT_ONLY, LONG_And_SHORT};
enum ENUM_TREND_TYPE {NONE,LONG,SHORT};
ENUM_TIMEFRAMES OPEN_ORDER_ON_TIME_FRAME = PERIOD_H1;//Trading time frame

input string SettingPosition="";//"==>>Setting position<=="
input ENUM_POSITION_TYPE PositionType = LONG_And_SHORT;//Positions
input string SettingRiskManagement="";//"==>>Setting risk management<=="
input double MAX_RISK_PER_TRADE = 20;//Max risk per trade(R$)

input string SettingBreakEvent ="";//"==>>Setting break event<=="
input bool IS_SET_BREAK_EVENT = true;// Set break event (TRUE)
input double Target_WinRisk=5;//Close all trade when target reacher factor R
input bool IS_BREAK_EVENT_BY_CANDLE_PARTTEN = true;//Close one trade when break event by candle partten

string SetingTimeForTrading = "";// "==>>Setting time for trading<=="
int START_TIME_TRADING = 8;//Start time(0-23)H
int END_TIME_TRADING = 20; //End time(0-23)H

string SetingBasePrice= "";// "==>>Setting calculate base price<=="
int BASE_CANDLES = 8;//Range candle (number) 

input string SetingTradingInfo = "";// "==>>Setting trading<=="
input bool IS_OPEN_BY_MARKET = true;//Open order type (Market|Limmit)( true| Market - False| Limmit)

input double DEFAULT_WIN_RISK_FACTOR = 1;//Default win risk factor F=TP/SL
input double FIBO = 23.8;//Open order in fibo of candle(1-100) 
int MAX_BREAK_OUNT_INDEX = 3;//Candle break out to open order (after that cancel order) 

input string SettingStoplost="";//"==>>Setting stop loss<=="
input ENUM_STOP_LOST_TYPE STOP_LOST_TYPE = MID_BASE_PRICE;// Stoploss type 
double DELTA_STOP_LOST = 5;// Delta stoplost pips

input string SettingDevelop="";//"==>>Setting view base and break out<=="
input bool off_base = false;// Off base price
input bool off_break_out = false;//Off Break out
input bool off_pinbar = false;// Off pinbar
input bool off_candle_partten = false;// Off candle partten
input bool off_open_order = false;// Off open order

string SetingDailyTrading = "";// "==>>Setting daily trading<==";
bool ReverseFialOrder = false;// Reverse order type when fail
int MAX_ORDER_PER_DAY = 1;// Max order perday (0-N)(0 unlimited)

string SetingAutoRisk= "";// "==>>Setting auto calculate risk per trade<==";
bool AUTO_LOT_SIZE = false;// Auto calculate 
double MAX_RISK_PER_TRADE_PERCENT = 0.5;// Max risk per trade percent (R%)

double TOTAL_LOTS= 0.5;// Max total lots size

double min_stop_loss = 20; // Min stop loss

double min_stop_loss_G = 40;

int MaxValue = 2147483647;
int MagicNumber =0;
double price = 0;
double priceSL = 0;
double priceTP = 0;  

double candleParttenHighPrice =0;
double candleParttenLowPrice =0;

double minStopLevel = 0;
color clColor=clrRed;
double LotSizeStart = 0;
string firstOrderComment ="F5.4.0.0";

double baseHighPrice = 0;
double baseLowPrice = 0;
double breakOutHighPrice = 0;
double breakOutLowPrice =0;

int breakOutIndex = -1;
int startBaseIndex = 0;

ENUM_ORDER_TYPE failOrderType = OP_BUYLIMIT;
ENUM_ORDER_TYPE currentOrderType = OP_BUYSTOP;
double currentProfit = 0;

double winRiskFactor = 0;

enum ENUM_FIBO_TYPE{FB_UP, FB_DOWN};
int ticketOpen = -1;

double maxProfit = 0;
double minProfit = 0;
string message = "";
string lblTrend ="trend";
string lblTrendH4 ="trendH4";
string lblMessage ="message";
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
   // ObDeleteObjects();
    EventKillTimer();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//--------------------------------------------------------------------  
  if(Year() > 2021)
  {
   CreateComment(lblMessage,"End time: 2021 must update new ");
   return;
  } 
  
  AutoTrade(); 
}
//+------------------------------------------------------------------+

void OnTimer(){
 if(Year() > 2021)
  {
   CreateComment(lblMessage,"End time: 2021 must update new ");
   return;
  }
}

void AutoTrade()
{ 
   if(IsTradeAllowed() == false) 
   return;   
   
   // Default pre candle  
   CheckBasePrice(); 
  
   ticketOpen = GetOpeningTicket(currentOrderType, currentProfit);
   
   BreakEvent();    
   
   // Close limmit-stop order
   if(!IS_OPEN_BY_MARKET)
     CloseTrade();   
   
    if(GetDailyProfit() >= Target_WinRisk*MAX_RISK_PER_TRADE && Target_WinRisk > 0)
   {   
       CreateComment(lblMessage,"STOP_TRADING_TOTAL DAILY PROFIT: "+ GetDailyProfit() + ">= MAX_PROFIT: "+ Target_WinRisk*MAX_RISK_PER_TRADE);
       return;
   }
   
   if(GetTotalLots() >= TOTAL_LOTS)
   {
     CreateComment(lblMessage,"STOP_TRADING_TOTAL LOTS SIZE: "+ GetTotalLots()+ ">= MAX_LOTS: "+ TOTAL_LOTS);
     return;
   }
   
    if(IsStopTrading()) 
     return;
   if(!IsTradingTime()) 
   return; 
    OpenFirtOrder();      
}

// Check if there is a new bar
bool IsNewBar()   
{        
      static datetime RegBarTime=0;
      datetime ThisBarTime = Time[0];

      if (ThisBarTime == RegBarTime)
      {
         return(false);
      }
      else
      {
         RegBarTime = ThisBarTime;
         return(true);
      }
}  

bool IsTradingTime()
{
   if(END_TIME_TRADING <= 0 || START_TIME_TRADING <= 0)
   return true;
  
   int hour = Hour();
   
   if(hour >= END_TIME_TRADING || hour < START_TIME_TRADING ) 
    {
      CreateComment(lblMessage,"Stop Trading Time :"+hour +"H");
     return false;  
    }
   return true;
}

void BreakEvent()
{   
    if(!IS_SET_BREAK_EVENT)
    {
      return;
    }
       
    BreakEventByCandleParrten();
    
    double profitTarget = Target_WinRisk*MAX_RISK_PER_TRADE;  
    double currentProfit = GetTotalProfit();
    double dailyProfit =  GetDailyProfit();
    double totalProfit =  currentProfit + dailyProfit;
       
     if(currentProfit > 0 && currentProfit > maxProfit)
     {
      maxProfit = currentProfit;
     }else if(currentProfit < 0 && currentProfit < minProfit)
     {
      minProfit = currentProfit;
     }
     
    if(totalProfit >= profitTarget && Target_WinRisk > 0)
    {
      //CreateComment(lblMessage,"Hit target Closed all trade");
      CloseAllTrade();     
    }    
     
     if(OrdersTotal() == 0 && (maxProfit!=0 || minProfit!=0))
     {
       WriteToFile(maxProfit,minProfit);
       maxProfit = 0;
       minProfit = 0;       
     }      
}

void BreakEventByCandleParrten()
{
      // Break event by candle partten   
    if(IS_BREAK_EVENT_BY_CANDLE_PARTTEN)
    {
        ENUM_TREND_TYPE trend =  GetCandlePartten(OPEN_ORDER_ON_TIME_FRAME);  
         
        if(!OrderSelect(ticketOpen,SELECT_BY_TICKET,MODE_TRADES)) 
         return;
          
       if(currentProfit > 0 && 
       (trend == LONG && OrderType() == OP_SELL || 
       trend == SHORT && OrderType() == OP_BUY))
       {         
         if(OrderType() == OP_SELL)         
            OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), SLIPPAGE, clrGreen);    
         else if(OrderType() == OP_SELL)         
           OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), SLIPPAGE, clrRed);             
       } 
    }

}

void CloseAllTrade()
{
  int totalOrders = OrdersTotal();
//Update the exchange rates before closing the orders
   RefreshRates();
   
  for(int i=0;i<totalOrders;i++)
    {
      if(!OrderSelect(i,SELECT_BY_POS, MODE_TRADES))
        continue;
        
        switch(OrderType())
      {
         case OP_BUY:        
            OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), SLIPPAGE, clrGreen);                
            break;
         case OP_SELL:          
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
    }
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
      CreateComment(lblMessage,"Order opened: "+ ticketOpen);
      return;
   } 
    
   string comment = firstOrderComment;
    
    candleParttenHighPrice = 0;
    candleParttenLowPrice = 0;
    breakOutHighPrice = 0;
    breakOutLowPrice = 0;
    price = 0;
    priceSL =0;
    priceTP =0;
    
   ENUM_ORDER_TYPE signalTrade = GetOrderType();

  if(off_open_order)
  {
   CreateComment(lblMessage,"off_open_order");
    return;
  }
  
   if(signalTrade == OP_BUYSTOP || Minute() < 1)
   {   
    Print("Stoping open order signalTrade = OP_BUYSTOP");
    return;
   }  
    
    if(signalTrade == OP_BUYLIMIT)
    {      
      if(candleParttenHighPrice >0 && candleParttenLowPrice >0)
       price = GetFiboLevel(candleParttenHighPrice,candleParttenLowPrice,FIBO,FB_DOWN);      
      else if(breakOutHighPrice >0 && breakOutLowPrice >0)      
       price = GetFiboLevel(breakOutHighPrice,breakOutLowPrice,FIBO,FB_DOWN);   
         
      comment +="\nOP_BUYLIMIT";
    }else if(signalTrade == OP_SELLLIMIT)
    {     
       if(candleParttenHighPrice >0 && candleParttenLowPrice >0)
        price = GetFiboLevel(candleParttenHighPrice,candleParttenLowPrice,FIBO,FB_UP);   
        else if(breakOutHighPrice >0 && breakOutLowPrice >0)     
         price = GetFiboLevel(breakOutHighPrice,breakOutLowPrice,FIBO,FB_UP);   
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
  
   if(breakOutHighPrice != 0 && breakOutLowPrice != 0)
   {      
     //Calculate stoploss
    CalculateSL(signalTrade,winRiskFactor,price,DELTA_STOP_LOST,baseHighPrice,baseLowPrice,priceSL,priceTP);
   } else if(candleParttenHighPrice!=0 && candleParttenLowPrice != 0)
   {
     CalculateSLByCandlePartten(signalTrade,winRiskFactor,price,DELTA_STOP_LOST,candleParttenHighPrice,candleParttenLowPrice,priceSL,priceTP);
   }
  
   double distanceR = GetPipsFrom2Price(price,priceSL);
       
   // Lot trade
   double lost_trade = MAX_RISK_PER_TRADE;
   
   if(AUTO_LOT_SIZE)
   {
    lost_trade =  AccountBalance()*MAX_RISK_PER_TRADE_PERCENT/100;
   }
     
   // Calculate lot size             
   LotSizeStart = GetLotSizeOrder(distanceR,lost_trade);
 
  lost_trade = TOTAL_LOTS - GetTotalLots();
  if(LotSizeStart > lost_trade)
   {
     CreateComment(lblMessage,"LotSize over max lots - OrderLotSize:"+LotSizeStart +" > Detal = (Total("+TOTAL_LOTS+") - Current("+GetTotalLots()+")= "+ lost_trade +" - MaxTotalLots:"+ TOTAL_LOTS);
    return;
   }
 
  int slipPage = SLIPPAGE;
  
  //preparing slippage for 5 digit broker
  if (Digits == 3 || Digits == 5) 
  slipPage *= 10;
     
  if(LotSizeStart < 0.01 ) 
  {
     CreateComment(lblMessage,"Cancel open order: LotSizeStart ="+ LotSizeStart +" < 0.01\n OpenPrice:"+ price+" Stop loss price:"+ priceSL+" SL:="+distanceR+" (pips) - PipsValue: "+ SymbolPointValue(_Symbol));
     return;
  }
  
  RefreshRates();
  // Reset ticket
  
  int ticket = OrderSend(_Symbol,signalTrade,LotSizeStart,price,slipPage,priceSL,priceTP,firstOrderComment,MagicNumber,0,clColor);  
  
  if(ticket<0)
  {      
       CreateComment(lblMessage,"Error: ", GetLastError()+" slipPage: "+slipPage+" price: "+ Ask+" - LotSizeStart: "+ LotSizeStart +" priceSL: " + priceSL +" priceTP: " + priceTP);
  } else
  {
   Print(_Symbol+" - OPEN Sucssess ticketOpen: "+ticketOpen+"\n price: "+ price+" - LotSizeStart: "+ LotSizeStart +" priceSL: " + priceSL +" priceTP: " + priceTP);
  }  
}

// Set SL_TP
void CalculateSL(ENUM_ORDER_TYPE orderType,double factor,double currentPrice,double deltaPips, double priceHigh,double priceLow,double& stopLossPrice, double& takeProfitPrice)
{ 
   if(currentPrice <= 0)
   {
      CreateComment(lblMessage,"Can't set Stop loss - Takeprofit => Price open order is zero");
      return;
   }
   
  double distanBase = 0;   
  string CurrencyBase = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
  string iProfitCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
  distanBase = min_stop_loss;
  
  if(_Symbol == "GBPUSD" || _Symbol == "GBPUSDx")
  {
      distanBase = 25;
  }
  else  
  { 
      if((CurrencyBase == "GBP" || iProfitCurrency == "GBP"))
      distanBase = min_stop_loss_G;
  }
           
   if(STOP_LOST_TYPE == MID_BASE_PRICE)
   {
      double midPrice = CalAvgPrice(priceHigh,priceLow);
      
         // Distance SL 
      distanBase = GetPipsFrom2Price(midPrice,currentPrice) + deltaPips;
                 
      if(orderType == OP_BUYLIMIT || orderType == OP_BUY)
      {
        stopLossPrice = currentPrice - distanBase *GetPipValue();
                
        takeProfitPrice = currentPrice + factor*distanBase*GetPipValue();
        
      }else if(orderType == OP_SELLLIMIT || orderType == OP_SELL)
      {  
        stopLossPrice = currentPrice + distanBase*GetPipValue();
        
        takeProfitPrice = currentPrice - factor*distanBase*GetPipValue();
      }
      
     CreateComment(lblMessage,"MID_BASE_PRICE Digits= "+Digits+"\n currentPrice:"+currentPrice+" priceSL="+priceSL +" priceTP:"+ priceTP +" basePriceHigh:"+ priceHigh +" basePriceLow:"+ priceLow+ " midPrice: "+ midPrice+" distanBase: "+ distanBase);
      
      return;
      
   }else if(STOP_LOST_TYPE == PRE_H4)
   {
      double h4Price = 0;      
     if(orderType == OP_BUYLIMIT || orderType == OP_BUY)
      {
        h4Price = iLow(_Symbol,PERIOD_H4,1);
        
         // Distance SL 
        distanBase = GetPipsFrom2Price(h4Price,currentPrice) + deltaPips;         
         
        stopLossPrice = currentPrice  - distanBase*GetPipValue();
        
        takeProfitPrice = currentPrice + factor*distanBase*GetPipValue();
        
      }else if(orderType == OP_SELLLIMIT || orderType == OP_SELL)
      {
        h4Price = iHigh(_Symbol,PERIOD_H4,1);
         // Distance SL 
        distanBase = GetPipsFrom2Price(h4Price,currentPrice) + deltaPips;         
        
        stopLossPrice = currentPrice + distanBase*GetPipValue();
               
        takeProfitPrice = currentPrice - factor*distanBase*GetPipValue();        
      }
      CreateComment(lblMessage,"PRE_4 Digits= "+Digits+"\n currentPrice:"+currentPrice+" priceSL="+priceSL +" priceTP:"+ priceTP +" basePriceHigh:"+ priceHigh +" basePriceLow:"+ priceLow+" distanBase: "+ distanBase);
       return;
   }else if(STOP_LOST_TYPE == BASE_PRICE) // Default Base_price
   {
      double basePrice = 0;
      if(orderType == OP_BUYLIMIT || orderType == OP_BUY)
      {
        // Distance SL 
        distanBase = GetPipsFrom2Price(priceLow,currentPrice) + deltaPips;         
        
        stopLossPrice = currentPrice - distanBase*GetPipValue();
        
        takeProfitPrice = currentPrice + factor*distanBase*GetPipValue();
        
      }else if(orderType == OP_SELLLIMIT || orderType == OP_SELL)
      {       
        // Distance SL 
        distanBase = GetPipsFrom2Price(priceHigh,currentPrice) + deltaPips;         
        
        stopLossPrice = currentPrice + distanBase*GetPipValue();        
        
        takeProfitPrice = currentPrice - factor*distanBase*GetPipValue();
      }
      
      CreateComment(lblMessage,"BASE_PRICE Digits= "+Digits+"\n currentPrice:"+currentPrice+" priceSL="+priceSL +" priceTP:"+ priceTP +" basePriceHigh:"+ priceHigh +" basePriceLow:"+ priceLow+" distanBase: "+ distanBase);
       return;
   }  
}

void CalculateSLByCandlePartten(ENUM_ORDER_TYPE orderType,double factor,double currentPrice,double deltaPips, double priceHigh,double priceLow,double& stopLossPrice, double& takeProfitPrice)
{   
  double distanBase = 0;  
  double stopLoss = 0;
  
  string CurrencyBase = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
  string iProfitCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
  stopLoss = min_stop_loss;
  
  if(_Symbol == "GBPUSD" || _Symbol == "GBPUSDx")
  {
      stopLoss = 25;
  }
  else  
  { 
      if((CurrencyBase == "GBP" || iProfitCurrency == "GBP"))
      stopLoss = min_stop_loss_G;
  }
  
   if(currentPrice <= 0)
   {
      CreateComment(lblMessage,"Can't set Stop loss - Takeprofit => Price open order is zero");
      return;
   }
   
    if(orderType == OP_BUYLIMIT || orderType == OP_BUY)
      {
        // Distance SL 
        distanBase = GetPipsFrom2Price(priceLow,currentPrice) + deltaPips;    
        
       if(distanBase < stopLoss)
       {
         distanBase = stopLoss;
       }
        
        stopLossPrice = currentPrice - distanBase*GetPipValue();
        
        takeProfitPrice = currentPrice + factor*distanBase*GetPipValue();
        
      }else if(orderType == OP_SELLLIMIT || orderType == OP_SELL)
      {       
        // Distance SL 
         distanBase = GetPipsFrom2Price(priceHigh,currentPrice) + deltaPips;      
            
        if(distanBase < stopLoss)
       {
          distanBase = stopLoss;
       }        
        
        stopLossPrice = currentPrice + distanBase*GetPipValue();
        takeProfitPrice = currentPrice - factor*distanBase*GetPipValue();
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
      delta = GetPipsFrom2Price(OrderOpenPrice(), baseLowPrice)*GetPipValue();
      delta = OrderOpenPrice() < baseLowPrice? -delta: delta; 
      stopLossPrice =  baseHighPrice + delta;
         
      takeProfitPrice = OrderOpenPrice() - winRiskFactor*GetPipsFrom2Price(baseHighPrice,baseLowPrice)*GetPipValue();      
  }else if(OrderType() == OP_BUY)
  {  
      delta = GetPipsFrom2Price(OrderOpenPrice(), baseHighPrice)*GetPipValue();
      delta = OrderOpenPrice() > baseHighPrice? delta: -delta;
      stopLossPrice =  baseLowPrice + delta;
      takeProfitPrice = OrderOpenPrice() + winRiskFactor*GetPipsFrom2Price(baseHighPrice,baseLowPrice)*GetPipValue();
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
      baseHighPrice = 0;
      baseLowPrice = 0;  
      startBaseIndex = 0; 
      breakOutIndex = 0;
   }  
   
   if(baseHighPrice <=0 || baseLowPrice<= 0)
   {  
      startBaseIndex = GetStartDayIndex(OPEN_ORDER_ON_TIME_FRAME);     
      GetBasePriceByDay(startBaseIndex,OPEN_ORDER_ON_TIME_FRAME,BASE_CANDLES, baseHighPrice, baseLowPrice);     
   }   
}


ENUM_ORDER_TYPE GetOrderType()
{   
   ENUM_ORDER_TYPE orderType = OP_BUYSTOP;
   string comment ="";  
   double fibo = 0;
   double highPrice =0;
   double lowPrice = 0;    
   bool isBreakOut = false;
      
   ENUM_TREND_TYPE trendType = GetPriceAction(baseHighPrice,baseLowPrice,highPrice,lowPrice, isBreakOut);
       
   if(trendType == NONE) 
   {
     CreateComment(lblMessage,"No break out candle can't open new order");
     return orderType;   
   } 
   
    comment ="Waitting for signal open order";
    
   // BUY
   if(trendType == LONG)
   {
      if(IS_OPEN_BY_MARKET)
      {
        // Open by Fibo
         if(FIBO > 0)
         {            
            fibo = GetFiboLevel(highPrice,lowPrice, FIBO, FB_DOWN);         
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
   else if(trendType == SHORT)
   {      
      if(IS_OPEN_BY_MARKET)
      {
         if(FIBO > 0)
         {
            fibo = GetFiboLevel(highPrice,lowPrice, FIBO, FB_UP);         
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
   
    // Not Set Trend open order by breakout
  if(PositionType == LONG_And_SHORT)
  {  
      //If breakout event
      if(!isBreakOut)
      {
            comment="LONG_And_SHORT";
           // Rest order if singal not breakout
             orderType = OP_BUYSTOP;
         } 
   } 
    else
   {
       // Set trend 
       if(PositionType != LONG_And_SHORT)
       {   
          if(PositionType == LONG_ONLY && (orderType == OP_SELL || orderType == OP_SELLLIMIT))
          {
             comment="NONE - PositionType: LONG_ONLY orderType:"+orderType;
             orderType = OP_BUYSTOP;
            
          }  
         else if(PositionType == SHORT_ONLY && (orderType == OP_BUY || orderType == OP_BUYLIMIT))
          {
             comment="NONE - PositionType: SHORT_ONLY orderType:"+orderType;
             orderType = OP_BUYSTOP;
            
          }              
       }
  }
      
  CreateComment(lblMessage,"Comment:" + comment); 
  
  return orderType;   
}

// Get price action
ENUM_TREND_TYPE GetPriceAction(double baseHighPrice, double baseLowPrice,double& highPrice, double& lowPrice,bool& isBreakOut)
{
    ENUM_TREND_TYPE trend = NONE;      
      
    GetMainTrend(baseHighPrice, baseLowPrice);
    
           
    if(baseHighPrice <= 0 || baseLowPrice <= 0)
     {    
       CreateComment(lblMessage,"Waiting for base created");
       return trend;
     }    
           
   isBreakOut = false;
   double openCandleH1 = iOpen(_Symbol,OPEN_ORDER_ON_TIME_FRAME,1);
   double closedCandleH1 = iClose(_Symbol,OPEN_ORDER_ON_TIME_FRAME,1);
   
    if(Hour() >= 9)   
   // Check doji     
   trend = PinbarCandleType(OPEN_ORDER_ON_TIME_FRAME,candleParttenHighPrice, candleParttenLowPrice);
        
   // Check engufing
    if(Hour() >= 10 && trend == NONE)   
   {         
      trend = EngulfingCandleType(OPEN_ORDER_ON_TIME_FRAME,candleParttenHighPrice, candleParttenLowPrice);      
   } 
    
  highPrice = candleParttenHighPrice;
  lowPrice = candleParttenLowPrice;  
         
   if(trend == NONE)   
   {  
     // Late
     trend = GetBreakOutType(OPEN_ORDER_ON_TIME_FRAME,baseHighPrice, baseLowPrice,breakOutIndex, breakOutHighPrice, breakOutLowPrice);
     
     highPrice = breakOutHighPrice;
     lowPrice = breakOutLowPrice;
     isBreakOut = true; 
              
     if(breakOutIndex > MAX_BREAK_OUNT_INDEX)
     { 
       CreateComment(lblMessage,"No break out to oenpen order breakOutIndex: "+ breakOutIndex +" > MAX_BREAK_OUNT_INDEX: "+ MAX_BREAK_OUNT_INDEX);
       
       trend = NONE;    
     }   
   }
   
   return trend;  
}

ENUM_TREND_TYPE GetCandlePartten(ENUM_TIMEFRAMES timeFrame)
{
 ENUM_TREND_TYPE trend = NONE;  
         double highPrice, lowPrice;    
         trend = EngulfingCandleType(timeFrame,highPrice, lowPrice);          
         if(trend == NONE)
         trend = PinbarCandleType(timeFrame,highPrice, lowPrice); 
 return  trend;
}


ENUM_TREND_TYPE GetBreakOutType(ENUM_TIMEFRAMES timeFrame,double baseHighPrice, double baseLowPrice,int& breakOutIndex, double& breakOutHighPrice, double& breakOutLowPrice)
{
   ENUM_TREND_TYPE trend = NONE;
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
        if( close > open && close > baseHighPrice && open  < baseHighPrice && open > baseLowPrice)
        {  
          trend = LONG;                  
          DrawBreakOut(breakOutIndex, 1);   
                 
        }      // Break out down
         else if(close < open && close < baseLowPrice &&  open > baseLowPrice && open <  baseHighPrice)
        { 
          trend = SHORT;                            
          DrawBreakOut(breakOutIndex, -1);          
        } 
        
       if(trend != NONE)
       { 
          breakOutHighPrice = highPrice;
          breakOutLowPrice = lowPrice;   
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

ENUM_TREND_TYPE PinbarCandleType(ENUM_TIMEFRAMES timeFrame, double& candleHighPrice, double& candleLowPrice)
{
   ENUM_TREND_TYPE type = NONE;
 
   double openedPrice = iOpen(_Symbol,timeFrame,1);
   double closedPrice = iClose(_Symbol,timeFrame,1);
   double higPrice = iHigh(_Symbol,timeFrame,1);
   double lowPrice = iLow(_Symbol,timeFrame,1);
   double fiboValue = 35;
   
   double fibo38Down = GetFiboLevel(higPrice,lowPrice,fiboValue,FB_DOWN);
   double fibo38Up =  GetFiboLevel(higPrice,lowPrice,fiboValue,FB_UP);
   
   candleHighPrice =0;
   candleLowPrice = 0;
   string typeString ="";
   // Type: LONG
   if(openedPrice > fibo38Down && closedPrice > fibo38Down)
    {
      typeString="LONG";
      type = LONG;
      if(!off_pinbar)
      DrawPinbar(iTime(_Symbol,timeFrame,1),higPrice,0);
    }
   else if(openedPrice < fibo38Up && closedPrice < fibo38Up)
   {
      typeString="SHORT";
     type = SHORT;
     if(!off_pinbar)
     DrawPinbar(iTime(_Symbol,timeFrame,1),0,lowPrice);
   }
   
   if(type != NONE)
    {
        candleHighPrice = higPrice;
        candleLowPrice = lowPrice;
    }  
    
   CreateComment(lblMessage,"TypeString:"+typeString+" - PinbarCandleType: "+ type +" candleHighPrice: "+ candleHighPrice +" candleLowPrice: "+ candleLowPrice);
            
  return type;
}

ENUM_TREND_TYPE EngulfingCandleType(ENUM_TIMEFRAMES timeFrame, double& candleHighPrice, double& candleLowPrice)
{
   ENUM_TREND_TYPE type = NONE;
   int shift =1;
  
   double openedPrice1 = iOpen(_Symbol,timeFrame,shift);
   double closedPrice1 = iClose(_Symbol,timeFrame,shift);
   double higPrice1 = iHigh(_Symbol,timeFrame,shift);
   double lowPrice1 = iLow(_Symbol,timeFrame,shift);
   double distance1 = GetPipsFrom2Price(openedPrice1,closedPrice1);   
   
   double openedPrice2 = iOpen(_Symbol,timeFrame,shift + 1);
   double closedPrice2 = iClose(_Symbol,timeFrame,shift + 1);
   double higPrice2 = iHigh(_Symbol,timeFrame,shift + 1);
   double lowPrice2 = iLow(_Symbol,timeFrame,shift + 1);
   double distance2 = GetPipsFrom2Price(openedPrice2,closedPrice2);
   
   if( distance2 >= distance1/4 && distance2 <= 2*distance1/3 && lowPrice1 <= lowPrice2 && higPrice1 >= higPrice2)
    {  
      // TH1: LONG
      if(openedPrice1 < closedPrice1 && openedPrice2 > closedPrice2)
      {
            CreateComment(lblMessage,"LONG distance1: "+ distance1 +" distance2: "+ distance2);
            type = LONG;            
            if(!off_candle_partten)
            DrawBox(iTime(_Symbol,timeFrame,shift),higPrice1,iTime(_Symbol,timeFrame,shift+ 1),lowPrice1);
      } 
      // TH2: SHORT 
      else if(openedPrice1 > closedPrice1 && openedPrice2 < closedPrice2)
      {
            CreateComment(lblMessage,"SHORT distance1: "+ distance1 +" distance2: "+ distance2);
            type = SHORT;
            if(!off_candle_partten)
            DrawBox(iTime(_Symbol,timeFrame,shift),higPrice1,iTime(_Symbol,timeFrame,shift+1),lowPrice1);
      } 
      if(type != NONE)
      {
         candleHighPrice = higPrice1;
         candleLowPrice = lowPrice1;
      }  
    }
   
  return type;
}

ENUM_TREND_TYPE PinbarPartten(ENUM_TIMEFRAMES timeframe)
{
ENUM_TREND_TYPE trend = NONE;  
   double higPrice = iHigh(_Symbol,timeframe,1);
   double lowPrice = iLow(_Symbol,timeframe,1);
   
   double fiboDown = GetFiboLevel(higPrice,lowPrice,25,FB_DOWN);
   double fiboUp = GetFiboLevel(higPrice,lowPrice,25,FB_UP);
   double closedPrice = iClose(_Symbol,timeframe,1);
   double openedPrice = iOpen(_Symbol,timeframe,1);
   
   if(IsPinbarValid(timeframe,1))
   {
     if(IsUp(timeframe,1) && openedPrice >= fiboDown || !IsUp(timeframe,1) && closedPrice >= fiboDown)
     {
        trend = LONG;
     }else if(!IsUp(timeframe,1) && openedPrice <= fiboUp || IsUp(timeframe,1) && closedPrice <= fiboUp)
     {
        trend = SHORT;
     }
   }
   
return trend;
}


ENUM_TREND_TYPE GetMainTrend(double baseHighPrice, double baseLowPrice)
{
    ENUM_TREND_TYPE trend = NONE;  
    double highPrice =0, lowPrice = 0;
    string preFix = "D1";
    color  clr = clrGold;
     
     message = preFix +"- NONE Partern";    
  
    trend =  ThreeCandleType(PERIOD_D1,highPrice,lowPrice);  
    if(trend == LONG)
    {
      clr = clrGreen;
      message = preFix+"- Partern Bulish";
    }
    else if(trend == SHORT)
    {
       clr = clrRed;
       message = preFix+"- Partern Bearlish";
    }
    //if(trend != NONE)
    CreateComment(lblTrend,message,35,clr);
    
   preFix = "H4 - NONE Partern";
   clr = clrGold;
   trend = ThreeCandleType(PERIOD_H4,highPrice,lowPrice);
   message = preFix;
   if(trend == LONG)
    {
      clr = clrGreen;
      message += "- Partern Bulish";
    }
    else if(trend == SHORT)
    {
       clr = clrRed;
       message += "- Partern Bearlish";
    }
    //if(trend != NONE)
    CreateComment(lblTrendH4,message,50,clr);
    
 return  trend;
}

ENUM_TREND_TYPE ThreeCandleType(ENUM_TIMEFRAMES timeFrame, double& candleHighPrice, double& candleLowPrice)
{
   ENUM_TREND_TYPE type = NONE;
   int shift =2;
   double openedCandleL, closedCandleL =0, highPriceL, lowPriceL, BodyL;
   double openedCandleR, closedCandleR =0,highPriceR,lowPriceR, BodyR;
   double openedCandleM, closedCandleM =0,highPriceM,lowPriceM, BodyM;
   bool isUpL, isUpR, isUpM;
   
   highPriceL = iHigh(_Symbol,timeFrame,shift + 1);
   lowPriceL = iLow(_Symbol,timeFrame,shift + 1);    
   openedCandleL = iOpen(_Symbol,timeFrame,shift + 1);
   closedCandleL = iClose(_Symbol,timeFrame,shift +1);
   BodyL = CandleBody(openedCandleL,closedCandleL);
   isUpL = IsUp(timeFrame,shift + 1);
   
   highPriceR = iHigh(_Symbol,timeFrame,shift - 1);
   lowPriceR = iLow(_Symbol,timeFrame,shift - 1);
   openedCandleR = iOpen(_Symbol,timeFrame,shift - 1);   
   closedCandleR = iClose(_Symbol,timeFrame,shift -1);
   BodyR = CandleBody(openedCandleR,closedCandleR);
   isUpR = IsUp(timeFrame,shift - 1);
   
   highPriceM = iHigh(_Symbol,timeFrame,shift);
   lowPriceM = iLow(_Symbol,timeFrame,shift); 
   openedCandleM = iOpen(_Symbol,timeFrame,shift);   
   closedCandleM = iClose(_Symbol,timeFrame,shift);
   isUpM = IsUp(timeFrame,shift);
   BodyM = CandleBody(openedCandleM,closedCandleM);
   
   candleHighPrice = iHigh(_Symbol,timeFrame,shift);
   candleLowPrice = iLow(_Symbol,timeFrame,shift);
   
   double min,max;
   
   min = MathMin(lowPriceL,lowPriceM);
   min = MathMin(min,lowPriceR);
   
   max = MathMax(highPriceL,highPriceM);
   max = MathMax(max,highPriceR);     
       
   if(IsPinbarValid(timeFrame,shift))
   {     
      // Trend Buy
     if(BodyL > BodyM && BodyL < BodyR )
     {
      if(!isUpL && isUpR && closedCandleR > openedCandleL)
      {
        //DrawBox(iTime(_Symbol,timeFrame,shift + 1),min,iTime(_Symbol,timeFrame,shift-1),max,clrYellow);
       type = LONG;
      }
       else if(isUpL && !isUpR && closedCandleR < openedCandleL)
       {
         //DrawBox(iTime(_Symbol,timeFrame,shift + 1),max,iTime(_Symbol,timeFrame,shift-1),min, clrRed);
        type = SHORT;       
       }
      }
   }
   return type;
}

double CandleBody(double openPrice, double closedPrice)
{
   return MathAbs(openPrice - closedPrice);
}

bool IsUp(ENUM_TIMEFRAMES timeFrame,int bar)
   {
     return iClose(_Symbol, timeFrame, bar) > iOpen(_Symbol, timeFrame, bar);
   }

//+------------------------------------------------------------------+
bool IsPinbarValid(ENUM_TIMEFRAMES timeFrame, int bar)
{     
   double body      = MathAbs(iClose(_Symbol, timeFrame, bar) - iOpen(_Symbol, timeFrame, bar));
   double lowerWick = LowerWick(timeFrame, bar);
   double upperWick = UpperWick(timeFrame, bar);
   double range     = iHigh(_Symbol, timeFrame, bar) - iLow(_Symbol, timeFrame, bar);
   double tail      = MathMax(lowerWick, upperWick);
   double nose      = MathMin(lowerWick, upperWick); 
   // The body of a pin bar must be no more than 20% of the measurement of the body to the tip of the wick
   
  if (upperWick >= 2 * body || lowerWick >= 2 * body)  
   {
     if (tail > 2 * nose)
      {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
   double UpperWick(ENUM_TIMEFRAMES timeFrame,int bar)
   {
      double upperBody = MathMax(iClose(_Symbol, timeFrame, bar), iOpen(_Symbol, timeFrame, bar));
      return iHigh(_Symbol, timeFrame, bar) - upperBody;
   }
   
   //+------------------------------------------------------------------+
double LowerWick(ENUM_TIMEFRAMES timeFrame, int bar)
{
      double lowerBody = MathMin(iClose(_Symbol, timeFrame, bar), iOpen(_Symbol, timeFrame, bar));
      return lowerBody - iLow(_Symbol, timeFrame, bar);
}
      

void GetBasePriceByDay(int startBaseIndex, ENUM_TIMEFRAMES timeFrame, int baseCounter,double& highPrice, double& lowPrice)
{    
      int endBaseIndex = startBaseIndex -  baseCounter + 1;      
     
      if(endBaseIndex > 0)
      {      
         int indexHigh = iHighest(_Symbol,timeFrame,MODE_HIGH,baseCounter,endBaseIndex);      
         int indexLow =  iLowest(_Symbol,timeFrame,MODE_LOW,baseCounter,endBaseIndex);
     
         highPrice = iHigh(_Symbol,timeFrame,indexHigh);
         lowPrice = iLow(_Symbol,timeFrame,indexLow);
         if(!off_base)
         DrawBox(iTime(_Symbol,timeFrame,startBaseIndex),highPrice,iTime(_Symbol,timeFrame,endBaseIndex),lowPrice);
      }
      
      CreateComment(lblMessage,"StartBaseIndex:"+startBaseIndex+" EndBaseIndex:"+endBaseIndex+ "\nbasePriceHigh: "+ highPrice +" basePriceLow: "+ lowPrice); 
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
   
   CreateComment(lblMessage,"startIndex: "+ startIndex +" timeFrame: "+ timeFrame);  
   return startIndex;
 }

int GetOpeningTicket(ENUM_ORDER_TYPE& orderType,double& orderProfit)
{
  int orderTicket = -1;
  for(int i=0;i<OrdersTotal();i++)
      {
         if(!OrderSelect(i,SELECT_BY_POS, MODE_TRADES))
          continue;
          
          if(OrderSymbol()!= _Symbol)
            continue;                     
            orderTicket = OrderTicket(); 
            orderType = OrderType(); 
            orderProfit += (OrderProfit() + OrderSwap() + OrderCommission());                       
      }
  return orderTicket;
}

//+------------------------------------------------------------------+
//| Get StopTradingByWinRiskToday                                    |
//| minWinPercent per day                                            |
//+------------------------------------------------------------------+
bool IsStopTrading()
{  
   if(MAX_ORDER_PER_DAY > 0 && OrdersHistoryTotal() > 0)
   { 
        int totals = CountOrderOfDayByType(); 
        // If has win stop| If has loss > max open stop           
        if(totals >= MAX_ORDER_PER_DAY )
         {
           CreateComment(lblMessage,"StopTrading total trading in day = "+ (totals) +" > MAX_ORDER_PER_DAY:= "+  MAX_ORDER_PER_DAY);           
          return true;     
        }
    }
        
   return false;
}


//Type -1 > Profit <0
// Type 1 > Profit >0
int CountOrderOfDayByType(int typeCount=0)
{  
 if(OrdersHistoryTotal() <= 0) 
  return 0;
  
  int countOrder = 0;
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

double GetDailyProfit()
{
 double profit=0;

 if(OrdersHistoryTotal() <= 0) 
 {    
  return 0;
 }
  
  datetime today_midnight=TimeCurrent()-(TimeCurrent()%(PERIOD_D1*60));
   for(int x=OrdersHistoryTotal()-1; x>=0; x--)
   {
      if(!OrderSelect(x,SELECT_BY_POS,MODE_HISTORY))
       continue;
      
      if(OrderCloseTime()>=today_midnight)
      {
            profit += (OrderProfit() + OrderSwap() + OrderCommission());
      }
   }
    
  CreateComment(lblMessage,"maxProfit: "+ maxProfit +" minProfit:"+ minProfit);
     
return profit;
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
 double PointValue =0;

  if (MarketInfo(_Symbol, MODE_POINT) == 0.00001) PointValue = 0.0001;
         else if (MarketInfo(_Symbol, MODE_POINT) == 0.001) PointValue = 0.01;
         else PointValue = MarketInfo(_Symbol, MODE_POINT);
  return  GetPointValue();// PointValue;
}

double GetPointValue()
{
  double iPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   switch( (int) SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE) )
   {
      case 0: //Forex
         if ( Digits == 3 || Digits == 5 )
            iPoint *= 10;   
      break;
      case 1: //Cfd
         if ((1.0 / SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE)) != 100.0)
            iPoint = 0.01;//1
      break;
   }
 return iPoint;
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
   if(priceHigh == 0 || priceLow == 0) 
   return 0; 
   double points = priceHigh - priceLow;
   double distance = MathRound(MathAbs(points)/PipSize()) + GetSpread();
   return  distance;
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

double PipSize()
{
  double point = MarketInfo(_Symbol,MODE_POINT);
  int digits =(int)MarketInfo(_Symbol,MODE_DIGITS);
  point = digits%2 == 1? point*10: point;
  return point;
}

double Pip2Price(double pips)
{
   return pips*PipSize();
}

double GetLotSizeOrder(double distance,double loss){
   double lotSize = 0;   
   if(distance == 0){
  CreateComment(lblMessage,"Lotsize zero - distance: "+ distance);
   return 0;
   }   
     
   lotSize = loss/(distance*SymbolPointValue(_Symbol));
    
   
   if(lotSize <0.01) {
    CreateComment(lblMessage,"Lotsize < 0.01 - distance: "+ distance);
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

double GetTotalProfit(){
double totalProfits=0;   
  int total = OrdersTotal();
  for(int i=0;i<total;i++)
  {
     if(OrderSelect(i,SELECT_BY_POS, MODE_TRADES))
      {              
         totalProfits += (OrderProfit()+OrderSwap()+OrderCommission());     
      }        
  }      
   
  CreateComment(lblMessage,"Total Profit: "+ totalProfits); 
   return totalProfits;
}

double CalAvgPrice(double highPrice, double lowPrice){
return (highPrice + lowPrice)/2;
}

double GetAvgAtrD(int shift)
{
   return GetPipsFrom2Price(iHigh(_Symbol,PERIOD_D1,shift),iLow(_Symbol,PERIOD_D1,shift));
}

// Type 1 breakout up
// Type -1 breakout down
void DrawBreakOut(int index, int type)
{   
  if(off_break_out)
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
   ObjectSet(name, OBJPROP_ARROWCODE,SYMBOL_CHECKSIGN);// type ==1? SYMBOL_ARROWUP: SYMBOL_ARROWDOWN);
   ObjectSet(name, OBJPROP_COLOR,cl);
}

void DrawBox(datetime time1, double price1, datetime time2, double price2,color clr = clrBlue)
{
   string name = "Rectangle_"+time1;
   ObjectCreate(name, OBJ_RECTANGLE, 0,time1, price1, time2, price2); 
   ObjectSet(name, OBJPROP_COLOR, clr);
   ObjectSet(name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSet(name, OBJPROP_WIDTH, 2);
}

void DrawPinbar(datetime time, double higPrice =0, double lowPrice = 0)
{   
    string name ="Check_";
    if(higPrice!=0)
    name +="Up"+ time;
    else
    name +="Down"+ time;
    color cl = higPrice !=0? Blue: Red;
    double value = higPrice !=0 ? higPrice + 6*GetPipValue(): lowPrice - 6*GetPipValue();
    ObjectCreate(name,OBJ_ARROW_CHECK,0,time,value);
    ObjectSet(name, OBJPROP_ARROWCODE, higPrice !=0? SYMBOL_ARROWUP : SYMBOL_ARROWDOWN);
    ObjectSet(name, OBJPROP_COLOR,cl);
}

void DrawDoji(datetime time, double higPrice =0, double lowPrice = 0)
{   
    string name ="Thump_";
    if(higPrice!=0)
    name +="Up"+ time;
    else
    name +="Down"+ time;
    color cl = higPrice !=0? Blue: Red;
    double value = lowPrice - 6*GetPipValue();
    if(higPrice !=0)
    ObjectCreate(name,OBJ_ARROW_STOP,0,time,value);
     if(lowPrice !=0)
    ObjectCreate(name,OBJ_ARROW_STOP,0,time,value);
    ObjectSet(name, OBJPROP_COLOR,cl);
}

//+------------------------------------------------------------------+
// 
//+------------------------------------------------------------------+
int SymbolsListGet(string &pSymbolsRef[], bool pOnlyOnMarketWatch = false)
{
   int iSymbolNumber = SymbolsTotal(false);
   for ( int i = 0; i < iSymbolNumber; i++ )
   {
      string iSymbolName = SymbolName(i, false);
      int x = ArrayResize(pSymbolsRef, ArraySize(pSymbolsRef) + 1) - 1;
      if ( pOnlyOnMarketWatch )
      {
         if ( SymbolInfoInteger(iSymbolName, SYMBOL_VISIBLE) )
            pSymbolsRef[x] = iSymbolName;
      }
      else
         pSymbolsRef[x] = iSymbolName;
   }
   return ArraySize(pSymbolsRef);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double SymbolPointValue(string pSymbol = NULL, datetime pDt = 0)
{
  return NormalizeDouble(SymbolInfoDouble(pSymbol, SYMBOL_TRADE_TICK_VALUE) * 10,2);   
 
   pSymbol = pSymbol == NULL || pSymbol == "" ? Symbol() : pSymbol;
   if ( MQLInfoInteger(MQL_TESTER) )
      return SymbolInfoDouble(pSymbol, SYMBOL_TRADE_TICK_VALUE) * 10.0;
      
   double iPoint = SymbolInfoDouble(pSymbol, SYMBOL_POINT);
   
   switch( (int) SymbolInfoInteger(pSymbol, SYMBOL_TRADE_CALC_MODE) )
   {
      case 0: //Forex
         if ( Digits == 3 || Digits == 5 )
            iPoint *= 10;   
      break;
      case 1: //Cfd
         if ((1.0 / SymbolInfoDouble(pSymbol, SYMBOL_TRADE_TICK_SIZE)) != 100.0)
            iPoint = 1;
      break;
   }
   
   double iPipValue = SymbolInfoDouble(pSymbol, SYMBOL_TRADE_CONTRACT_SIZE) * iPoint;
   string iAccountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   string iProfitCurrency = SymbolInfoString(pSymbol, SYMBOL_CURRENCY_PROFIT);
   if ( iAccountCurrency != iProfitCurrency )
   {
      string iAccountAndProfitSymbol = iAccountCurrency + iProfitCurrency;
      string iMarketSymbol = "";
      string iaSymbol[];
      SymbolsListGet(iaSymbol);
      for ( int i = 0; i < ArraySize(iaSymbol); i++ )
      {
         if ( StringFind(iaSymbol[i], iAccountCurrency, 0) >= 0 && StringFind(iaSymbol[i], iProfitCurrency, 0) >= 0 )
            iMarketSymbol = iaSymbol[i];
      }
      double iBid = SymbolInfoDouble(iMarketSymbol, SYMBOL_BID);
      if ( pDt != 0 )
      {
         int iShift = iBarShift(iMarketSymbol, PERIOD_M1, pDt, false);
         iBid = iClose(iMarketSymbol, PERIOD_M1, iShift);
      }
      if ( iAccountAndProfitSymbol != iMarketSymbol )
      {
         iAccountAndProfitSymbol = iMarketSymbol;
         iBid = SymbolInfoDouble(iAccountAndProfitSymbol, SYMBOL_BID) != 0.0 ? 1.0 / SymbolInfoDouble(iAccountAndProfitSymbol, SYMBOL_BID) : 0.0;
         if ( pDt != 0)
         {
            int iShift = iBarShift(iAccountAndProfitSymbol, PERIOD_M1, pDt, false);
            iBid = iClose(iAccountAndProfitSymbol, PERIOD_M1, iShift) != 0.0 ? 1.0 / iClose(iAccountAndProfitSymbol, PERIOD_M1, iShift) : 0.0;
         }
      }
      iPipValue = iBid == 0 ? 0 : iPipValue / iBid;
   }
   CreateComment(lblMessage,"iPipValue: "+ iPipValue);
   return iPipValue;
}

double GetTotalLots()
{
   int total = OrdersTotal();
   double lots=0;
   for(int i=0;i<total;i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      continue;
      lots += OrderLots();
     }
     
     return lots;
}

string InpFileName ="profit.csv";
string InpDirectoryName ="Data//"+InpFileName;

void WriteToFile(double maxProfit, double minProfit)
{
   int file_handle=FileOpen(InpDirectoryName,FILE_READ|FILE_WRITE|FILE_CSV,';');
   
   if(file_handle!=INVALID_HANDLE)
     {
      PrintFormat("%s file is available for writing",InpFileName);
      PrintFormat("File path: %s\\Files\\",TerminalInfoString(TERMINAL_DATA_PATH));
      //--- first, write the number of signals
      string data = iTime(_Symbol,PERIOD_D1,1) +"\t "+ maxProfit+" \t"+minProfit+"\n";
      FileSeek(file_handle, 0, SEEK_END);
      
      FileWriteString(file_handle,data);     
      //--- close the file
      FileClose(file_handle);
      PrintFormat("Data is written, %s file is closed",InpFileName);
     }else
      PrintFormat("Failed to open %s file, Error code = %d",InpFileName,GetLastError());
}

void ObDeleteObjects(string objName){  
   int i = 0; 
   while(i < ObjectsTotal()) {
      string ObjName = ObjectName(i);    
      if(objName ==  ObjName)
      ObjectDelete(ObjName);
   }
}

void CreateComment(string com_lbl,string content,int position = 20, color cl=clrDarkGoldenrod)
{  
   ObjectCreate(com_lbl,OBJ_LABEL,0,0,0);
   ObjectSet(com_lbl,OBJPROP_XDISTANCE,10);
   ObjectSet(com_lbl,OBJPROP_YDISTANCE,position);
   ObjectSetText(com_lbl,content,9,"Arial",cl);
   WindowRedraw();
}