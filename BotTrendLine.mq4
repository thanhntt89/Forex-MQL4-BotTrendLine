
//+------------------------------------------------------------------+
#property copyright "Copyright ｩ 2013 Matus German www.MTexperts.net"
#define OP_ALL 10
#define SLIPPAGE              10

#include <Controls\RadioButton.mqh>
#include <Controls\RadioGroup.mqh>

enum ENUM_TRADING_TYPE {Manual, SetTrend, Auto};
enum ENUM_POSITION_TYPE {LongOnly, ShortOnly, LongAndShort};
//Define trend type
enum ENUM_TREND_TYPE {NONE,LONG,SHORT};
enum ENUM_ORDER_TYPES {OrderTypeStop,OrderTypeMarket,OrderTypeLimit};

extern string SettingGeneral =">>Setting General<<";
extern double RiskPerDeal = 20;//Risk_Per_Deal
input double WinRiskFactor = 3;//Win/Risk factor F=TP/SL
extern double MaxLotAllDEAL = 2;//Max_Lot_ALL_DEAL
extern double MaxRiskPerDay = -100;//Max_Risk_per_Day
extern double MinProfitPerDay = 100;//Min_Profit_per_Day
extern string SettingTradingType =">>Setting Trading Time Frame<<";
extern ENUM_TIMEFRAMES TradingTimeFrame= PERIOD_H4;//Trading time frame
extern string SettingTradingMode =">>Setting Trading Mode<<";
extern ENUM_TRADING_TYPE TradingType = SetTrend;//Trading Type
extern string SettingTradingTypeAuto =">>Setting Trading Position<<"; 
extern ENUM_POSITION_TYPE MarketTrend = LongAndShort;// Set market trend
extern string SettingOpenOrderType =">>Setting Open Order Type<<"; 
extern ENUM_ORDER_TYPES OpenOrderType = OrderTypeMarket;//Open order type 
extern string SettingFiboLevel=">>Setting OpenOrderType: OrderTypeLimit / OrderTypeMarket<<";//Set fibo(1-100) using for OpenOrderType: OrderTypeStop / OrderTypeMarket (waiting for fibo)
extern double FiboLevel=23.8;
extern string SettingBreakEvent =">>Setting Break Event<<";
extern bool IsSetBreakEvent = true;//Set break event

extern string SettingMovingSotpLoss =">>Setting moving stop loss<<";
extern bool IsMovingStopLoss = true;// Set moving stopLoss
extern double StopLossMinProfits = 20;// Min profit to move stoploss
extern bool IsUsedCandlePattenMovingStopLoss = true;// Using candle patten to moving stoploss


double DELTA_PIPS = 3;

string    Info               = "Create trendline, name it buy or sell, after crossing will be opened trade";
bool isStopOpenOrder = false;

double maxProfit = 0;
double minProfit = 0;

double min_stop_loss = 20;
double min_stop_loss_G = 40;
double    MagicNumber        = 0; 
double    Lot                = 0.1;
double    TakeProfitPip      = 100;
double    StopLossPip        = 30;
color     BuyTrendLine       = Lime;
color     SellTrendLine      = Red;
color     Sl_BuyLineColor    = Blue;
color     Sl_SellLineColor   = Violet;

color     TP_BuyLineColor    = Blue;
color     TP_SellLineColor   = Violet;

double    MaxSlippage           =3;   
 

double   stopLoss, takeProfit, trailingStop,
         minAllowedLot, lotStep, maxAllowedLot,
         pips2dbl, pips2point, pipValue, minGapStop, maxSlippage,
         lots;         

int      ticket;

bool     startBuy=true, startSell=true,
         openedBuy=false, openedSell=false, 
         buyLineUp, sellLineUp;

ENUM_ORDER_TYPE currentOrderType = -1;
double currentProfit =0;

string   comm;
string lblMessage ="lblMessage";

// Define trend
string trendBuy="buy";
string trendBuySL="slbuy";
string trendBuyTP="tpbuy";
string trendSell="sell";
string trendSellSL = "slsell";
string trendSellTP ="tpsell";    

  
  
CRadioGroup rdGroup;
CRadioButton rdOrderMarket;
CRadioButton rdOrderStop;
CRadioButton rdOrderLimit;
  
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//---        
   InitRadioButton();
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
//----
   return(0);
  }


void InitRadioButton(){

   rdOrderMarket.Create (0,"Market Order",3,300,30,450,50);
   rdOrderMarket.Color(clrBlue);
   
   rdOrderStop.Create (0,"Stop Order",3,300,30,450,80);
   rdOrderMarket.Color(clrBlue);
   
   rdOrderLimit.Create (0,"Limit Order",3,300,30,450,120);
   rdOrderMarket.Color(clrBlue);
   
   rdGroup.Create(0,"Help!",3,300,60,450,150);
}

  
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
{
//---- 
 
 StartTrading();
    
 GetSignal();
//----
   return(0);
} 

void GetSignal(){

   //Reading indicator value
   

}

///////////////////////
void StartTrading(){

 //SettingBreakEvent();
  ticket = GetOpeningTicket(currentOrderType,currentProfit);
  
  AutoTrading();   
     
  //Set BE   
  BreakEvent();  
  
  SetBreakEventTPSL();
}

///Check allow trade
bool IsAllowedTrade(){
double dailyProfit = GetDailyProfit();
   if(dailyProfit >= MinProfitPerDay && MinProfitPerDay > 0)
   {   
       CreateComment(lblMessage,"STOP_TRADING_TOTAL DAILY PROFIT: "+ dailyProfit + ">= MAX_PROFIT: "+ MinProfitPerDay);
       return false;
   }else if(dailyProfit <= MaxRiskPerDay && MaxRiskPerDay < 0)
   {   
       CreateComment(lblMessage,"STOP_TRADING_TOTAL MAX LOSS PERDAY: "+ dailyProfit + ">= MAX_LOSS: "+ MaxRiskPerDay);
        return false;
   }
   
  if(ticket > 0) 
  return false;
  
  return true;
}

// Set trading type
void AutoTrading()
{
   if(!IsAllowedTrade()) 
   return;
   ENUM_ORDER_TYPE orderType = -1;
   stopLoss = 0;
   takeProfit = 0;
   double openPrice = 0;
   string orderTypeString ="";
   if(TradingType == SetTrend)
   {
     orderType = GetOrderTypeByTrendLine(TradingTimeFrame, orderTypeString);
   }
   
   if(orderType == -1) 
   return; 
    
  openPrice = GetOpenPrice(orderType,TradingTimeFrame,FiboLevel, stopLoss, takeProfit);
   
  double stopLossPips = GetPipsFrom2Price(openPrice,stopLoss);
   
  lots = GetLotSizeOrder(stopLossPips,RiskPerDeal);
  
  double MaxLotsDeal = MaxLotAllDEAL - GetTotalLots();
  if(lots > MaxLotsDeal)
   {
     CreateComment(lblMessage,"LotSize over max lots - OrderLotSize: "+lots +" > Detal = (Total("+MaxLotsDeal+") - Current("+GetTotalLots()+")= "+ lots +" - MaxTotalLots:"+ MaxLotAllDEAL);
     return;
   }
 
  if(takeProfit == 0) 
   takeProfit = GetTakeProfit(orderType,openPrice,stopLossPips,WinRiskFactor); 
 
  //comm ="OpenPrice: "+ openPrice +" StopLoss: "+ stopLoss + " TakeProfit: "+ takeProfit +"\n stopLossPips: "+ stopLossPips;
  //CreateComment(lblMessage,comm);
  //comm ="stopLossPips: "+ stopLossPips +" lots: " + lots+ " MaxLotsDeal: "+MaxLotsDeal;
  //CreateComment(lblMessage,comm,50);

  //comm ="orderType = "+ orderType +" OpenPrice: "+ openPrice +" stopLossPrice: "+stopLoss;
 // CreateComment("lblTest0",comm,30);
  
 // comm ="orderType: "+orderTypeString + " StopLossPips: "+ stopLossPips +" Lots:" + lots;
 // CreateComment("lblTest1",comm,50);
  
  
 // comm ="TakeProfitPrice = "+ takeProfit;
 // CreateComment("lblTest2",comm,70);
  
  int countOpened = 0; 
  isStopOpenOrder = false;
    
  while(!OpenOrder(orderType,openPrice,lots,stopLoss,takeProfit,ticket) && !isStopOpenOrder) 
  {
      countOpened++;
      Print("Try open order - CountTime:"+ countOpened);
      
      // Try reopen order 3 times 
      if(countOpened > 10)
      {
         openPrice = MarketInfo(_Symbol, MODE_BID);
        // orderType = OP_SELL;
         if(orderType == OP_BUYLIMIT  || orderType == OP_BUYSTOP || orderType == OP_BUY)
         {
           //orderType = OP_BUY;
           openPrice = MarketInfo(_Symbol, MODE_ASK);
         }
         
         isStopOpenOrder = true;
      }
  } 
}

// Get open price by ordertype
double GetOpenPrice(ENUM_ORDER_TYPE orderType, ENUM_TIMEFRAMES timeFrame, double fiboLevel,double& sotopLossPrice, double& takeProfitPrice)
{
   if(orderType == -1) 
   return 0; 
   
   double openPrice = 0;
  
   if(orderType == OP_BUY)
   {
      openPrice = MarketInfo(_Symbol, MODE_ASK);
   }
   else if(orderType == OP_BUYLIMIT)
   {
     openPrice = GetFiboValueOfCandle(timeFrame,1,FB_DOWN,fiboLevel);
     if(MarketInfo(_Symbol, MODE_ASK) < openPrice)
      openPrice = 0;
   }else if(orderType == OP_BUYSTOP)
   {
      openPrice = GetHighPrice(timeFrame,1) + Pip2Price(DELTA_PIPS);
      if(MarketInfo(_Symbol, MODE_ASK) > openPrice)
      openPrice = 0;
      
   }else if(orderType == OP_SELL)
   {
      openPrice = MarketInfo(_Symbol, MODE_BID);
   }
   else if(orderType == OP_SELLLIMIT)
   {
     openPrice = GetFiboValueOfCandle(timeFrame,1,FB_UP,fiboLevel);
     if(MarketInfo(_Symbol, MODE_BID) > openPrice)
      openPrice = 0;
      
   }else if(orderType == OP_SELLSTOP)
   {
       openPrice = GetLowPrice(timeFrame,1) - Pip2Price(DELTA_PIPS);
       if(MarketInfo(_Symbol, MODE_BID) < openPrice)
        openPrice = 0;
   }
   
    sotopLossPrice = GetTrendLineValue(trendBuySL,0); 
    takeProfitPrice = GetTrendLineValue(trendBuyTP,0);
    
    if(orderType == OP_SELL ||  orderType == OP_SELLLIMIT ||  orderType == OP_SELLSTOP)
    {
       sotopLossPrice = GetTrendLineValue(trendSellSL,0);
       takeProfitPrice = GetTrendLineValue(trendSellTP,0); 
    }
   return openPrice;
}

//////Get take profit////////
double GetTakeProfit(ENUM_ORDER_TYPE orderType,double openPrice,double stopLossPips, double winRiskFactor)
{
  double takeProfit = 0;
  
  if(orderType == OP_BUY || orderType == OP_BUYLIMIT || orderType == OP_BUYSTOP)
  {
    takeProfit = openPrice + Pip2Price(winRiskFactor*stopLossPips);
  }else if(orderType == OP_SELL || orderType == OP_SELLLIMIT || orderType == OP_SELLSTOP)
  {
    takeProfit = openPrice - Pip2Price(winRiskFactor*stopLossPips);
  }  
  
  return takeProfit;
}

/// Setting BE ///
void BreakEvent(){

    if(!IsSetBreakEvent || ticket <= 0)
    return;
     
    double profitTarget = MinProfitPerDay;  
    double currentProfit = NormalizeDouble(GetTotalProfit(),2);
    double dailyProfit =  GetDailyProfit();
    double totalProfit =  currentProfit + dailyProfit;
         
     totalProfit =  NormalizeDouble(totalProfit,2);
     
     if(currentProfit > 0 && currentProfit > maxProfit)
     {
      maxProfit = currentProfit;
     }else if(currentProfit < 0 && currentProfit < minProfit)
     {
      minProfit = currentProfit;
     }
     
     //Break by total profit
    if(totalProfit >= profitTarget && MinProfitPerDay > 0)
    
    {
      CloseAllTrade();     
    }        
        
    string comment = "Total DailyProfit: "+ totalProfit;
    CreateComment("lblProfit",comment,90,clrGreenYellow);    
}

//Getcandle partten
ENUM_TREND_TYPE GetCandlePartten(ENUM_TIMEFRAMES timeFrame,double& highPrice, double& lowPrice)
{
 ENUM_TREND_TYPE trend = NONE;           
         trend = EngulfingPartten(timeFrame,highPrice, lowPrice);          
         if(trend == NONE)
         trend = PinbarPartten(timeFrame,highPrice, lowPrice); 
 return  trend;
}


void SetBreakEventTPSL(){
  
   if(ticket < 0 || !IsMovingStopLoss) 
   return;
   
  double stopLossPrice = 0;
  double takeProfitPrice = 0;
  double delta = Pip2Price(5);
  string candleParttenString ="";
  double highPrice, lowPrice;
  string comment ="";
    
  if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
   return;
  
  // Moving stoploss to openorder
  if(OrderType() == OP_BUY && OrderOpenPrice () > OrderStopLoss() || OrderType() == OP_SELL && OrderOpenPrice() < OrderStopLoss())
  {
     if(OrderProfit() <= StopLossMinProfits) 
     return;
       if(OrderType() == OP_BUY)
       stopLossPrice = OrderOpenPrice() + delta;
       else
        stopLossPrice = OrderOpenPrice() - delta;
  }else  // If using candel patten
  if(IsUsedCandlePattenMovingStopLoss)
  {
   
    ENUM_TREND_TYPE candlePartten = GetCandlePartten(TradingTimeFrame, highPrice, lowPrice);
     //   comment = "candlePartten: "+ candlePartten;
    //  CreateComment("lblTest1",comment,60,clrGreenYellow);    
      
     if(candlePartten == NONE) 
     return;
     
     if(OrderType() == OP_SELL && candlePartten == LONG)
     {  
         delta = OrderOpenPrice() < lowPrice? -delta: delta; 
         stopLossPrice =  highPrice + delta;
            
     }else if(OrderType() == OP_BUY && candlePartten == SHORT)
     {  
         delta = OrderOpenPrice() > highPrice? delta: -delta;
         stopLossPrice =  lowPrice + delta;   
     }
  }
      
  if(stopLossPrice!=0)
  {     
     int ticketModify = OrderModify(OrderTicket(),OrderOpenPrice(),stopLossPrice,OrderTakeProfit(),NULL,NULL);
     if(ticketModify < 0)
     {
       Print(Symbol()+" - SetTPSLError: "+ GetLastError());
     }
  }
}


///Get total lots///
double GetTotalLots()
{
   int total = OrdersTotal();
   double lots=0;
   for(int i=0;i<total;i++)
     {      
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      continue;
      
      if(OrderType() == OP_BUY && OrderStopLoss() > OrderOpenPrice() || OrderType() == OP_SELL && OrderStopLoss() < OrderOpenPrice())
         continue;
       
      lots += OrderLots();
     }
     
     return lots;
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

//Get Order type
ENUM_ORDER_TYPE GetOrderTypeByTrendLine(ENUM_TIMEFRAMES timeFrame,string& orderTypeString)
{
   SetTrendLineColor();
   ENUM_ORDER_TYPE orderType = -1;
   
   double  closePrice = GetClosedPrice(timeFrame,1); 
  
   // Check current price to open buy
   if(ObjectFind(trendBuy)!=-1)
   {
      double buyTrendLineValue = GetTrendLineValue(trendBuy,1);
     
      if(buyTrendLineValue != 0 && buyTrendLineValue < closePrice)
      {
         orderType = OP_BUY; 
          orderTypeString ="OP_BUY";
          if(OpenOrderType == OrderTypeLimit){
         orderType = OP_BUYLIMIT;
          orderTypeString ="OP_BUYLIMIT";
         }else if (OpenOrderType == OrderTypeStop){
         orderType = OP_BUYSTOP;
         orderTypeString ="OP_BUYSTOP";
         } 
         
        // CreateComment("lbl1","BUY - Price: "+ GetTrendLineValue(trendBuy,1)+" stoploss: "+ stopLoss,50);
      }
      
       //CreateComment("lbl1","BUY---test: buyTrendLineValue = "+ buyTrendLineValue +" closePriceH41:"+ closePrice,50);   
   }
   
   // Check current price to open sell
   if(ObjectFind(trendSell)!=-1)
   {
      double sellTrendLineValue = GetTrendLineValue(trendSell,1);
      
      if(sellTrendLineValue != 0 && sellTrendLineValue > closePrice)
     {
         orderType = OP_SELL; 
         orderTypeString ="OP_SELL";
         if(OpenOrderType == OrderTypeLimit){
           orderType = OP_SELLLIMIT;
            orderTypeString ="OP_SELLLIMIT";
         }else if (OpenOrderType == OrderTypeStop){
           orderType = OP_SELLSTOP;
           orderTypeString ="OP_SELLSTOP";
         }           
          //CreateComment("lbl1","SELL - Price: "+ GetTrendLineValue(trendSell,1)+" stoploss: "+ stopLoss,50);  
     }  
     //CreateComment("lbl1","SELL---test: sellTrendLineValue = "+ sellTrendLineValue +" closePrice: "+ closePrice,50);       
   }  

  return orderType;
}


//////////////////////////////////////////////////////////////////////////////////////////////////
bool OpenOrder(ENUM_ORDER_TYPE orderType,double openPrice, double olots, double stopLoss, double takeProfit,int& ticket)
{       
      while (!IsTradeAllowed()) Sleep(300);   
    
      if(orderType == -1) 
       return (false);
     
      // Set color order
      color clrOrder = Red;
      if(orderType == OP_BUY || orderType == OP_BUYLIMIT || orderType == OP_BUYSTOP)
      {
         clrOrder = Green;
      }
      
      // Timeout order
      int orderTimeOut = 0;// 1D = 24hx60m = 1440 m
      if(orderType == OP_BUYLIMIT || orderType == OP_BUYSTOP || orderType == OP_SELLLIMIT || orderType == OP_SELLSTOP)
      {
         orderTimeOut = TimeCurrent() + PERIOD_H1*6 + PERIOD_H1*(24 - Hour())*60; 
      }
            
      RefreshRates();
      
      ticket = OrderSend(_Symbol, orderType,olots,openPrice ,maxSlippage,stopLoss,takeProfit,"",MagicNumber,orderTimeOut,clrOrder);
         
      if(ticket>0)
      {    
         // Delete all trendline after opening success
         DeleteTrendLine();
         return(true);              
      }
      else 
      {
         return(false);
      }
   
   return (false);   
}

//Delete trendline
void DeleteTrendLine()
{
   DeleteObject(trendBuy);
   DeleteObject(trendBuySL);
   DeleteObject(trendBuyTP);
   
   DeleteObject(trendSell);
   DeleteObject(trendSellSL);
   DeleteObject(trendSellTP);
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

//+------------------------------------------------------------------+
//| Get spread symbol                                                |
//+------------------------------------------------------------------+
double GetSpread()
{
double spred = MarketInfo(_Symbol,MODE_SPREAD)/10;
 //  Print("Spread: "+ spred);
   return spred;
}

//Get lotsize by distance SL and Loss (R) usd
double GetLotSizeOrder(double distance,double loss){
   double lotSize = 0;   
   if(distance == 0){
     CreateComment(lblMessage,"Lotsize zero - distance: "+ distance);
    return(-1);
   }   
     
   lotSize = loss/(distance* NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * 10,2));
    
   if(lotSize <0.01) {
    CreateComment(lblMessage,"Lotsize < 0.01 - distance: "+ distance);
     return(-1);
   }
   
  double minAllowedLot  =  MarketInfo(Symbol(), MODE_MINLOT);    //IBFX= 0.10
  double lotStep        =  MarketInfo(Symbol(), MODE_LOTSTEP);   //IBFX= 0.01
  double maxAllowedLot  =  MarketInfo(Symbol(), MODE_MAXLOT );   //IBFX=50.00
     
   if(lotSize < minAllowedLot || lotSize > maxAllowedLot)
   {
      CreateComment("lblMinLost","Lotsize < "+lotSize+" - distance: "+ distance +" maxAllowedLot: "+ maxAllowedLot);
      return(-1);  
   }
      
   lotSize = NormalizeDouble(lotSize,2); 
   return lotSize;
}


// Get value trendline
double GetTrendLineValue(string trendLineName, int shift)
{
  double trendPrice = 0;
   if(ObjectFind(trendLineName)!=-1)
  {
    trendPrice = ObjectGetValueByShift(trendLineName,shift);
    if(trendPrice == 0)
     {
         trendPrice = ObjectGetDouble(0,trendLineName,OBJPROP_PRICE1,shift);
     }
  }
  
  return trendPrice;
}

// Set trend line
void SetTrendLineColor()
{   
    FindTrendLine(trendBuy,BuyTrendLine);
    FindTrendLine(trendBuySL,Sl_BuyLineColor);
    FindTrendLine(trendBuyTP,TP_BuyLineColor);
    
    FindTrendLine(trendSell,SellTrendLine); 
    FindTrendLine(trendSellSL,Sl_SellLineColor);   
    FindTrendLine(trendSellTP,TP_SellLineColor);  
    
    SetTextTrendLine(trendBuy,"BUY");
    SetTextTrendLine(trendBuySL,"SL_BUY");
    SetTextTrendLine(trendBuyTP,"TP_BUY");
    
    SetTextTrendLine(trendSell,"SELL");
    SetTextTrendLine(trendSellSL,"SL_SELL");
    SetTextTrendLine(trendSellTP,"TP_SELL");
}

//Set text for trendline
void SetTextTrendLine(string trendLineName,string trendLineDescription)
{
 if(ObjectFind(trendLineName)!=-1)
 {
   ChartSetInteger(0,CHART_SHOW_OBJECT_DESCR,true);   
   ObjectCreate(0,trendLineName,OBJ_HLINE,0,0,Ask);
   ObjectSetString(0,trendLineName,OBJPROP_TEXT,trendLineDescription);  
   
 }
}

//Finding trend line and set color
void FindTrendLine(string trendLineName, color clr)
{
  if(ObjectFind(trendLineName)!=-1)
  {
    ObjectSet(trendLineName,OBJPROP_COLOR,clr);
  }
}

// Delete object
void DeleteObject(string trendLineName)
{
   if(ObjectFind(trendLineName)!=-1)
  {
    ObjectDelete(trendLineName);
  }
}

// Get ticket order
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
            break;                   
      }
       
  return orderTicket;
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


//////////////////////////////////////////////////////////////////////////////////////////////////
// chceck trades if they do not have set sl and tp than modify trade
bool CheckStops()
{
   double sl=0, tp=0;
   double total=OrdersTotal();
   
   int ticket=-1;
   
   for(int cnt=total-1;cnt>=0;cnt--)
   {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if(   OrderType()<=OP_SELL                      
         && OrderSymbol()==Symbol()                  
         && OrderMagicNumber() == MagicNumber)        
      {
         if(OrderType()==OP_BUY)
         {
            if((OrderStopLoss()==0 && stopLoss>0) || (OrderTakeProfit()==0 && takeProfit>0))
            {  
               while (!IsTradeAllowed()) Sleep(500); 
               RefreshRates();
               
               if(OrderStopLoss()==0 && stopLoss>0)
               {
                  sl = OrderOpenPrice()-stopLoss; 
                  if(Bid-sl<=minGapStop)
                     sl = Bid-minGapStop*2;
               }
               else
                  sl = OrderStopLoss();
               
               if(OrderTakeProfit()==0 && takeProfit>0)   
               {
                  tp = OrderOpenPrice()+takeProfit;
                  if(tp-Bid<=minGapStop)
                     tp = Bid+minGapStop*2;
               }
               else
                  tp = OrderTakeProfit();
                     
               if(!OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0,Green)) 
                  return (false);
            }
         }   
         if(OrderType()==OP_SELL)
         {
            if((OrderStopLoss()==0 && stopLoss>0) || (OrderTakeProfit()==0 && takeProfit>0))
            {        
               while (!IsTradeAllowed()) Sleep(500); 
               RefreshRates();  
               
               if(OrderStopLoss()==0 && stopLoss>0)    
               {        
                  sl = OrderOpenPrice()+stopLoss;         
                  if(sl-Ask<=minGapStop)
                     sl = Ask+minGapStop*2;              
               }
               else
                  sl = OrderStopLoss();
               
               if(OrderTakeProfit()==0 && takeProfit>0)
               {
                  tp = OrderOpenPrice()-takeProfit;               
                  if(Ask-tp<=minGapStop)
                     tp = Ask-minGapStop*2;
               }
               else
                  tp = OrderTakeProfit();
                       
               if(!OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0,Green)) 
                  return (false);
            }
         } 
      }
   }
   return (true);
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

void CloseTrade(ENUM_TIMEFRAMES timeFrame, int ticketOpen)
{
    int hour = TimeHour(iTime(_Symbol,timeFrame,0));
   
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

// cmd = OP_ALL // OP_ALL = OP_BUY || OP_SELL || OP_BUYSTOP || OP_SELLSTOP || OP_BUYLIMIT || OP_SELLLIMIT
////////////////////////////////////////////////////////////////////////////////////////////////////////
bool CloseOrders(string symbol, int magic, int cmd)
{
    int total  = OrdersTotal();
      for (int cnt = total-1 ; cnt >=0 ; cnt--)
      {
         OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES);
         if (OrderSymbol()==symbol && OrderMagicNumber() == magic)
         {
            while(IsTradeContextBusy()) Sleep(100);
            if((cmd==OP_BUY || cmd==OP_ALL) && OrderType()==OP_BUY)
            {
               if(!OrderClose(OrderTicket(),OrderLots(),MarketInfo(symbol,MODE_BID),maxSlippage,Violet)) 
               {
                  Print("Error closing " + OrderType() + " order : ",GetLastError());
                  return (false);
               }
            }
            if((cmd==OP_SELL || cmd==OP_ALL) && OrderType()==OP_SELL)
            {  
               if(!OrderClose(OrderTicket(),OrderLots(),MarketInfo(symbol,MODE_ASK),maxSlippage,Violet)) 
               {
                  Print("Error closing " + OrderType() + " order : ",GetLastError());
                  return (false);
               }
            }
            if(cmd==OP_ALL && (OrderType()==OP_BUYSTOP || OrderType()==OP_SELLSTOP || OrderType()==OP_BUYLIMIT || OrderType()==OP_SELLLIMIT))
               if(!OrderDelete(OrderTicket()))
               { 
                  Print("Error deleting " + OrderType() + " order : ",GetLastError());
                  return (false);
               }
         }
      }
      return (true);
}


ENUM_TREND_TYPE PinbarPartten(ENUM_TIMEFRAMES timeFrame, double& highPrice, double& lowPrice)
{
   ENUM_TREND_TYPE trend = NONE;
   // double highPrice =0, lowPrice = 0;
    double openPrice = 0, closePrice =0;
    double body = 0, range = 0;
    double fiboUp=0, fiboDown =0;
   
   // 1.Candles - Ispinbar
    if(IsPinbarValid(timeFrame,1))
    {
       highPrice = GetHighPrice( timeFrame,1);
       lowPrice = GetLowPrice(timeFrame,1);
       
       openPrice = GetOpenedPrice(timeFrame,1);
       closePrice = GetClosedPrice(timeFrame,1);
       
       range = GetRange(timeFrame,1);       
       body = GetBody(timeFrame,1);
       
       fiboUp = GetFiboLevel(highPrice,lowPrice,25.0,FB_UP);
       fiboDown = GetFiboLevel(highPrice,lowPrice,25.0,FB_DOWN);
       
     
       if(body <= range/4)
       {
           // Trend Long
           if((IsUp(timeFrame,1) || !IsUp(timeFrame,1)) && closePrice >= fiboDown)
           {             
              trend = LONG;
           }
           else if ((!IsUp(timeFrame,1)|| IsUp(timeFrame,1)) && closePrice <= fiboUp )
           {              
               trend = SHORT;
           }
       }      
  }
  
 return trend;
}

ENUM_TREND_TYPE EngulfingPartten(ENUM_TIMEFRAMES timeFrame, double& highPrice, double& lowPrice)
{
   ENUM_TREND_TYPE trend = NONE;
   
   double body2 = GetBody(timeFrame,2);
   double body1 = GetBody(timeFrame,1);
   
   double openedPrice1 = GetOpenedPrice(timeFrame,1);
   double closedPrice1 = GetClosedPrice(timeFrame,1);
   
   double openedPrice2 = GetOpenedPrice(timeFrame,2);
   double closedPrice2 = GetClosedPrice(timeFrame,2);
   
   highPrice = GetHighPrice(timeFrame,1);
   lowPrice = GetLowPrice(timeFrame,1);
   
   double fiboUp = GetFiboLevel(highPrice,lowPrice,25,FB_UP);
   double fiboDown = GetFiboLevel(highPrice,lowPrice,25,FB_DOWN);
   
   if(body2 >= body1/3 && body2 <= body1*2/3)// && (closedPrice1 <= fiboDown || closedPrice1 >= fiboUp))
   {
       // Trend Up
       if(!IsUp(timeFrame,2) && IsUp(timeFrame,1))
       {
          trend = LONG;
       }
       else if(IsUp(timeFrame,2) && !IsUp(timeFrame,1))
       {
          trend = SHORT;
       }
   }
   
   return trend;
}

void CreateComment(string com_lbl,string content,int position = 20, color cl=clrDarkGoldenrod)
{  
   ObjectCreate(com_lbl,OBJ_LABEL,0,0,0);
   ObjectSet(com_lbl,OBJPROP_XDISTANCE,5);
   ObjectSet(com_lbl,OBJPROP_YDISTANCE,position);
   ObjectSetText(com_lbl,content,9,"Arial",cl);
   WindowRedraw();
}

enum ENUM_FIBO_TYPE{FB_UP, FB_DOWN};
//+------------------------------------------------------------------+
//|Get market trend                                                  |
//+------------------------------------------------------------------+
double GetFiboLevel( double highPrice, double lowPrice, double lev, ENUM_FIBO_TYPE fiboType ){

   double ling = MathAbs( highPrice - lowPrice);
   double pLev = ( ling / 100 ) * lev;
   
   return ( fiboType == FB_DOWN ) ? NormalizeDouble( highPrice - pLev, Digits ) : NormalizeDouble( lowPrice + pLev, Digits) ;
}

// Get value of candle
double GetFiboValueOfCandle(ENUM_TIMEFRAMES timeFrame, int shift, ENUM_FIBO_TYPE fiboType, double fiboLevel)
{
  double price = 0;
  double highPrice = GetHighPrice(timeFrame,shift);
  double lowPrice = GetLowPrice(timeFrame,shift);
  price = GetFiboLevel(highPrice,lowPrice,fiboLevel,fiboType);
  return price;
}


double GetOpenedPrice(ENUM_TIMEFRAMES timeFrame, int shift)
{
 return iOpen(_Symbol,timeFrame,shift);
}

double GetClosedPrice(ENUM_TIMEFRAMES timeFrame, int shift)
{
 return iClose(_Symbol,timeFrame,shift);
}

double GetHighPrice(ENUM_TIMEFRAMES timeFrame, int shift)
{
 return iHigh(_Symbol,timeFrame,shift);
}

double GetLowPrice(ENUM_TIMEFRAMES timeFrame, int shift)
{
 return iLow(_Symbol,timeFrame,shift);
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
     if (tail >= 2 * nose)
      {
         return true;
      }
   }
   return false;
}

double GetBody(ENUM_TIMEFRAMES timeFrame, int bar)
{
 return MathAbs(iClose(_Symbol, timeFrame, bar) - iOpen(_Symbol, timeFrame, bar));
}

double GetRange(ENUM_TIMEFRAMES timeFrame, int bar)
{
 return (iHigh(_Symbol, timeFrame, bar) - iLow(_Symbol, timeFrame, bar));
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
