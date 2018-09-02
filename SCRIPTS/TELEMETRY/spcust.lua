-- Custom Telemetry script for Taranis X9D+
--   Data from FrSky S.Port passthrough
--   Optimised for screen size (Taranis X9D+): 212x64 pixels.
--
-- This script reuses some coding found in:
--   https://github.com/jplopezll/OpenTX_FrSkySPort_passthrough_master
-- 


local screenCleared=0   -- Track if lcd needs full wiping
local lastUpdtTelem=0     -- Last moment normal telemetry < 0x5000 was updated
local timeToTelemUpdt=1000  -- Minimum redraw time (multiples of 10ms)

-- Function to clear screen areas. To be improved
local function clearRectangle(x,y,w,h)
  lcd.drawFilledRectangle(x,y,w,h,SOLID + GREY(0))
  lcd.drawFilledRectangle(x,y,w,h,GREY(0))
  lcd.drawPoint(x,y)
  lcd.drawPoint(x+w-1,y)
  lcd.drawPoint(x,y+h-1)
  lcd.drawPoint(x+w-1,y+h-1)
end


----------------------------------------------------------------------------------
-- Functions to draw certain areas of the screen when passthrough data is received
----------------------------------------------------------------------------------
local function drawLayout()
  -- Background title area
  lcd.drawFilledRectangle(-1, -1, 214, 8, GREY(12) + SOLID)

  -- Draw vertical separators
  lcd.drawFilledRectangle(94,7,2,50,GREY(12))
  -- lcd.drawFilledRectangle(145,7,2,50,GREY(12))

  -- Backaground footer area
  lcd.drawFilledRectangle(0,57,212,7,GREY(12))
end

local function draw5009()
  -- Show custom sensor data on screen.
  clearRectangle(96,27,100,10)
  lcd.drawText(98,29,"Gas: ", SMLSIZE)
  lcd.drawNumber(lcd.getLastPos(),29,Concentration, SMLSIZE)
  lcd.drawText(lcd.getLastPos(),29," ppm",SMLSIZE)
  lcd.drawGauge(96,28,100,8,Concentration,20000)
  

end

local function drawUnder5000()
  -- Title areas. Right side
  lcd.drawFilledRectangle(90,-1,122,8,INVERS)
  lcd.drawFilledRectangle(90,-1,122,8)

  -- Taranis battery voltage
  lcd.drawText(98, 0, " TX: ", SMLSIZE)
  lcd.drawNumber(lcd.getLastPos(), 0, TxVoltage*10, SMLSIZE + PREC1)
  lcd.drawText(lcd.getLastPos(), 0, "V", SMLSIZE)

  -- Timer
  lcd.drawText(lcd.getLastPos(), 0, " On: ", SMLSIZE)
  lcd.drawTimer(lcd.getLastPos(), 0, Timer1, SMLSIZE)

  lcd.drawFilledRectangle(89, -1, 124, 8, GREY(12) + SOLID)


  -- Indicators: gauges
  -- Radio quality
  local rssi = RSSIPer
  clearRectangle(148,7,49,10)
  lcd.drawText(150,9, "RSSI: ", SMLSIZE)
  lcd.drawNumber(lcd.getLastPos(),9,rssi,SMLSIZE)
  lcd.drawText(lcd.getLastPos(),9,"%",SMLSIZE)
  lcd.drawGauge(148,8,49,8,rssi,101)
  
  -- Taranis battery voltage
  -- For 6xNi-MH battery voltage is in between 6.5 (0%) and 8.1V (100%)
  local txbtPor = (TxVoltage - 6.5)/1.6 * 100
  if txbtPor<0 then rxbtPor=0 end
  clearRectangle(96,7,49,10)
  lcd.drawText(98,9, "BtTx: ", SMLSIZE)
  lcd.drawNumber(lcd.getLastPos(),9, txbtPor, SMLSIZE)
  lcd.drawText(lcd.getLastPos(),9,"%",SMLSIZE)
  lcd.drawGauge(96,8,49,8,txbtPor,100)

  
end

---------------------------------------------------------------
-- Init function global variables
---------------------------------------------------------------
local function init_func()
  -- 0x5009
  Concentration=0            -- 9 bits.
  
  -- Local Taranis variables getValue
  TxVoltageId=getFieldInfo("tx-voltage").id    
  TxVoltage = getValue(TxVoltageId)            
  Timer1Id=getFieldInfo("timer1").id           
  Timer1=getValue(Timer1Id)                    
  RSSIPerId=getFieldInfo("RSSI").id            
  RSSIPer=getValue(RSSIPerId)                 
end


---------------------------------------------------------------
-- Visible loop function
---------------------------------------------------------------
local function run(e)
  -- Record the time to print total exec time during debugging
  local runTime = getTime()
 
  -- Prepare to extract SPort data
  local sensorID,frameID,dataID,value = sportTelemetryPop()
  while dataID~=nil do
    
    -- unpack 0x5009 packet
    if dataID == 0x5009 then
      Concentration = bit32.extract(value,2,7)*(10^bit32.extract(value,0,2)) -- 2+7 bits 10^x + ppm
    end

    -- Update normal local telemetry data by its id

    if runTime > (lastUpdtTelem+timeToTelemUpdt) then
      lastUpdtTelem=runTime
      TxVoltage = getValue(TxVoltageId)
      Timer1=getValue(Timer1Id)
      RSSIPer=getValue(RSSIPerId)

      -- Redraw all the screen
      screenCleared=0
    end

    -- Check if there are messages in the queue to avoid exit from the while-do loop
    sensorID,frameID,dataID,value = sportTelemetryPop()
  end
  

  -- If first called, wipe out the lcd
  if screenCleared==0 then
   lcd.clear()
   drawLayout()
   screenCleared=1
   draw5009()
   drawUnder5000()
  end

  draw5009()
  

end

return{run=run, init=init_func}
 
