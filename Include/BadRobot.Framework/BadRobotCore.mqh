//+------------------------------------------------------------------+
//|                                   Copyright 2016, Erlon F. Souza |
//|                                       https://github.com/erlonfs |
//+------------------------------------------------------------------+

#property   copyright   "Copyright 2016, Erlon F. Souza"
#property   link        "https://github.com/erlonfs"
#define     version     "1.18.0"

#include <Trade\Trade.mqh>
#include <BadRobot.Framework\Logger.mqh>
#include <BadRobot.Framework\Account.mqh>
#include <BadRobot.Framework\Enum.mqh>
#include <Controls\Dialog.mqh>

class BadRobotCore : public CAppDialog
{
	private:

	//Classes
	Logger _logger;
	Account _account;
	MqlTick _price;
	CTrade _trade;
	CPositionInfo _positionInfo;
	MqlRates _ratesRemainingTime[];

	//Definicoes Basicas
	string _symbol;
	double _volume;
	int _spread;
	int _stopGain;
	int _stopLoss;
	ENUM_LAST_PRICE_TYPE _lastPriceType; 
	string _robotName;
	string _robotVersion;
	ulong _magicNumber;

	//Enums
	ENUM_TIMEFRAMES _period;

	//Trailing Stop
	bool _isTrailingStop;
	int _trailingStopInicio;
	int _trailingStop;

	//Break Even
	bool _isBreakEven;
	bool _isBreakEvenExecuted;
	int _breakEvenInicio;
	int _breakEven;
		
	//Stop no candle anteriora
	bool _isStopOnLastCandle;
	int _spreadStopOnLastCandle;
	bool _waitBreakEvenExecuted;
	bool _isPeriodCustom;
	ENUM_TIMEFRAMES _periodStopOnLastCandle;
	MqlRates _ratesLasCandle[];

	//Parciais
	bool _isParcial;
	bool _isPrimeiraParcialExecuted;
	double _primeiraParcialVolume;
	int _primeiraParcialInicio;
	bool _isSegundaParcialExecuted;
	double _segundaParcialVolume;
	int _segundaParcialInicio;
	bool _isTerceiraParcialExecuted;
	double _terceiraParcialVolume;
	int _terceiraParcialInicio;	
   string _objNamePrimeiraParcial;
   string _objNameSegundaParcial;
   string _objNameTerceiraParcial;
   
   //Indicators
	bool _hasAnyIndicator;
	bool _indicatorsAllowBuy;
	bool _indicatorsAllowSell;
	
	//Indicators > Cruzamento de Medias Moveis
   bool _hasIndicatorCrossAverages;   	   
   int _eMA1Period;
   double _eMA1Values[];   	
   int _eMA1Handle;      
   int _eMA2Period;
   double _eMA2Values[];
   int _eMA2Handle;      
   int _eMA3Period;
   double _eMA3Values[];
   int _eMA3Handle;  
   ENUM_APPLIED_PRICE _crossAveragesAppliedPrice;
   ENUM_MA_METHOD _crossAveragesMethod;
   
   //Indicators > MACD 
   bool _hasIndicatorMACD;   	   
   int _mACDHandle;
   int _mACDFastPeriod;
   int _mACDSlowPeriod;
   int _mACDSignalPeriod;
   double _mACD[];
   double _mACDSignal[];
   ENUM_APPLIED_PRICE _mACDAppliedPrice;
   
   //Indicators > RSI 
   bool _hasIndicatorRSI;   	   
   int _rSIHandle;
   int _rSIPeriod;   
   double _rSIBuySignal; 
   double _rSISellSignal;
   double _rSI[];
   ENUM_APPLIED_PRICE _rSIAppliedPrice;
   
   //Indicators > SAR 
   bool _hasIndicatorSAR;   	   
   int _sARHandle;
   double _sARStep;
   double _sARMaximum;
   double _sAR[];
   
   //Indicators > BandsBollinger
   bool _hasIndicatorBandsBollinger;   	   
   int _bandsBollingerHandle;
   int _bandsBollingerPeriod;
   int _bandsBollingerShift;
   double _bandsBollingerDeviation;
   double _bandsBollingerBaseLine[];
   double _bandsBollingerUpperBand[];
   double _bandsBollingerLowerBand[];
   ENUM_APPLIED_PRICE _bandsBollingerAppliedPrice;
      
   //Indicators > Envelops
   bool _hasIndicatorEnvelopes;   	      
   int _envelopesPeriod;
   int _envelopesShift;
   ENUM_MA_METHOD _envelopesMethod;
   ENUM_APPLIED_PRICE _envelopesAppliedPrice;
   double _envelopesDeviation;
   int _envelopesHandle;
   double _envelopesUpperLine[];
   double _envelopesLowerLine[];
   
	//Gerenciamento Financeiro
	bool _isGerenciamentoFinanceiro;
	double _totalProfitMoney;
	double _totalStopLossMoney;
	double _totalOrdensVolume;
	double _maximoLucroDiario;
	double _maximoPrejuizoDiario;

	//Text
	string _lastText;
	string _lastTextValidate;
	string _lastTextInfo;

	//Period
	MqlDateTime _timeCurrent;
	MqlDateTime _horaInicio;
	MqlDateTime _horaFim;
	MqlDateTime _horaInicioIntervalo;
	MqlDateTime _horaFimIntervalo;

	//Period Interval
	string _horaInicioString;
	string _horaFimString;
	string _horaInicioIntervaloString;
	string _horaFimIntervaloString;

	//Flags
	bool _isBusy;
	bool _isNewCandle;
	bool _isNewDay;
	bool _isNotificacoesApp;
	bool _isAlertMode;
	bool _isClosePosition;
	bool _isRewrite;
	bool _canRewrite;
	bool _isInverted;

	void ManagePosition()
	{
		if (_isBusy) return;

		_isBusy = true;

		if (GetPositionMagicNumber() != _trade.RequestMagic())
		{
			return;
		}

		if (_isClosePosition)
		{
			if (GetHoraFim().hour <= GetTimeCurrent().hour)
			{
				if (GetHoraFim().min <= GetTimeCurrent().min)
				{
					ClosePosition();
				}
			}
		}		

		if (!HasPositionLossOrPositionGain())
		{
			RepositionTrade();
			ResetPosition();
		}
		else
		{	
			ManageStopOnLastCandle();
			ManageTrailingStop();
			ManageBreakEven();
			ManageParcial();
		}			
		
		_isBusy = false;

	}

	void ResetPosition()
	{			
		ClearDraw(_objNamePrimeiraParcial);
	   ClearDraw(_objNameSegundaParcial);
	   ClearDraw(_objNameTerceiraParcial);
	
	   if(HasPositionOpen()) return;

	   _isPrimeiraParcialExecuted = false;
	   _isSegundaParcialExecuted = false;
	   _isTerceiraParcialExecuted = false;
	   _isBreakEvenExecuted = false;	   
	}

	void ManageDealsProfit()
	{
		string CurrDate = TimeToString(TimeCurrent(), TIME_DATE);
		//HistorySelect(StringToTime(CurrDate), TimeCurrent());
		HistorySelect(0, TimeCurrent());

		ulong ticket = 0;
		double price;
		double profit;
		datetime time;
		string symbol;
		string comment;
		long type;
		long entry;
		double volume;
		ulong magic;

		double totalGainMoney = 0.0;
		double totalLossMoney = 0.0;
		double qtdOrdensVolume = 0;

		for (int i = HistoryDealsTotal() - 1; i >= 0; i--)
		{
			ticket = HistoryDealGetTicket(i);

			if (ticket <= 0){continue;}

			price = HistoryDealGetDouble(ticket, DEAL_PRICE);
			time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
			symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
			comment = HistoryDealGetString(ticket, DEAL_COMMENT);
			type = HistoryDealGetInteger(ticket, DEAL_TYPE);
			magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
			entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
			profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
			volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);

			if (symbol != _symbol)
			{
				continue;
			}

			if (magic != _trade.RequestMagic())
			{
				continue;
			}

			if (!price && !time)
			{
				continue;
			}

			if (profit < 0)
			{
				totalLossMoney += profit;
				qtdOrdensVolume += volume;
				continue;
			}

			if (profit > 0)
			{
				totalGainMoney += profit;
				qtdOrdensVolume += volume;
				continue;
			}
		}

		_totalProfitMoney = totalGainMoney;
		_totalStopLossMoney = totalLossMoney;
		_totalOrdensVolume = qtdOrdensVolume;


	}
			
	bool ManageStopOnLastCandle()
	{	
	   if(_isBreakEven && _waitBreakEvenExecuted)
	   {
	      if(!_isBreakEvenExecuted) return false;
	   }

		if (!_isStopOnLastCandle || !_isNewCandle)
		{		   
			return false;
		}

		if (CopyRates(GetSymbol(), _isPeriodCustom ? _periodStopOnLastCandle : GetPeriod(), 0, 2, _ratesLasCandle) <= 0)
		{
			return false;
		}

		//Posicao menor é o mais longe, ou seja, _rates[0] é o primeiro e _rates[1] é o ultimo
		MqlRates _candleAnterior = _ratesLasCandle[0];

		if (IsPositionTypeBuy())
		{

			if (GetPositionLoss() < _candleAnterior.low - ToPoints(GetSpreadStopOnLastCandle()))
			{
				_trade.PositionModify(_symbol, _candleAnterior.low - ToPoints(GetSpreadStopOnLastCandle()), GetPositionGain());
				_logger.Log("Stop ajustado candle anterior. " + (string)GetPositionLoss());
				return true;
			}
		}

		if (IsPositionTypeSell())
		{

			if (GetPositionLoss() > _candleAnterior.high + ToPoints(GetSpreadStopOnLastCandle()))
			{
				_trade.PositionModify(_symbol, _candleAnterior.high + ToPoints(GetSpreadStopOnLastCandle()), GetPositionGain());
				_logger.Log("Stop ajustado candle anterior. " + (string)GetPositionLoss());
				return true;
			}
		}

		return false;

	}

	bool ManageTrailingStop()
	{
		if (!_isTrailingStop){return false;}

		if (IsPositionTypeBuy())
		{

			if (GetLastPrice() - GetPositionPriceOpen() >= ToPoints(_trailingStopInicio))
			{
				_trade.PositionModify(_symbol, GetPositionLoss() + ToPoints(_trailingStop), GetPositionGain());
				_logger.Log("Stop ajustado trailing stop. " + (string)GetPositionLoss());
				return true;
			}

		}

		if (IsPositionTypeSell())
		{

			if (GetPositionPriceOpen() - GetLastPrice() >= ToPoints(_trailingStopInicio))
			{
				_trade.PositionModify(_symbol, GetPositionLoss() - ToPoints(_trailingStop), GetPositionGain());
				_logger.Log("Stop ajustado trailing stop. " + (string)GetPositionLoss());
				return true;
			}

		}

		return false;

	}

	bool ManageBreakEven()
	{
		if (!_isBreakEven || _isBreakEvenExecuted){return false;}

		if (IsPositionTypeBuy())
		{

			if (GetLastPrice() >= GetPositionPriceOpen() + ToPoints(_breakEvenInicio) && GetPositionLoss() < GetPositionPriceOpen())
			{
				_trade.PositionModify(_symbol, GetPositionPriceOpen() + ToPoints(_breakEven), GetPositionGain());
				_logger.Log("Stop ajustado break even. " + (string)(GetPositionPriceOpen() + _breakEven));
				_isBreakEvenExecuted = true;
			}
		}

		if (IsPositionTypeSell())
		{

			if (GetLastPrice() <= GetPositionPriceOpen() - ToPoints(_breakEvenInicio) && GetPositionLoss() > GetPositionPriceOpen())
			{
				_trade.PositionModify(_symbol, GetPositionPriceOpen() - ToPoints(_breakEven), GetPositionGain());
				_logger.Log("Stop ajustado break even. " + (string)(GetPositionPriceOpen() - _breakEven));
				_isBreakEvenExecuted = true;
			}
		}

		return _isBreakEvenExecuted;

	}

	bool ManageParcial()
	{
		if (!_isParcial){return false;}		
		if(GetLastPrice() <= 0) return false;

		double positionLoss = GetPositionLoss();
		double positionGain = GetPositionGain();

		bool isPrimeiraParcial = false;
		bool isSegundaParcial = false;
		bool isTerceiraParcial = false;	

		if (IsPositionTypeBuy())
		{
			isPrimeiraParcial = GetLastPrice() >= GetParcialValue(_objNamePrimeiraParcial);
			isSegundaParcial = GetLastPrice() >= GetParcialValue(_objNameSegundaParcial);
			isTerceiraParcial = GetLastPrice() >= GetParcialValue(_objNameTerceiraParcial);
		}
		
		if (IsPositionTypeSell())
		{
			isPrimeiraParcial = GetLastPrice() <= GetParcialValue(_objNamePrimeiraParcial);
			isSegundaParcial = GetLastPrice() <= GetParcialValue(_objNameSegundaParcial);
			isTerceiraParcial = GetLastPrice() <= GetParcialValue(_objNameTerceiraParcial);
		}

		if (isPrimeiraParcial && !_isPrimeiraParcialExecuted && _primeiraParcialInicio > 0)
		{
			return ExecutePrimeiraParcial();
		}

		if (isSegundaParcial && !_isSegundaParcialExecuted && _segundaParcialInicio > 0)
		{
			return ExecuteSegundaParcial();
		}

		if (isTerceiraParcial && !_isTerceiraParcialExecuted && _terceiraParcialInicio > 0)
		{
			return ExecuteTerceiraParcial();
		}

		return false;
		
	}
		
	void ManageDrawParcial()
	{		
	   if(_isPrimeiraParcialExecuted)
	   {
		   ClearDraw(_objNamePrimeiraParcial);
		}
		
	   if(_isSegundaParcialExecuted)
	   {		
		   ClearDraw(_objNameSegundaParcial);
		}		   
		
	   if(_isTerceiraParcialExecuted)
	   {		
		   ClearDraw(_objNameTerceiraParcial);
		}

		if (!HasPositionOpen()) return;

		if (IsPositionTypeBuy())
		{
			if (!_isPrimeiraParcialExecuted && _primeiraParcialInicio > 0)
			{
				DrawParcial(_objNamePrimeiraParcial, GetPositionPriceOpen() + ToPoints(_primeiraParcialInicio), 
				"Saída parcial\nPreço " + (string)(GetPositionPriceOpen() + ToPoints(_primeiraParcialInicio)) + "\nVolume " + (string)_primeiraParcialVolume);
			}

			if (!_isSegundaParcialExecuted && _segundaParcialInicio > 0)
			{
				DrawParcial(_objNameSegundaParcial, GetPositionPriceOpen() + ToPoints(_segundaParcialInicio), 
				"Saída parcial\nPreço " + (string)(GetPositionPriceOpen() + ToPoints(_segundaParcialInicio)) + "\nVolume " + (string)_segundaParcialVolume);
			}

			if (!_isTerceiraParcialExecuted && _terceiraParcialInicio > 0)
			{
				DrawParcial(_objNameTerceiraParcial, GetPositionPriceOpen() + ToPoints(_terceiraParcialInicio), 
				"Saída parcial\nPreço " + (string)(GetPositionPriceOpen() + ToPoints(_terceiraParcialInicio)) + "\nVolume " + (string)_terceiraParcialVolume);
			}
								
			return;

		}

		if (IsPositionTypeSell())
		{

			if (!_isPrimeiraParcialExecuted && _primeiraParcialInicio > 0)
			{
				DrawParcial(_objNamePrimeiraParcial, GetPositionPriceOpen() - ToPoints(_primeiraParcialInicio), 
				"Saída parcial\nPreço " + (string)(GetPositionPriceOpen() - ToPoints(_primeiraParcialInicio)) + "\nVolume " + (string)_primeiraParcialVolume);
			}

			if (!_isSegundaParcialExecuted && _segundaParcialInicio > 0)
			{
				DrawParcial(_objNameSegundaParcial, GetPositionPriceOpen() - ToPoints(_segundaParcialInicio), 
				"Saída parcial\nPreço " + (string)(GetPositionPriceOpen() - ToPoints(_segundaParcialInicio)) + "\nVolume " + (string)_segundaParcialVolume);
			}

			if (!_isTerceiraParcialExecuted && _terceiraParcialInicio > 0)
			{
				DrawParcial(_objNameTerceiraParcial, GetPositionPriceOpen() - ToPoints(_terceiraParcialInicio), 
				"Saída parcial\nPreço " + (string)(GetPositionPriceOpen() - ToPoints(_terceiraParcialInicio)) + "\nVolume " + (string)_terceiraParcialVolume);
			}

			return;

		}

	}

	void DrawParcial(string objName, double price, string text)
	{	
	   if(ObjectFind(0, objName) > -1 || !_isParcial) return;
	
		ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price);
		ObjectSetInteger(0, objName, OBJPROP_COLOR, _isParcial ? clrOrange : clrDarkGray);
		ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, clrBlack);
		ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASHDOT);
		ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
		ObjectSetString(0, objName, OBJPROP_TOOLTIP, text);
		ObjectSetInteger(0, objName, OBJPROP_BACK, true);
		ObjectSetInteger(0, objName, OBJPROP_FILL, true);		
		ObjectSetInteger(0, objName, OBJPROP_SELECTED, 1);
		ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
	}
	
	void OnDragParcial()
	{
	   OnDragLineParcial(_objNamePrimeiraParcial, _primeiraParcialVolume);
	   OnDragLineParcial(_objNameSegundaParcial, _segundaParcialVolume);
	   OnDragLineParcial(_objNameTerceiraParcial, _terceiraParcialVolume);
	}
	
	void OnDragLineParcial(string objName, double volume)
	{
	
		for(int i = ObjectsTotal(0, 0, OBJ_HLINE) - 1; i >= 0; i--)						
		{			   			  					 		      
	      if(ObjectGetInteger(0, objName, OBJPROP_SELECTED) == 1)
			{
            ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Saída parcial\nPreço " + 
                           DoubleToString(ObjectGetDouble(0, objName, OBJPROP_PRICE), _Digits) + 
                           "\nVolume " + (string)volume);            
			}		      
		}
	
	}
	
	double GetParcialValue(string objName)
	{	   
	   return NormalizeDouble(ObjectGetDouble(0, objName, OBJPROP_PRICE), _Digits);
	}	
				
	void ClearDraw(string objName)
	{
		ObjectDelete(0, objName);
	}	
	
	void ClearDrawObjects()
	{
		ClearDraw("logo_badrobot");
		ClearDraw("label1_badrobot");
		ClearDraw("label2_badrobot");
		ClearDraw("label3_badrobot");
		ClearDraw("label_candle_remaining");
	}	
	
	void ClearDrawParciais()
	{
	   ClearDraw(_objNamePrimeiraParcial);
		ClearDraw(_objNameSegundaParcial);
		ClearDraw(_objNameTerceiraParcial);
	}
	
   void ClearObjectAutoTrading()
   {		
      if(!_canRewrite) return;
         
	   ObjectsDeleteAll(ChartID(), 0, OBJ_ARROW_BUY);
      ObjectsDeleteAll(ChartID(), 0, OBJ_ARROW_SELL);
      ObjectsDeleteAll(ChartID(), 0, OBJ_TREND);	
   }
	
	void DrawLogo()
	{		
		long height = ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
		long width = 0;
		
		string tooltip = "BadRobot Framework, para mais informaçõe acesse https://github.com/erlonfs/bad-robot.framework";
				
		string objName = "logo_badrobot";				
		ObjectCreate(0, objName, OBJ_BITMAP_LABEL, 0, 0, 0);
		ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, width + 5);
		ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, height - 100);
    	ObjectSetString(0, objName, OBJPROP_BMPFILE, "\\Images\\logo.bmp");
    	ObjectSetString(0, objName, OBJPROP_TOOLTIP, tooltip);
    	ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    	ObjectSetInteger(0, objName, OBJPROP_ZORDER, 999);
		ObjectSetInteger(0, objName, OBJPROP_FILL, true);	
    	    	
    	objName = "label1_badrobot";    	
    	ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    	ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, width + 5);
		ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, height - 62);
		ObjectSetString(0, objName, OBJPROP_TEXT, GetRobotName() + " " + GetRobotVersion());
		ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDimGray);
		ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
		ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
		ObjectSetInteger(0, objName, OBJPROP_ZORDER, 999);
		ObjectSetInteger(0, objName, OBJPROP_BACK, true);
		ObjectSetInteger(0, objName, OBJPROP_FILL, true);	
		
		objName = "label2_badrobot";
		ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    	ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, width + 5);
		ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, height - 47);
		ObjectSetString(0, objName, OBJPROP_TEXT, "BadRobot " + (string)version);
		ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDimGray);
		ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
		ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
		ObjectSetInteger(0, objName, OBJPROP_ZORDER, 999);
		ObjectSetInteger(0, objName, OBJPROP_BACK, true);
		ObjectSetInteger(0, objName, OBJPROP_FILL, true);	
		
		objName = "label3_badrobot";
		ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    	ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, width + 5);
		ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, height - 32);
		ObjectSetString(0, objName, OBJPROP_TEXT, "2016 - " + (string)GetTimeCurrent().year);
		ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDimGray);
		ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
		ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
		ObjectSetInteger(0, objName, OBJPROP_ZORDER, 999);
		ObjectSetInteger(0, objName, OBJPROP_BACK, true);
		ObjectSetInteger(0, objName, OBJPROP_FILL, true);				
	}
	
	void DrawLabelCandleRemaining()
	{
	   string objName = "label_candle_remaining";
	   	   
		if (CopyRates(GetSymbol(), _Period, 0, 1, _ratesRemainingTime) <= 0)
		{
			return;
		}

	   int leftTime = PeriodSeconds(_Period) - (int)(TimeCurrent() - _ratesRemainingTime[0].time);
	   	     
	   if(ObjectFind(0, objName) > -1 && leftTime > 0)
	   {
	      ObjectSetString(0, objName, OBJPROP_TEXT, TimeToString((datetime)leftTime, TIME_SECONDS));	     
	      return;
	   }
	   	   
	   long height = ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
		long width = ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);	

		ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    	ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, width -120);
		ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, height - 32);
		ObjectSetString(0, objName, OBJPROP_TEXT, "00:00:00");	   
		ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDimGray);
		ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
		ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
		ObjectSetInteger(0, objName, OBJPROP_ZORDER, 999);
		ObjectSetInteger(0, objName, OBJPROP_BACK, true);
		ObjectSetInteger(0, objName, OBJPROP_FILL, true);	
	}

	bool RepositionTrade()
	{
		if (!HasPositionOpen()) return false;

		double price = GetPositionPriceOpen();

		if (IsPositionTypeBuy())
		{
			double stopGain = NormalizeDouble((price + ToPoints(GetStopGain())), _Digits);
			double stopLoss = NormalizeDouble((price - ToPoints(GetStopLoss())), _Digits);

			_trade.PositionModify(_symbol, stopLoss, stopGain);
		}
		else
		{
			if (IsPositionTypeSell())
			{
				double stopGain = NormalizeDouble((price - ToPoints(GetStopGain())), _Digits);
				double stopLoss = NormalizeDouble((price + ToPoints(GetStopLoss())), _Digits);

				_trade.PositionModify(_symbol, stopLoss, stopGain);
			}
		}

		_logger.Log("Stop, Gain e gerenciamento retomado");

		return true;

	}

	void SetNewCandle()
	{

		static datetime OldTime;
		datetime NewTime[1];
		bool newBar = false;

		int copied = CopyTime(_symbol, _period, 0, 1, NewTime);

		if (copied > 0 && OldTime != NewTime[0])
		{
			newBar = true;
			OldTime = NewTime[0];
		}

		_isNewCandle = newBar;

	}

	void SetNewday()
	{
		static int oldDay;
		int newDay = GetTimeCurrent().day;
		bool isNewDay = false;

		if (oldDay != newDay)
		{
			isNewDay = true;
			oldDay = newDay;
			_logger.Log("Seja bem vindo ao " + _robotName);
		}

		_isNewDay = isNewDay;

	}
	
	void SetCanRewrite()
	{
	   if(_isRewrite)
	   {
	      _isRewrite = false;
	      _canRewrite = true;
	   }
	   else
	   {
	   	_canRewrite = false;
	   }	   
	   
	}	
	
	void SetIndicatorAllowBuy()
	{
	   _indicatorsAllowBuy = true;	   
	
	   if(_hasIndicatorCrossAverages)
	   {
	      if(_eMA1Period > 0)
	      {
	         _indicatorsAllowBuy = _indicatorsAllowBuy && GetLastPrice() > _eMA1Values[0];
	      }
	      
	      if(_eMA2Period > 0)
	      {
	         _indicatorsAllowBuy = _indicatorsAllowBuy && GetLastPrice() > _eMA2Values[0];
	         
            if(_eMA1Period > 0)
   	      {
   	         _indicatorsAllowBuy = _indicatorsAllowBuy && _eMA1Values[0] > _eMA2Values[0];
   	      }
	      }
	      
         if(_eMA3Period > 0)
	      {
	         _indicatorsAllowBuy = _indicatorsAllowBuy && GetLastPrice() > _eMA3Values[0];
	         
	         if(_eMA2Period > 0)
   	      {
   	         _indicatorsAllowBuy = _indicatorsAllowBuy && _eMA2Values[0] > _eMA3Values[0];
   	         
               if(_eMA1Period > 0)
      	      {
      	         _indicatorsAllowBuy = _indicatorsAllowBuy && _eMA1Values[0] > _eMA3Values[0];
      	      }
   	      }
	      }
	   }
	   
	   if(_hasIndicatorMACD)
	   {
	      _indicatorsAllowBuy = _indicatorsAllowBuy && (_mACD[0] > _mACDSignal[0]);
	   }
	   
	   if(_hasIndicatorRSI)
	   {
	      _indicatorsAllowBuy = _indicatorsAllowBuy && (_rSI[0] <= _rSIBuySignal);
	   }	
	   
	   if(_hasIndicatorSAR)
	   {
	      _indicatorsAllowBuy = _indicatorsAllowBuy && (_sAR[0] < GetLastPrice());
	   }	
	   
	   if(_hasIndicatorBandsBollinger)
	   {
	      _indicatorsAllowBuy = _indicatorsAllowBuy && (GetLastPrice() <= _bandsBollingerLowerBand[0]);
	   }	
	   
	   if(_hasIndicatorEnvelopes)
	   {
	      _indicatorsAllowBuy = _indicatorsAllowBuy && (GetLastPrice() <= _envelopesLowerLine[0]);
	   }		   	      	      
	}
	
	void SetIndicatorAllowSell() 
	{
	   _indicatorsAllowSell = true;
	
      if(_hasIndicatorCrossAverages)
	   {
	      if(_eMA1Period > 0)
	      {
	         _indicatorsAllowSell = _indicatorsAllowSell && GetLastPrice() < _eMA1Values[0];
	      }
	      
	      if(_eMA2Period > 0)
	      {
	         _indicatorsAllowSell = _indicatorsAllowSell && GetLastPrice() < _eMA2Values[0];
	         
            if(_eMA1Period > 0)
   	      {
   	         _indicatorsAllowSell = _indicatorsAllowSell && _eMA1Values[0] < _eMA2Values[0];
   	      }
	      }
	      
         if(_eMA3Period > 0)
	      {
	         _indicatorsAllowSell = _indicatorsAllowSell && GetLastPrice() < _eMA3Values[0];
	         
	         if(_eMA2Period > 0)
   	      {
   	         _indicatorsAllowSell = _indicatorsAllowSell && _eMA2Values[0] < _eMA3Values[0];
   	         
               if(_eMA1Period > 0)
      	      {
      	         _indicatorsAllowSell = _indicatorsAllowSell && _eMA1Values[0] < _eMA3Values[0];
      	      }
   	      }
	      }
	   }
	   
      if(_hasIndicatorMACD)
	   {
	      _indicatorsAllowSell = _indicatorsAllowSell && (_mACD[0] < _mACDSignal[0]);
	   }
	   
	   if(_hasIndicatorRSI)
	   {
	      _indicatorsAllowSell = _indicatorsAllowSell && (_rSI[0] >= _rSISellSignal);
	   }		
	   
	   if(_hasIndicatorSAR)
	   {
	      _indicatorsAllowSell = _indicatorsAllowSell && (_sAR[0] > GetLastPrice());
	   }	 
	   
	   if(_hasIndicatorBandsBollinger)
	   {
	      _indicatorsAllowSell = _indicatorsAllowSell && (GetLastPrice() >= _bandsBollingerUpperBand[0]);
	   }	
	   
	   if(_hasIndicatorEnvelopes)
	   {
	      _indicatorsAllowSell = _indicatorsAllowSell && (GetLastPrice() >= _envelopesUpperLine[0]);
	   }		   	        
	   
	}
	
	int InitIndicators()
	{
	   if(!_hasAnyIndicator) return INIT_SUCCEEDED;
	   	   
	   if(InitCrossAverage() != INIT_SUCCEEDED) return INIT_FAILED;
	   if(InitMACD() != INIT_SUCCEEDED) return INIT_FAILED;
	   if(InitRSI() != INIT_SUCCEEDED) return INIT_FAILED;
	   if(InitSAR() != INIT_SUCCEEDED) return INIT_FAILED;
	   if(InitBandsBollinger() != INIT_SUCCEEDED) return INIT_FAILED;
	   if(InitEnvelops() != INIT_SUCCEEDED) return INIT_FAILED;
	   
	   return INIT_SUCCEEDED;
	   
	}
	
	int InitCrossAverage()
	{
	   if(!_hasIndicatorCrossAverages) return INIT_SUCCEEDED;
	   	
      _eMA1Handle = _eMA1Period > 0 ? iMA(GetSymbol(), GetPeriod(), _eMA1Period, 0, _crossAveragesMethod, _crossAveragesAppliedPrice) : 1;
      _eMA2Handle = _eMA2Period > 0 ? iMA(GetSymbol(), GetPeriod(), _eMA2Period, 0, _crossAveragesMethod, _crossAveragesAppliedPrice) : 1;
      _eMA3Handle = _eMA3Period > 0 ? iMA(GetSymbol(), GetPeriod(), _eMA3Period, 0, _crossAveragesMethod, _crossAveragesAppliedPrice) : 1;
      
      if (_eMA1Handle < 0 || _eMA2Handle < 0 || _eMA3Handle < 0) 
      {
      	Alert("Erro ao criar indicador cross average: ", GetLastError());
      	return INIT_FAILED;
      }
      
      return INIT_SUCCEEDED;
	}
	
	int InitMACD()
	{
	   if(!_hasIndicatorMACD) return INIT_SUCCEEDED;
	   
      _mACDHandle = iMACD(GetSymbol(), GetPeriod(), _mACDFastPeriod, _mACDSlowPeriod, _mACDSignalPeriod, _mACDAppliedPrice);
      
      if(_mACDHandle < 0) 
      {
      	Alert("Erro ao criar indicador MACD: ", GetLastError());
      	return INIT_FAILED;
      }
      
      return INIT_SUCCEEDED;
	}	
	
	int InitRSI()
	{
	   if(!_hasIndicatorRSI) return INIT_SUCCEEDED;
	   
      _rSIHandle = iRSI(GetSymbol(), GetPeriod(), _rSIPeriod, _rSIAppliedPrice);
      
      if(_rSIHandle < 0) 
      {
      	Alert("Erro ao criar indicador RSI: ", GetLastError());
      	return INIT_FAILED;
      }
      
      return INIT_SUCCEEDED;
	}	
	
	int InitSAR()
	{
	   if(!_hasIndicatorSAR) return INIT_SUCCEEDED;
	   
      _sARHandle = iSAR(GetSymbol(), GetPeriod(), _sARStep, _sARMaximum);
      
      if(_sARHandle < 0) 
      {
      	Alert("Erro ao criar indicador SAR: ", GetLastError());
      	return INIT_FAILED;
      }
      
      return INIT_SUCCEEDED;
	}
	
	int InitBandsBollinger()
	{
	   if(!_hasIndicatorBandsBollinger) return INIT_SUCCEEDED;
	   
      _bandsBollingerHandle = iBands(GetSymbol(), GetPeriod(), _bandsBollingerPeriod, _bandsBollingerShift, _bandsBollingerDeviation, _bandsBollingerAppliedPrice);
      
      if(_bandsBollingerHandle < 0) 
      {
      	Alert("Erro ao criar indicador Bands Bollinger: ", GetLastError());
      	return INIT_FAILED;
      }
      
      return INIT_SUCCEEDED;
	}	
	
	int InitEnvelops()
	{
	   if(!_hasIndicatorEnvelopes) return INIT_SUCCEEDED;
	   
      _envelopesHandle = iEnvelopes(GetSymbol(), GetPeriod(), _envelopesPeriod, _envelopesShift, _envelopesMethod, _envelopesAppliedPrice, _envelopesDeviation);
      
      if(_envelopesHandle < 0) 
      {
      	Alert("Erro ao criar indicador Envelops: ", GetLastError());
      	return INIT_FAILED;
      }
      
      return INIT_SUCCEEDED;
	}				
	
	bool GetBuffersIndicators()
	{
	   if(!_hasAnyIndicator) return true;
	   
	   if(!GetBufferCrossAverage()) return false;
	   if(!GetBufferMACD()) return false;
	   if(!GetBufferRSI()) return false;
	   if(!GetBufferSAR()) return false;
	   if(!GetBufferBandsBollinger()) return false;
	   if(!GetBufferEnvelopes()) return false;
	   
	   return true;
	  
	   
	}
	
	bool GetBufferCrossAverage()
	{	
	   if(!_hasIndicatorCrossAverages) return true;
	   
	   int copiedMA1Buffer = 1;
	   int copiedMA2Buffer = 1;
	   int copiedMA3Buffer = 1;
	   
	   if(_eMA1Period > 0)
	   {
         ZeroMemory(_eMA1Values);
         ArraySetAsSeries(_eMA1Values, true);
         ArrayFree(_eMA1Values);
         
         copiedMA1Buffer = CopyBuffer(_eMA1Handle, 0, 0, 2, _eMA1Values);
	   }
	   
      if(_eMA2Period > 0)
	   {
         ZeroMemory(_eMA2Values);
         ArraySetAsSeries(_eMA2Values, true);
         ArrayFree(_eMA2Values);
         
         copiedMA2Buffer = CopyBuffer(_eMA2Handle, 0, 0, 2, _eMA2Values);
	   }
	   
	   if(_eMA3Period > 0)
	   {
         ZeroMemory(_eMA3Values);
         ArraySetAsSeries(_eMA3Values, true);
         ArrayFree(_eMA3Values);
         
         copiedMA3Buffer = CopyBuffer(_eMA3Handle, 0, 0, 2, _eMA3Values);
	   }	   
      
      return copiedMA1Buffer > 0 && copiedMA2Buffer > 0 && copiedMA3Buffer > 0;
      
	}
	
   bool GetBufferMACD()
	{	
	   if(!_hasIndicatorMACD) return true;
	   	  
      ZeroMemory(_mACD);  
      ArraySetAsSeries(_mACD, true);
      ArrayFree(_mACD);
      
      ZeroMemory(_mACDSignal);
      ArraySetAsSeries(_mACDSignal, true);
      ArrayFree(_mACDSignal);
      
      int copiedMACDBuffer = CopyBuffer(_mACDHandle, 0, 0, 2, _mACD);
      int copiedMACDSignalBuffer = CopyBuffer(_mACDHandle, 1, 0, 2, _mACDSignal);
      
      return copiedMACDBuffer > 0 && copiedMACDSignalBuffer > 0;     
   }
	   
   bool GetBufferRSI()
	{	
	   if(!_hasIndicatorRSI) return true;
	   	  
      ZeroMemory(_rSI);  
      ArraySetAsSeries(_rSI, true);
      ArrayFree(_rSI);
      
      int copiedBuffer = CopyBuffer(_rSIHandle, 0, 0, 2, _rSI);
      
      return copiedBuffer > 0; 
          
   }	
   
   bool GetBufferSAR()
	{	
	   if(!_hasIndicatorSAR) return true;
	   	  
      ZeroMemory(_sAR);  
      ArraySetAsSeries(_sAR, true);
      ArrayFree(_sAR);
      
      int copiedBuffer = CopyBuffer(_sARHandle, 0, 0, 2, _sAR);     
      
      return copiedBuffer > 0; 
          
   }	
   
   bool GetBufferBandsBollinger()
	{	
	   if(!_hasIndicatorBandsBollinger) return true;
	   	  
      ZeroMemory(_bandsBollingerBaseLine);  
      ArraySetAsSeries(_bandsBollingerBaseLine, true);
      ArrayFree(_bandsBollingerBaseLine);
      
      ZeroMemory(_bandsBollingerUpperBand);  
      ArraySetAsSeries(_bandsBollingerUpperBand, true);
      ArrayFree(_bandsBollingerUpperBand);
      
      ZeroMemory(_bandsBollingerLowerBand);  
      ArraySetAsSeries(_bandsBollingerLowerBand, true);
      ArrayFree(_bandsBollingerLowerBand);
      
      int copiedBufferBaseLine = CopyBuffer(_bandsBollingerHandle, BASE_LINE, 0, 2, _bandsBollingerBaseLine);     
      int copiedBufferUpperBand = CopyBuffer(_bandsBollingerHandle, UPPER_BAND, 0, 2, _bandsBollingerUpperBand);     
      int copiedBufferLowerBand = CopyBuffer(_bandsBollingerHandle, LOWER_BAND, 0, 2, _bandsBollingerLowerBand);     
      
      return copiedBufferBaseLine > 0 && copiedBufferUpperBand > 0 && copiedBufferLowerBand > 0; 
          
   }
   
   bool GetBufferEnvelopes()
	{	
	   if(!_hasIndicatorEnvelopes) return true;
	   	  
      ZeroMemory(_envelopesUpperLine);  
      ArraySetAsSeries(_envelopesUpperLine, true);
      ArrayFree(_envelopesUpperLine);
      
      ZeroMemory(_envelopesLowerLine);  
      ArraySetAsSeries(_envelopesLowerLine, true);
      ArrayFree(_envelopesLowerLine);
         
      int copiedBufferUpperLine = CopyBuffer(_envelopesHandle, UPPER_LINE, 0, 2, _envelopesUpperLine);     
      int copiedBufferLowerLine = CopyBuffer(_envelopesHandle, LOWER_LINE, 0, 2, _envelopesLowerLine);     
      
      return copiedBufferUpperLine > 0 && copiedBufferLowerLine > 0; 
          
   }   	      	
   
	protected:	
	
	int virtual OnInitHandler()
	{                                                             
	   return INIT_SUCCEEDED;
	}      
   
   void virtual OnDeinitHandler(const int reason)
   {
		
	}
	
	void virtual OnTickHandler(){                                                             
	   
	}
	
	void virtual OnTimerHandler(){
	   
	}
	
	void virtual OnTradeHandler(){
	   
	}
	
	void virtual OnTradeTransactionHandler(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
	{
		
	}
	
	double virtual OnTesterHandler()
	{
		return 0;
	}
	
	void virtual OnTesterInitHandler()
	{
		
	}
	
	void virtual OnTesterPassHandler()
	{
		
	}
	
	void OnTesterDeinitHandler()
	{
		
	}
	
	void virtual OnBookEventHandler(const string& symbol)
	{
		
	}
	
	void virtual OnChartEventHandler(const int id, const long& lparam, const double& dparam, const string& sparam)
	{
	   
	}	
	
   void virtual OnShowInfoHandler()
	{					
	
	}
	
   void virtual OnManagePositionHandler()
	{					
	
	}			

   void SetInfo(string value)
	{
		if(_lastTextInfo != value)
		{
			_lastTextInfo = value;
			_isRewrite = true;
		}
	}

	int GetPositionType()
	{
		return (int)PositionGetInteger(POSITION_TYPE);
	}
	
	bool IsPositionTypeBuy()
	{
	   return GetPositionType() == POSITION_TYPE_BUY;
	}
	
	bool IsPositionTypeSell()
	{
	   return GetPositionType() == POSITION_TYPE_SELL;
	}	

	double GetPositionGain()
	{
		return PositionGetDouble(POSITION_TP);
	}
	
	double GetPositionProfit()
	{
		return PositionGetDouble(POSITION_PROFIT);
	}	

	double GetPositionLoss()
	{
		return PositionGetDouble(POSITION_SL);
	}

	int GetPositionMagicNumber()
	{
		return (int)PositionGetInteger(POSITION_MAGIC);
	}

	double GetPositionPriceOpen()
	{
		return NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), _Digits);
	}

	double GetPositionVolume()
	{
		return PositionGetDouble(POSITION_VOLUME);
	}
	
	double GetSymbolTickSize()		
	{		
      if(GetSymbol() == "WIN$"){ return 5.0; }
      if(GetSymbol() == "WIN@"){ return 5.0; }
      if(GetSymbol() == "WDO$"){ return 0.5; }
      if(GetSymbol() == "WDO@"){ return 0.5; }
	   
		return SymbolInfoDouble(_symbol, SYMBOL_TRADE_TICK_SIZE);		
	}
	
	double GetSymbolVolumeSize()		
	{	
		return SymbolInfoDouble(_symbol, SYMBOL_TRADE_CONTRACT_SIZE);				
	}
	
	string GetPositionVolumeText()
	{
		return HasPositionOpen() ? (IsPositionTypeSell() ? "-" : "") + DoubleToString(GetPositionVolume(), 2) : "0";
	}

	bool HasPositionLossOrPositionGain()
	{
		return GetPositionLoss() > 0.0 && GetPositionGain() > 0.0;
	}
	
	Logger GetLogger()
	{
		return _logger;
	}

	double GetLastPrice()
	{
	   if(_lastPriceType == ENUM_LAST_PRICE_TYPE_LAST)
	   {
	      return _price.last;
	   }
	   
	   if(_lastPriceType == ENUM_LAST_PRICE_TYPE_ASK_OR_BID)
	   {	
	      return (IsPositionTypeSell() ? _price.ask : _price.bid);	   
	   }
	   
	   return NormalizeDouble(0, _Digits);
	   
	}
	
	datetime GetLastTime()
	{	   
	   return _price.time;	   
	}	

	MqlDateTime GetTimeCurrent()
	{
		TimeCurrent(_timeCurrent);
		return _timeCurrent;
	}

	bool Validate()
	{
		bool isValid = true;
		MqlDateTime time = GetTimeCurrent();
				
		if(_horaInicioString != NULL && _horaFimString != NULL)
      {
   		if (time.hour < GetHoraInicio().hour || time.hour > GetHoraFim().hour)
   		{
   			isValid = false;
   		}
   
   		if (time.hour == GetHoraInicio().hour && time.min < GetHoraInicio().min)
   		{
   			isValid = false;
   		}
   
   		if (time.hour == GetHoraFim().hour && time.min > GetHoraFim().min)
   		{
   			isValid = false;
   		}
   
   		if (!isValid)
   		{
   			_logger.Log("Horário somente entre " + _horaInicioString + " e " + _horaFimString);
   		}
		}

		if (isValid && (_horaInicioIntervaloString != NULL && _horaFimIntervaloString != NULL))
		{
			if (time.hour >= GetHoraInicioIntervalo().hour && time.hour <= GetHoraFimIntervalo().hour)
			{
				if (time.min >= GetHoraInicioIntervalo().min && time.min <= GetHoraFimIntervalo().min)
				{
					isValid = false;
					_logger.Log("Horário deve estar fora do intervalo de " + _horaInicioIntervaloString + " e " + _horaFimIntervaloString);
				}
			}
		}

		if (!_isAlertMode && isValid)
		{

			if (_isGerenciamentoFinanceiro)
			{

				if (GetTotalLucro() >= _maximoLucroDiario)
				{
					isValid = false;
					_logger.Log("Lucro máximo atingido. R$ " + (string)GetTotalLucro());
				}

				if (GetTotalLucro() <= _maximoPrejuizoDiario)
				{
					isValid = false;
					_logger.Log("Prejuizo máximo atingido. R$ " + (string)GetTotalLucro());
				}
			}

			if (_isParcial && (_primeiraParcialVolume + _segundaParcialVolume + _terceiraParcialVolume) > _volume)
			{
				isValid = false;
				_logger.Log("Valores de parciais inválidos! Verifique-os.");
			}

			if (_isBreakEven)
			{
				if (_breakEven > _breakEvenInicio)
				{
					isValid = false;
					_logger.Log("O Valor do break-even não pode ser maior do que do valor de inicio do mesmo.");
				}
			}
		}

		if (!isValid)
		{		
			if (_logger.Last() != _lastTextValidate)
			{
				SendNotification(_logger.Last());
				SendMail(_robotName, _logger.Last());
				MessageBox(_logger.Last());
			}

			_lastTextValidate = _logger.Last();
			

		}

		return isValid;

	}

	void ShowMessage(string text)
	{
		if (text != "" && text != _lastText)
		{
			string message = GetRobotName() + " (" + GetSymbol() + ", " + ToPeriodText(_period) + ")" + ": " + text;

			if (_isAlertMode)
			{
				Alert(message);
			}
			else
			{
				_logger.Log(text);
			}

			if (_isNotificacoesApp)
			{
				SendNotification(message);
			}
		}

		_lastText = text;

	}	

	void Buy(double price = 0.0, double volume = 0.0, bool isInverted = false)
	{
		if (!Validate() || (!IndicatorsAllowBuy() && !_isInverted))return;
		
		if(!isInverted && _isInverted)
		{
		   Sell(price, volume, true);
		   return;
		}
				
		double stopGain = 0.0;
		double stopLoss = 0.0;
		string msg = "Compra à mercado";

      if(price > 0.0)
      {
		   stopGain = NormalizeDouble((price + ToPoints(GetStopGain())), _Digits);
		   stopLoss = NormalizeDouble((price - ToPoints(GetStopLoss())), _Digits);
		   msg = "Compra em " + (string)price;
		}


		_logger.Log(msg);

		if (_isAlertMode)
		{
			Alert(msg);
			return;
		}

		_trade.Buy(volume > 0 ? volume : _volume, _symbol, price, stopLoss, stopGain, "ORDEM AUTOMATICA - " + _robotName);
		ResetPosition();
	}
	
	void BuyStop(double price, double volume = 0.0, bool isInverted = false)
	{
		if (!Validate()) return;
		
      if(!isInverted && _isInverted)
		{
		   SellStop(price, volume, _isInverted);
		   return;
		}
		
		double stopGain = 0.0;
		double stopLoss = 0.0;
		string msg = "Compra à mercado";

      if(price > 0.0)
      {
		   stopGain = NormalizeDouble((price + ToPoints(GetStopGain())), _Digits);
		   stopLoss = NormalizeDouble((price - ToPoints(GetStopLoss())), _Digits);
		   msg = "Compra em " + (string)price;
		}

		_logger.Log(msg);

		if (_isAlertMode)
		{
			Alert(msg);
			return;
		}

		_trade.BuyStop(volume > 0 ? volume : _volume, price, _symbol, stopLoss, stopGain);
		
	}
	
	void BuyLimit(double price, double volume = 0.0, bool isInverted = false)
	{
		if (!Validate()) return;
		
      if(!isInverted && _isInverted)
		{
		   SellStop(price, volume, _isInverted);
		   return;
		}
		
		double stopGain = 0.0;
		double stopLoss = 0.0;
		string msg = "Compra à mercado";

      if(price > 0.0)
      {
		   stopGain = NormalizeDouble((price + ToPoints(GetStopGain())), _Digits);
		   stopLoss = NormalizeDouble((price - ToPoints(GetStopLoss())), _Digits);
		   msg = "Compra limit em " + (string)price;
		}

		_logger.Log(msg);

		if (_isAlertMode)
		{
			Alert(msg);
			return;
		}

		_trade.BuyLimit(volume > 0 ? volume : _volume, price, _symbol, stopLoss, stopGain);
		
	}
	
	void Sell(double price = 0.0, double volume = 0.0, bool isInverted = false)
	{
		if (!Validate() || (!IndicatorsAllowSell() && !_isInverted))return;
		
		if(!isInverted && _isInverted)
		{
		   Buy(price, volume, _isInverted);
		   return;
		}				

		double stopGain = 0.0;
		double stopLoss = 0.0;
		string msg = "Venda à mercado";		
		
		if(price > 0.0)
		{		
		   stopGain = NormalizeDouble((price - ToPoints(GetStopGain())), _Digits);
		   stopLoss = NormalizeDouble((price + ToPoints(GetStopLoss())), _Digits);
		   msg = "Venda em " + (string)price;
		}
		
		_logger.Log(msg);

		if (_isAlertMode)
		{
			Alert(msg);
			return;
		}

		_trade.Sell(volume > 0 ? volume : _volume, _symbol, price, stopLoss, stopGain, "ORDEM AUTOMATICA - " + _robotName);
		ResetPosition();
	}
	
	void SellStop(double price, double volume = 0.0, bool isInverted = false)
	{
		if (!Validate())return;
		
		if(!isInverted && _isInverted)
		{
		   BuyStop(price, volume, _isInverted);
		   return;
		}			

		double stopGain = 0.0;
		double stopLoss = 0.0;
		string msg = "Venda à mercado";		
		
		if(price > 0.0)
		{		
		   stopGain = NormalizeDouble((price - ToPoints(GetStopGain())), _Digits);
		   stopLoss = NormalizeDouble((price + ToPoints(GetStopLoss())), _Digits);
		   msg = "Venda em " + (string)price;
		}
		
		_logger.Log(msg);

		if (_isAlertMode)
		{
			Alert(msg);
			return;
		}

		_trade.SellStop(volume > 0 ? volume : _volume, price, _symbol, stopLoss, stopGain);

	}	
	
	void SellLimit(double price, double volume = 0.0, bool isInverted = false)
	{
		if (!Validate())return;
		
		if(!isInverted && _isInverted)
		{
		   BuyStop(price, volume, _isInverted);
		   return;
		}			

		double stopGain = 0.0;
		double stopLoss = 0.0;
		string msg = "Venda à mercado";		
		
		if(price > 0.0)
		{		
		   stopGain = NormalizeDouble((price - ToPoints(GetStopGain())), _Digits);
		   stopLoss = NormalizeDouble((price + ToPoints(GetStopLoss())), _Digits);
		   msg = "Venda limit em " + (string)price;
		}
		
		_logger.Log(msg);

		if (_isAlertMode)
		{
			Alert(msg);
			return;
		}

		_trade.SellLimit(volume > 0 ? volume : _volume, price, _symbol, stopLoss, stopGain);

	}	

	void ClosePosition()
	{
		if(!HasPositionOpen())
		{
			_logger.Log("Não existe posição em aberto");
			return;			
		}
		
		_trade.PositionClose(_symbol);
		_logger.Log("Posição total zerada.");
	}
	
	void CancelPendingOrders()
	{		
	   int ord_total=OrdersTotal();
	   
	   for(int i=ord_total-1;i>=0;i--)
	   {
	      ulong ticket=OrderGetTicket(i);
	      if(OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL)==_symbol)
	      {
	         _trade.OrderDelete(ticket);
	         _logger.Log("Ordem com ticket " + IntegerToString(ticket) + " cancelada");
	      }
		}     
	}
	
	void InvertPosition()
	{	
		if(!HasPositionOpen())
		{
			_logger.Log("Não existe posição em aberto");
			return;			
		}
			
		if(IsPositionTypeBuy())
		{
		   if (_account.IsHedging()) 
		   {
		      ClosePosition();
		      _trade.Sell(GetPositionVolume());
		   } else {
		      _trade.Sell(GetPositionVolume() * 2.0);
		   }
			_logger.Log("Posição invertida para vendido");
		}
		
		if(IsPositionTypeSell())
		{
		   if (_account.IsHedging()) 
		   {
		      ClosePosition();
		      _trade.Buy(GetPositionVolume());	
		   } else {
			   _trade.Buy(GetPositionVolume() * 2.0);		   
		   }
			_logger.Log("Posição invertida para comprado");
		}	
		
		ResetPosition();
							
	}
	
	bool ExecutePrimeiraParcial()
	{
		if(_isPrimeiraParcialExecuted) return false;	
		
		if(!HasPositionOpen())
		{
			_logger.Log("Não existe posição em aberto");
			return false;			
		}
		
		if(GetPositionVolume() < _primeiraParcialVolume)
		{
			_logger.Log("Volume da parcial maior do que posição atual");
			return false;
		}
	
		_isPrimeiraParcialExecuted = true;		
		
		if(IsPositionTypeBuy())
		{
		   if (_account.IsHedging())
		   {
		      ClosePartial(_primeiraParcialVolume, _symbol);
		   } else {
		      _trade.Sell(_primeiraParcialVolume, _symbol);	
		   }		
		}
		
		if(IsPositionTypeSell())
		{
		   if (_account.IsHedging())
		   {
		      ClosePartial(_primeiraParcialVolume, _symbol);
		   } else {
		      _trade.Buy(_primeiraParcialVolume, _symbol);	
		   }			
		}
		
		_logger.Log("Saída parcial em " + (string)GetLastPrice() + " com volume " + (string)_primeiraParcialVolume);
		
		return true;
		
	}
	
	bool ExecuteSegundaParcial()
	{		
		if(_isSegundaParcialExecuted) return false;	
		
		if(!HasPositionOpen())
		{
			_logger.Log("Não existe posição em aberto");
			return false;			
		}
		
		if(GetPositionVolume() < _segundaParcialVolume)
		{
			_logger.Log("Volume da parcial maior do que posição atual");
			return false;
		}	
	
		_isSegundaParcialExecuted = true;		
		
		if(IsPositionTypeBuy())
		{
		   if (_account.IsHedging())
		   {
		      ClosePartial(_segundaParcialVolume, _symbol);
		   } else {
		      _trade.Sell(_segundaParcialVolume, _symbol);	
		   }		
		}
		
		if(IsPositionTypeSell())
		{
		   if (_account.IsHedging())
		   {
		      ClosePartial(_segundaParcialVolume, _symbol);
		   } else {
		      _trade.Buy(_segundaParcialVolume, _symbol);	
		   }			
		}
		
		_logger.Log("Saída parcial em " + (string)GetLastPrice() + " com volume " + (string)_segundaParcialVolume);
		
		return true;
		
	}	
	
	bool ExecuteTerceiraParcial()
	{		
		if(_isTerceiraParcialExecuted) return false;	
			
		if(!HasPositionOpen())
		{
			_logger.Log("Não existe posição em aberto");
			return false;			
		}
		
		if(GetPositionVolume() < _terceiraParcialVolume)
		{
			_logger.Log("Volume da parcial maior do que posição atual");
			return false;
		}	
			
		_isTerceiraParcialExecuted = true;		
		
		if(IsPositionTypeBuy())
		{
		   if (_account.IsHedging())
		   {
		      ClosePartial(_terceiraParcialVolume, _symbol);
		   } else {
		      _trade.Sell(_terceiraParcialVolume, _symbol);	
		   }				
		}
		
		if(IsPositionTypeSell())
		{
		   if (_account.IsHedging())
		   {
		      ClosePartial(_terceiraParcialVolume, _symbol);
		   } else {
		      _trade.Buy(_terceiraParcialVolume, _symbol);	
		   }			
		}
		
		_logger.Log("Saída parcial em " + (string)GetLastPrice() + " com volume " + (string)_terceiraParcialVolume);
		
		return true;
		
	}		

	bool HasPositionOpen()
	{
		return _positionInfo.Select(_symbol) && GetPositionMagicNumber() == _trade.RequestMagic();
	}

	bool HasOrderOpen()
	{
		int orderCount = 0;

		for (int i = 0; i < OrdersTotal(); i++)
		{
			if (OrderSelect(OrderGetTicket(i)) && OrderGetString(ORDER_SYMBOL) == _symbol && OrderGetInteger(ORDER_MAGIC) == _trade.RequestMagic())
			{
				orderCount++;
			}
		}

		return orderCount > 0;
		
	}
	
	void CloseHasOrderOpen(int _basePoints)
	{
		for (int i = 0; i < OrdersTotal(); i++)
		{
			if (OrderSelect(OrderGetTicket(i)) && OrderGetString(ORDER_SYMBOL) == _symbol && OrderGetInteger(ORDER_MAGIC) == _trade.RequestMagic())
			{
				double orderOpenPrice = OrderGetDouble(ORDER_PRICE_OPEN);
				
				if (MathAbs(orderOpenPrice - GetLastPrice()) > _basePoints)
				{
				   CancelPendingOrders();
				   
				   _logger.Log("Cancelando ordem pendente "+ (string)OrderGetTicket(i) +" compreço de entrada em "+ (string)orderOpenPrice +" e divergencia de "+ (string)_basePoints);
				}
			}
		}		
	}
				
	public:

	BadRobotCore()
	{
		//_logger = new Logger(Logger &_logger);
		_account = new Account();
		_trade.LogLevel(LOG_LEVEL_ERRORS);
		
		_objNamePrimeiraParcial = "PRIMEIRA_PARCIAL";
      _objNameSegundaParcial = "SEGUNDA_PARCIAL";
      _objNameTerceiraParcial = "TERCEIRA_PARCIAL";
	}
	
	~BadRobotCore(void)
	{
		
	}
	
	int OnInit(){             
	                                                		
		//EventSetMillisecondTimer(800);
		EventSetTimer(1);
		
		int initCode = InitIndicators();
		
		if(initCode != INIT_SUCCEEDED)
		{
		   return initCode;
		}
				
	   return OnInitHandler();  
	   
	}
	
	void OnDeinit(const int reason){
	
		if(reason != REASON_CHARTCHANGE)
		{
			ClearDrawObjects();
			ClearDrawParciais();
		
			Comment("");
			EventKillTimer(); 
			
			printf("Obrigado por utilizar o " + GetRobotName() + " " + GetRobotVersion());
		}		
		
		OnDeinitHandler(reason);
		
	}
	
	void OnTick(){   		
      
      if (!SymbolInfoTick(_symbol, _price))
		{
			Alert("Erro ao obter a última cotação de preço: ", GetLastError());
			return;
		}
		
      if(!GetBuffersIndicators())
      {
         Alert("Erro ao obter indicadores!");
         return;
      }
		
		SetNewday();
		SetNewCandle();
		SetIndicatorAllowBuy();
		SetIndicatorAllowSell();

		if (HasPositionOpen())
		{
			ManagePosition();			
			OnManagePositionHandler();
			return;
			
		}

		ManageDealsProfit();
		ClearObjectAutoTrading();
			
		if (!Validate()){return;}

		OnManagePositionHandler();			      
	   OnTickHandler();  
	   
	}
	
	void OnTimer()
	{		
	   SetCanRewrite();
	   
	   if(_canRewrite)
	   {
	   	OnShowInfoHandler();		
	   }
	   
	   OnDragParcial();
	   ManageDrawParcial();
	   OnTimerHandler();	   	   
	   DrawLabelCandleRemaining();
	   
	   ChartRedraw();	   
	   
	}
	
	void OnTrade(){
		
		_isRewrite = true;

		if(!HasPositionOpen())
		{
			ResetPosition();
		}
		
		ManageDealsProfit();		
      ManageDrawParcial();		
	   OnTradeHandler();	   
	   
	}
	
	void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result)
	{
		OnTradeTransactionHandler(trans, request, result);
	}
	
	double OnTester()
	{
		return OnTesterHandler();
	}
	
	void OnTesterInit()
	{
		OnTesterInitHandler();
	}
	
	void OnTesterPass()
	{
		OnTesterPassHandler();
	}
	
	void OnTesterDeinit()
	{
		OnTesterDeinitHandler();
	}
	
	void OnBookEvent(const string& symbol)
	{
		OnBookEventHandler(symbol);
	}
	
	void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
	{
		ChartEvent(id, lparam, dparam, sparam);
		
		if(id == CHARTEVENT_CHART_CHANGE)
     	{
     	   ClearDrawObjects();
			//DrawLogo();
			DrawLabelCandleRemaining();
		}
		else
		{
		}
		
		OnShowInfoHandler();
				
	   OnChartEventHandler(id, lparam, dparam, sparam);   
	   
	}	
	
   void ClosePartial(double volume, string symbol)
   {
       ulong ticket = PositionGetInteger(POSITION_TICKET);
       double _deviation = 10 * _Point;
   
       _trade.PositionClosePartial(symbol, volume, _deviation);
   }	

	void SetPeriod(ENUM_TIMEFRAMES period)
	{
		_period = period;
	};	

	ENUM_TIMEFRAMES GetPeriod()
	{
		return _period;
	};

	string ToPeriodText(ENUM_TIMEFRAMES period)
	{

		string aux[];

		StringSplit(EnumToString(period), '_', aux);

		return aux[1];

	};
	
	void SetLastPriceType(ENUM_LAST_PRICE_TYPE value)
	{
		_lastPriceType = value;
	};
	
	double ToPoints(int tickValue)
	{
	   return tickValue * GetSymbolTickSize();
	}

	void SetSymbol(string symbol)
	{
		_symbol = symbol;
	};

	void SetVolume(double volume)
	{
		_volume = volume;
	}

	double GetVolume()
	{
		return _volume;
	}

	string GetSymbol()
	{
		return _symbol;
	}

	void SetSpread(int value)
	{
		_spread = value;
	};

	void SetIsClosePosition(bool value)
	{
		_isClosePosition = value;
	}

	int GetSpread()
	{
		return _spread;
	}

	void SetStopGain(int value)
	{
		_stopGain = value;
	};

	int GetStopGain()
	{
		return _stopGain;
	};

	void SetStopLoss(int value)
	{
		_stopLoss = value;
	};

	int GetStopLoss()
	{
		return _stopLoss;
	};

	void SetIsStopOnLastCandle(bool value)
	{
		_isStopOnLastCandle = value;
	}

	void SetSpreadStopOnLastCandle(int value)
	{
		_spreadStopOnLastCandle = value;
	}
	
	void SetIsPeriodCustomStopOnLastCandle(bool value)
	{
		_isPeriodCustom = value;
	}
	
	void SetPeriodStopOnLastCandle(ENUM_TIMEFRAMES period)
	{
		_periodStopOnLastCandle = period;
	};
	
	void SetWaitBreakEvenExecuted(bool value)
	{
		_waitBreakEvenExecuted = value;
	}

	int GetSpreadStopOnLastCandle()
	{
		return _spreadStopOnLastCandle;
	}

	void SetNumberMagic(ulong value)
	{
	   _magicNumber = value;
		_trade.SetExpertMagicNumber(value);
	}
	
	ulong GetNumberMagic()
	{
		return _magicNumber;
	}

	double GetTotalLucro()
	{
		return _totalProfitMoney + _totalStopLossMoney;
	}
	
	double GetTotalProfitMoney()
	{
	   return _totalProfitMoney;
	}
	
	double GetTotalStopLossMoney()
	{
	   return _totalStopLossMoney;
	}

	MqlDateTime GetHoraInicio()
	{
		return _horaInicio;
	};

	MqlDateTime GetHoraFim()
	{
		return _horaFim;
	};

	MqlDateTime GetHoraInicioIntervalo()
	{
		return _horaInicioIntervalo;
	};

	MqlDateTime GetHoraFimIntervalo()
	{
		return _horaFimIntervalo;
	};

	void SetHoraInicio(string hora)
	{
		_horaInicioString = hora;
		TimeToStruct(StringToTime("1990.04.02 " + hora), _horaInicio);
	};

	void SetHoraFim(string hora)
	{
		_horaFimString = hora;
		TimeToStruct(StringToTime("1990.04.02 " + hora), _horaFim);
	};

	void SetHoraInicioIntervalo(string hora)
	{
		_horaInicioIntervaloString = hora;
		TimeToStruct(StringToTime("1990.04.02 " + hora), _horaInicioIntervalo);
	};

	void SetHoraFimIntervalo(string hora)
	{
		_horaFimIntervaloString = hora;
		TimeToStruct(StringToTime("1990.04.02 " + hora), _horaFimIntervalo);
	};

	void SetMaximoLucroDiario(double valor)
	{
		_maximoLucroDiario = valor;
	};

	void SetMaximoPrejuizoDiario(double valor)
	{
		_maximoPrejuizoDiario = valor * -1;
	};

	void SetIsTrailingStop(bool flag)
	{
		_isTrailingStop = flag;
	}

	void SetTrailingStopInicio(int valor)
	{
		_trailingStopInicio = valor;
	};

	void SetTrailingStop(int valor)
	{
		_trailingStop = valor;
	};

	void SetIsBreakEven(bool flag)
	{
		_isBreakEven = flag;
	}

	void SetBreakEven(int valor)
	{
		_breakEven = valor;
	}

	void SetBreakEvenInicio(int valor)
	{
		_breakEvenInicio = valor;
	};

	void SetIsParcial(bool flag)
	{
		_isParcial = flag;
	}

	void SetPrimeiraParcialInicio(int valor)
	{
		_primeiraParcialInicio = valor;
	}

	void SetPrimeiraParcialVolume(double valor)
	{
		_primeiraParcialVolume = valor;
	}

	void SetSegundaParcialInicio(int valor)
	{
		_segundaParcialInicio = valor;
	}

	void SetSegundaParcialVolume(double valor)
	{
		_segundaParcialVolume = valor;
	}

	void SetTerceiraParcialInicio(int valor)
	{
		_terceiraParcialInicio = valor;
	}

	void SetTerceiraParcialVolume(double valor)
	{
		_terceiraParcialVolume = valor;
	}

	void SetIsGerenciamentoFinanceiro(bool flag)
	{
		_isGerenciamentoFinanceiro = flag;
	}

	void SetRobotName(string name)
	{
		_robotName = name;
	}

	string GetRobotName()
	{
		return _robotName;
	}

	void SetRobotVersion(string valor)
	{
		_robotVersion = valor;
	}

	string GetRobotVersion()
	{
		return _robotVersion;
	}

	void SetIsNotificacoesApp(bool flag)
	{
		_isNotificacoesApp = flag;
	}

	void SetIsAlertMode(bool flag)
	{
		_isAlertMode = flag;
	}
	
	void SetIsInvertedMode(bool flag)
	{
		_isInverted = flag;
	}	

	bool IsNewCandle()
	{
		return _isNewCandle;
	}

	bool IsNewDay()
	{
		return _isNewDay;
	}
	
	bool IsGerenciamentoFinanceiro()
	{
		return _isGerenciamentoFinanceiro;
	}
	
	bool IsParcial()
	{
		return _isParcial;
	}		
	
	bool IsPrimeiraParcialExecuted()
	{
		return _isPrimeiraParcialExecuted;
	}
	
	int GetPrimeiraParcialInicio()
	{
		return _primeiraParcialInicio;
	}	
	
	double GetPrimeiraParcialVolume()
	{
		return _primeiraParcialVolume;
	}	
	
	bool IsSegundaParcialExecuted()
	{
		return _isSegundaParcialExecuted;
	}
	
	int GetSegundaParcialInicio()
	{
		return _segundaParcialInicio;
	}	
	
	double GetSegundaParcialVolume()
	{
		return _segundaParcialVolume;
	}		
	
	bool IsTerceiraParcialExecuted()
	{
		return _isTerceiraParcialExecuted;
	}
	
	int GetTerceiraParcialInicio()
	{
		return _terceiraParcialInicio;
	}	
	
	double GetTerceiraParcialVolume()
	{
		return _terceiraParcialVolume;
	}
	
	bool IsBreakEven()
	{
		return _isBreakEven;
	}	
	
	int GetBreakEven()
	{
		return _breakEven;
	}	
	
	int GetBreakEvenInicio()
	{
		return _breakEvenInicio;
	}	
	
	bool IsBreakEvenExecuted()
	{
		return _isBreakEvenExecuted;
	}			
	
	bool IsModeAlert()
	{
		return _isAlertMode;
	}	
	
	bool IsTrailingStop()
	{
		return _isTrailingStop;
	}	
	
	int GetTrailingStop()
	{
		return _trailingStop;
	}	
	
	int GetTrailingStopInicio()
	{
		return _trailingStopInicio;
	}	
	
	bool IsStopOnLastCandle()
	{
		return _isStopOnLastCandle;
	}
	
	ENUM_TIMEFRAMES GetPeriodStopOnLastCandle()
	{
		return _periodStopOnLastCandle;
	}	
	
	string GetLastTextInfo()
	{
		return _lastTextInfo;
	}	
	
	bool IndicatorsAllowBuy()
	{
	   return _indicatorsAllowBuy;
	}				
	
	bool IndicatorsAllowSell()
	{
	   return _indicatorsAllowSell;
	}
	
   void SetHasIndicatorCrossAveragess(int flag)
   {
      _hasIndicatorCrossAverages = flag;
      
      if(flag)
      {
         _hasAnyIndicator = flag;
      }
   }
   
   void SetEMA1Period(int ema) 
   {
      _eMA1Period = ema;
   };
   
   void SetEMA2Period(int ema) 
   {
      _eMA2Period = ema;
   };  
   
   void SetEMA3Period(int ema) 
   {
      _eMA3Period = ema;
   };  
   
   void SetCrossAveragesAppliedPrice(ENUM_APPLIED_PRICE value)
   {
      _crossAveragesAppliedPrice = value;
   }  
   
   void SetCrossAveragesMethod(ENUM_MA_METHOD value)
   {
      _crossAveragesMethod = value;
   }    
   
   void SetHasIndicatorMACD(int flag)
   {
      _hasIndicatorMACD = flag;
      
      if(flag)
      {
         _hasAnyIndicator = flag;
      }
   }
   
   void SetMACDFastPeriod(int ema) 
   {
      _mACDFastPeriod = ema;
   };    
   
   void SetMACDSlowPeriod(int ema) 
   {
      _mACDSlowPeriod = ema;
   };  
   
   void SetMACDSinalPeriod(int ema) 
   {
      _mACDSignalPeriod = ema;
   }; 
   
   void SetMACDAppliedPrice(ENUM_APPLIED_PRICE value)
   {
      _mACDAppliedPrice = value;
   }     
   
   void SetHasIndicatorRSI(int flag)
   {
      _hasIndicatorRSI = flag;
      
      if(flag)
      {
         _hasAnyIndicator = flag;
      }
   }
   
   void SetRSIBuySignal(double value) 
   {
      _rSIBuySignal = value;
   }; 
   
   void SetRSISellSignal(double value) 
   {
      _rSISellSignal = value;
   }; 
   
   void SetRSIPeriod(int period) 
   {
      _rSIPeriod = period;
   }; 
   
   void SetRSIAppliedPrice(ENUM_APPLIED_PRICE value)
   {
      _rSIAppliedPrice = value;
   }   
   
   void SetHasIndicatorSAR(int flag)
   {
      _hasIndicatorSAR = flag;
      
      if(flag)
      {
         _hasAnyIndicator = flag;
      }
   }
   
   void SetSARStep(double value) 
   {
      _sARStep = value;
   };           
   
   void SetSARMaximum(double value) 
   {
      _sARMaximum = value;
   };
   
   void SetHasIndicatorBandsBollinger(int flag)
   {
      _hasIndicatorBandsBollinger = flag;
      
      if(flag)
      {
         _hasAnyIndicator = flag;
      }
   }  
   
   void SetBandsBollingerPeriod(int value) 
   {
      _bandsBollingerPeriod = value;
   };  
   
   void SetBandsBollingerShift(int value) 
   {
      _bandsBollingerShift = value;
   };
   
   void SetBandsBollingerDeviation(double value) 
   {
      _bandsBollingerDeviation = value;
   };  
   
   void SetBandsBollingerAppliedPrice(ENUM_APPLIED_PRICE value)
   {
      _bandsBollingerAppliedPrice = value;
   }  
   
   void SetHasIndicatorEnvelopes(int flag)
   {
      _hasIndicatorEnvelopes = flag;
      
      if(flag)
      {
         _hasAnyIndicator = flag;
      }
   }     
   
   void SetEnvelopesPeriod(int value) 
   {
      _envelopesPeriod = value;
   };
   
   void SetEnvelopesShift(int value) 
   {
      _envelopesShift = value;
   };
   
   void SetEnvelopesMethod(ENUM_MA_METHOD value) 
   {
      _envelopesMethod = value;
   };      
   
   void SetEnvelopesAppliedPrice(ENUM_APPLIED_PRICE value) 
   {
      _envelopesAppliedPrice = value;
   };   
   
   void SetEnvelopesDeviation(double value) 
   {
      _envelopesDeviation = value;
   };
};