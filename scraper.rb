# -*- coding: utf-8 -*-

require 'json'
require 'turbotlib'
require 'mechanize'
require 'byebug'
require 'logger'

Turbotlib.log("Starting run...") # optional debug logging

headers = {
 'User-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.89 Safari/537.36',
 'accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
 'origin' => 'http://www.dgsfp.mineco.es'
}

URL = "http://www.dgsfp.mineco.es/RegistrosPublicos/AseguradorasReaseguradoras/AseguradorasReaseguradoras.aspx"
agent = Mechanize.new
agent.user_agent_alias = 'Mac Safari'

puts "Running GET requrest..."
doc = agent.get(URL).parser

params = {}
params['__VIEWSTATE'] = doc.css('input[name="__VIEWSTATE"]').first['value']
params['__VIEWSTATEGENERATOR'] = doc.css('input[name="__VIEWSTATEGENERATOR"]').first['value']
params["__EVENTARGUMENT"] = ""
params["__EVENTTARGET"] = ""
params["cboComparadores1"] = "igual que"
params["TxtClave"] = ""
params["cboComparadores2"] = "igual que"
params["txtNifCif"] = ""
params["cboComparadores"] = "que contenga"
params["txtNombre"] = ""
params["cboSituacion"] = "1"
params["cboAmbito"] = "Todos/as"
params["cboTipoEntidad"] = "Todos/as"
params["cboActividad"] = "Todos/as"
params["CboRamos"] = "Todos/as"
params["cboPrestaciones"] = "Todos/as"
params["Chk_EEE_PaisOrg"] = "on"
params['CmdBusqueda'] = 'Buscar'

response = agent.post(URL, params)
doc = response.parser

params = {}
params['__VIEWSTATE'] = doc.css('input[name="__VIEWSTATE"]').first['value']
params['__VIEWSTATEGENERATOR'] = doc.css('input[name="__VIEWSTATEGENERATOR"]').first['value']
params["__EVENTARGUMENT"] = ""
params["__EVENTTARGET"] = "btnExportar"
params["cboComparadores1"] = "igual que"
params["TxtClave"] = ""
params["cboComparadores2"] = "igual que"
params["txtNifCif"] = ""
params["cboComparadores"] = "que contenga"
params["txtNombre"] = ""
params["cboSituacion"] = "1"
params["cboAmbito"] = "Todos/as"
params["cboTipoEntidad"] = "Todos/as"
params["cboActividad"] = "Todos/as"
params["CboRamos"] = "Todos/as"
params["cboPrestaciones"] = "Todos/as"
params["Chk_EEE_PaisOrg"] = "on"

response = agent.post(URL, params)
doc = response.parser
#puts doc

doc = agent.get("http://www.dgsfp.mineco.es/RegistrosPublicos/DetalleGrid/Detalle_Grid.aspx?C1=AsegReaseg").parser
puts doc