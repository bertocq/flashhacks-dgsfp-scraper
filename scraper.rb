# -*- coding: utf-8 -*-

require 'json'
require 'turbotlib'
require 'mechanize'

Turbotlib.log('Starting run...') # optional debug logging

URL = 'http://www.dgsfp.mineco.es/RegistrosPublicos/AseguradorasReaseguradoras/AseguradorasReaseguradoras.aspx'
agent = Mechanize.new
agent.user_agent_alias = 'Mac Safari'

# Since the website uses ASP Net View State, we will make a first GET
# request to obtain VIEWSTATE & VIEWSTATEGENERATOR values to use next time
puts 'Running GET request...'
doc = agent.get(URL).parser

viewstate = doc.css('input[name="__VIEWSTATE"]').first['value']
viewstategenerator = doc.css('input[name="__VIEWSTATEGENERATOR"]').first['value']

params = {}
params['__VIEWSTATE'] = viewstate
params['__VIEWSTATEGENERATOR'] = viewstategenerator
params['__EVENTARGUMENT'] = ''
params['__EVENTTARGET'] = ''
params['cboComparadores1'] = 'igual que'
params['TxtClave'] = ''
params['cboComparadores2'] = 'igual que'
params['txtNifCif'] = ''
params['cboComparadores'] = 'que contenga'
params['txtNombre'] = ''
params['cboSituacion'] = 'Todos/as'
params['cboAmbito'] = 'Todos/as'
params['cboTipoEntidad'] = 'Todos/as'
params['cboActividad'] = 'Todos/as'
params['CboRamos'] = 'Todos/as'
params['cboPrestaciones'] = 'Todos/as'
params['Chk_EEE_PaisOrg'] = 'on'

params['CmdBusqueda'] = 'Buscar'

# Do a search so next call will get all the results
agent.post(URL, params)

params = {}
params['__VIEWSTATE'] = viewstate
params['__VIEWSTATEGENERATOR'] = viewstategenerator
params['__EVENTARGUMENT'] = ''
params['__EVENTTARGET'] = 'btnExportar'
params['cboComparadores1'] = 'igual que'
params['TxtClave'] = ''
params['cboComparadores2'] = 'igual que'
params['txtNifCif'] = ''
params['cboComparadores'] = 'que contenga'
params['txtNombre'] = ''
params['cboSituacion'] = 'Todos/as'
params['cboAmbito'] = 'Todos/as'
params['cboTipoEntidad'] = 'Todos/as'
params['cboActividad'] = 'Todos/as'
params['CboRamos'] = 'Todos/as'
params['cboPrestaciones'] = 'Todos/as'
params['Chk_EEE_PaisOrg'] = 'on'

# Ask for the export-all function
agent.post(URL, params)

# Finally get the list on the popup url
doc = agent.get('http://www.dgsfp.mineco.es/RegistrosPublicos/DetalleGrid/Detalle_Grid.aspx?C1=AsegReaseg').parser
rows = doc.xpath('//table[@id="DataGrid1"]//tr[@bgcolor="WhiteSmoke"]')
puts "Got #{rows.count} rows"

# TODO companys should be an array companys[company_id] = hash{}
rows.collect do |row|
  datum = {}
  [
    [:company_id, 'td[1]/font/text()'],
    [:entity_name, 'td[2]/font/text()'],
    [:cif, 'td[3]/font/text()'],
    [:telephone, 'td[4]/font/text()'],
    [:status, 'td[5]/font/text()'],
    [:cancel_date, 'td[6]/font/text()']
  ].each do |name, xpath|
    datum[name] = row.at_xpath(xpath).to_s.strip || nil
  end
  puts datum
end

# Visit each company details
# url = "http://www.dgsfp.mineco.es/RegistrosPublicos/AseguradorasReaseguradoras/DetalleAsegReaseg.aspx?C1=#{company_id}&C2=False&C3=False&C4=False&C5=False"

# doc.css('#DataGrid1 tr').each do |row|
#   cols = row.css('td').map {|r| r.text }
#   datum = {
#     company_name: cols[0],
#     company_number: cols[1],
#     source_url: SOURCE_URL,     # mandatory field
#     sample_date: Time.now       # mandatory field
#   }
#   # The important part of the Turbot specification is that your scraper outputs lines of JSON
#   puts JSON.dump(datum)
# end
