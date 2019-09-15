local device = fibaro:getSelfId();
local ipaddress = fibaro:getValue(device, "IPAddress");
local port = fibaro:getValue(device, "TCPPort");
local measuringInterval = 145;
local requestRetryInterval = 10;
FIBARO = Net.FHttp(ipaddress, port)
local response = FIBARO:GET("/data.json");

function getResponse()
  return json.decode(response);
end

function calculateAqi(pm25)
  local aqiBreakpoints = {
    {aqi = 0, pm25 = 0},
    {aqi = 51, pm25 = 15.5},
    {aqi = 101, pm25 = 40.5},
    {aqi = 151, pm25 = 65.5},
    {aqi = 201, pm25 = 150.5},
    {aqi = 301, pm25 = 250.5}
  };

  function getCeiling(pm25)
    for i = 1, #aqiBreakpoints, 1 do
      if (pm25 < aqiBreakpoints[i].pm25) then
        return aqiBreakpoints[i];
      end
    end
  end

  function getFloor(pm25)
    for i = #aqiBreakpoints, 1, -1 do
      if (pm25 >= aqiBreakpoints[i].pm25) then
        return aqiBreakpoints[i];
      end
    end
  end

  local max = getCeiling(pm25);
  local min = getFloor(pm25);

  if (type(min) ~= 'nil' and type(max) ~= 'nil') then
    return math.floor((pm25 - min.pm25) * (max.aqi - min.aqi) / (max.pm25 - min.pm25) + min.aqi);
  else
    return aqiBreakpoints[#aqiBreakpoints].aqi;
  end
end

local requestSucceeded, jsonResponse = pcall(getResponse);

if (requestSucceeded) then
  for _, sensor in ipairs(jsonResponse.sensordatavalues) do
    local valueType = sensor.value_type;
    local value = sensor.value;
    local unit = "";

    if (valueType == "SDS_P1" or valueType == "SDS_P2") then
      unit = " µg/m³";
      if (valueType == "SDS_P2") then
        fibaro:call(device, "setProperty", "ui.aqi.value", calculateAqi(tonumber(value)));
      end
    elseif(valueType == "temperature" or valueType == "BME280_temperature") then
      unit = "°C";
    elseif(valueType == "humidity" or valueType == "BME280_humidity") then
      unit = " %";
    elseif(valueType == "BME280_pressure") then
      value = math.floor(value)/100;
      unit = " hPa";
    end

    fibaro:call(device, "setProperty", "ui." .. sensor.value_type:gsub("_", "") .. ".value", value .. unit);
  end

  fibaro:sleep(measuringInterval * 1000);
else
  fibaro:sleep(requestRetryInterval * 1000);
end
