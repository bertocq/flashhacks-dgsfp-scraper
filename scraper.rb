# -*- coding: utf-8 -*-

require 'json'
require 'turbotlib'
require 'mechanize'
#require 'byebug'
#require 'logger'

viewstate=''
viewstategenerator=''

Turbotlib.log("Starting run...") # optional debug logging

headers = {
 'User-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.89 Safari/537.36',
 'accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
 'origin' => 'http://www.dgsfp.mineco.es'
}

URL = "http://www.dgsfp.mineco.es/RegistrosPublicos/AseguradorasReaseguradoras/AseguradorasReaseguradoras.aspx"
agent = Mechanize.new
agent.user_agent_alias = 'Mac Safari'

#Since the website uses ASP Net View State, we will make a first GET request to obtain VIEWSTATE & VIEWSTATEGENERATOR values to use in next requests
puts "Running GET request..."
doc = agent.get(URL).parser

viewstate = doc.css('input[name="__VIEWSTATE"]').first['value']
viewstategenerator = doc.css('input[name="__VIEWSTATEGENERATOR"]').first['value']

params = {}
params['__VIEWSTATE'] = viewstate
params['__VIEWSTATEGENERATOR'] = viewstategenerator
params["__EVENTARGUMENT"] = ""
params["__EVENTTARGET"] = ""
params["cboComparadores1"] = "igual que"
params["TxtClave"] = ""
params["cboComparadores2"] = "igual que"
params["txtNifCif"] = ""
params["cboComparadores"] = "que contenga"
params["txtNombre"] = ""
params["cboSituacion"] = "Todos/as"
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
params['__VIEWSTATE'] = viewstate
params['__VIEWSTATEGENERATOR'] = viewstategenerator
params["__EVENTARGUMENT"] = ""
params["__EVENTTARGET"] = "btnExportar"
params["cboComparadores1"] = "igual que"
params["TxtClave"] = ""
params["cboComparadores2"] = "igual que"
params["txtNifCif"] = ""
params["cboComparadores"] = "que contenga"
params["txtNombre"] = ""
params["cboSituacion"] = "Todos/as"
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
rows = doc.xpath('//table[@id="DataGrid1"]//tr[@bgcolor="WhiteSmoke"]')
puts "Got #{rows.count} rows"

details = rows.collect do |row|
  detail = {}
  [
    [:key, 'td[1]/font/text()'],
    [:entity, 'td[2]/font/text()'],
    [:cif, 'td[3]/font/text()'],
    [:telephone, 'td[4]/font/text()'],
    [:status, 'td[5]/font/text()'],
    [:cancel_date, 'td[6]/font/text()'],
  ].each do |name, xpath|
    detail[name] = row.at_xpath(xpath).to_s.strip || nil
  end
  #puts detail
end

=begin
doc.css('#DataGrid1 tr').each do |row|
  cols = row.css('td').map {|r| r.text }
  datum = {
    company_name: cols[0],
    company_number: cols[1],
    source_url: SOURCE_URL,     # mandatory field
    sample_date: Time.now       # mandatory field
  }
  # The important part of the Turbot specification is that your scraper outputs lines of JSON
  puts JSON.dump(datum)
end
=end