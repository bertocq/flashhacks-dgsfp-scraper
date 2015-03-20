# -*- coding: utf-8 -*-

require 'json'
require 'turbotlib'
require 'mechanize'

Turbotlib.log('Starting run...') # optional debug logging

URL = 'http://www.dgsfp.mineco.es/RegistrosPublicos/AseguradorasReaseguradoras/AseguradorasReaseguradoras.aspx'
agent = Mechanize.new
agent.user_agent_alias = 'Mac Safari'

# Since the website uses ASP Net View State, we will make a first GET request
# to obtain the values for VIEWSTATE & VIEWSTATEGENERATOR and reuse them
Turbotlib.log('Running GET request...')
doc = agent.get(URL).parser
viewstate = doc.css('input[name="__VIEWSTATE"]').first['value']
viewstategen = doc.css('input[name="__VIEWSTATEGENERATOR"]').first['value']

# Default parameters used in each POST request
params = {}
params['__VIEWSTATE'] = viewstate
params['__VIEWSTATEGENERATOR'] = viewstategen
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

# Do a search so next call will get all the results
agent.post(URL, params.merge('CmdBusqueda' => 'Buscar'))

# Ask for the export-all function
agent.post(URL, params.merge('__EVENTTARGET' => 'btnExportar'))

# Finally get the list on the popup url
SOURCE_URL = 'http://www.dgsfp.mineco.es/RegistrosPublicos/DetalleGrid/Detalle_Grid.aspx?C1=AsegReaseg'
doc = agent.get(SOURCE_URL).parser
rows = doc.xpath('//table[@id="DataGrid1"]//tr[@bgcolor="WhiteSmoke"]')
Turbotlib.log("Got #{rows.count} rows")

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
    # Visit each company details
    # url = "http://www.dgsfp.mineco.es/RegistrosPublicos/AseguradorasReaseguradoras/DetalleAsegReaseg.aspx?C1=#{company_id}&C2=False&C3=False&C4=False&C5=False"
      # Then visit the details subsections
  end
  datum[:source_url] = SOURCE_URL # mandatory field
  datum[:sample_date] = Time.now # mandatory field
  puts JSON.dump(datum)
end
