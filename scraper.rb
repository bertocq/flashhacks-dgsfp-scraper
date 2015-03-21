# -*- coding: utf-8 -*-

require 'json'
require 'turbotlib'
require 'mechanize'

FORM_URL = 'http://www.dgsfp.mineco.es/RegistrosPublicos/AseguradorasReaseguradoras/AseguradorasReaseguradoras.aspx'
SOURCE_URL = 'http://www.dgsfp.mineco.es/RegistrosPublicos/DetalleGrid/Detalle_Grid.aspx?C1=AsegReaseg'

Turbotlib.log('Starting run...') # optional debug logging
agent = Mechanize.new
agent.user_agent_alias = 'Mac Safari'

# Since the website uses ASP Net View State, we will make a first GET request
# to obtain the values for VIEWSTATE & VIEWSTATEGENERATOR and reuse them
Turbotlib.log('Running GET request...')
doc = agent.get(FORM_URL).parser
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
params['cboSituacion'] = '1' # 'Todos/as' will get all of the possible statuses, not just active
params['cboAmbito'] = 'Todos/as'
params['cboTipoEntidad'] = 'Todos/as'
params['cboActividad'] = 'Todos/as'
params['CboRamos'] = 'Todos/as'
params['cboPrestaciones'] = 'Todos/as'
params['Chk_EEE_PaisOrg'] = 'on'

# Do a search so next call will get all the results
agent.post(FORM_URL, params.merge('CmdBusqueda' => 'Buscar'))

# Ask for the export-all function
agent.post(FORM_URL, params.merge('__EVENTTARGET' => 'btnExportar'))

# Finally get the list on the popup url
doc = agent.get(SOURCE_URL).parser
rows = doc.xpath('//table[@id="DataGrid1"]//tr[@bgcolor="WhiteSmoke"]')
Turbotlib.log("Got #{rows.count} rows")

# For each company get data from the export list
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
    
    detail_url = "http://www.dgsfp.mineco.es/RegistrosPublicos/AseguradorasReaseguradoras/DetalleAsegReaseg.aspx?C1=#{datum[:company_id]}&C2=False&C3=False&C4=False&C5=False"
    # GET request to capture new viewstate and viewstategenerator values, and basic data
    doc = agent.get(detail_url).parser
    
    # TODO: Scrap basic company data

    # Ask for Executives list
    agent.post(
      detail_url,
      '__VIEWSTATE' => doc.css('input[name="__VIEWSTATE"]').first['value'],
      '__VIEWSTATEGENERATOR' => doc.css('input[name="__VIEWSTATEGENERATOR"]').first['value'],
      'btnCar' => 'Altos Cargos'
    )

    # read executive list?
    doc = agent.get(detail_url).parser
    #puts doc
  end
  datum[:source_url] = SOURCE_URL # mandatory field
  datum[:sample_date] = Time.now # mandatory field
  puts JSON.dump(datum)
end
