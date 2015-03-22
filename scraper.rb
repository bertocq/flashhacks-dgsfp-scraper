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
params['cboSituacion'] = 'Todos/as' # 'Todos/as' will get all of the possible statuses, not just active
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
  end

  detail_url = "http://www.dgsfp.mineco.es/RegistrosPublicos/AseguradorasReaseguradoras/DetalleAsegReaseg.aspx?C1=#{datum[:company_id]}&C2=False&C3=False&C4=False&C5=False"
  # GET request to capture new viewstate and viewstategenerator values, and basic data
  doc = agent.get(detail_url).parser

  # TODO: Scrap basic company data
  datum[:management_id] = doc.xpath('//span[@id="lblClaveGes"]//b/text()').to_s.strip
  datum[:denomination] = doc.xpath('//span[@id="lblDen"]/text()').to_s.strip
  datum[:cif_2] = doc.xpath('//span[@id="lblCif"]//b/text()').to_s.strip
  datum[:status_2] = doc.xpath('//span[@id="lblSit"]//b/text()').to_s.strip
  datum[:address] = doc.xpath('//span[@id="lblDir"]//b/text()').to_s.strip
  datum[:postal_code] = doc.xpath('//span[@id="lblcodPos"]//b/text()').to_s.strip
  datum[:province] = doc.xpath('//span[@id="lblPro"]//b/text()').to_s.strip
  datum[:region] = doc.xpath('//span[@id="lblCom"]//b/text()').to_s.strip
  datum[:country] = doc.xpath('//span[@id="lblPaisOrg"]//b/text()').to_s.strip
  datum[:telephone_2] = doc.xpath('//span[@id="lblTel"]//b/text()').to_s.strip
  datum[:fax] = doc.xpath('//span[@id="lblFax"]//b/text()').to_s.strip
  datum[:ambit] = doc.xpath('//span[@id="lblAmb"]//b/text()').to_s.strip
  datum[:website] = doc.xpath('//span[@id="lblWeb"]//b/text()').to_s.strip
  datum[:email] = doc.xpath('//span[@id="lblMail"]//b/text()').to_s.strip
  datum[:authorization_date] = doc.xpath('//span[@id="lblFecAut"]//b/text()').to_s.strip
  datum[:subscribed_capital] = doc.xpath('//span[@id="lblCapSus"]//b/text()').to_s.strip
  datum[:disbursed] = doc.xpath('//span[@id="lblCapDes"]//b/text()').to_s.strip
  puts JSON.dump(datum)
  throw :marlo

  # default params for details page requests
  details_params = {
    '__EVENTTARGET' => '',
    '__EVENTARGUMENT' => '',
    '__VIEWSTATE' => doc.css('input[name="__VIEWSTATE"]').first['value'],
    '__VIEWSTATEGENERATOR' => doc.css('input[name="__VIEWSTATEGENERATOR"]').first['value']
  }

  # Ask for Executives list
  response = agent.post(detail_url, details_params.merge('btnCar' => 'Altos Cargos'))
  # TODO: Parse list from doc.content
  executives = {}
  doc = Nokogiri::HTML(response.content.gsub(/&nbsp;/i, ''))
  executive_list = doc.xpath('//table[@id="DataGrid1"]//tr[@class="ItemStilo"]')
  executive_list.collect do |executive|
    [
      [:accreditation, 'td[1]/text()'],
      [:name, 'td[2]/text()'],
      [:position, 'td[3]/text()']
    ].each do |exec_name, exec_xpath|
      executives[exec_name] = executive.at_xpath(exec_xpath).to_s.strip
    end
  end
  datum[:executives] = executives

=begin
  # Ask for DE list
  doc = agent.post(detail_url, details_params.merge('btnDE' => 'DE'))
  # TODO: Parse list from doc.content
  datum[:branch_offices] = {}
  puts JSON.dump(datum)
  throw :marlo

  # Ask for Branch & Modality list
  doc = agent.post(detail_url, details_params.merge('btnRamMod' => 'Ramos y Modalidades'))
  # TODO: Parse list from doc.content
  datum[:departments_and_modalities] = {}

  # Ask for Representatives list
  doc = agent.post(detail_url, details_params.merge('btnRep' => 'Representantes'))
  # TODO: Parse list from doc.content
  datum[:representatives] = {}

  # Ask for Partners list
  doc = agent.post(detail_url, details_params.merge('btnSoc' => 'Socios'))
  # TODO: Parse list from doc.content
  datum[:partners] = {}

  # Ask for LPS list
  doc = agent.post(detail_url, details_params.merge('btnLPS' => 'LPS'))
  # TODO: Parse list from doc.content
  datum[:free_provision_services] = {}

  # Ask for SAC & Defender list
  doc = agent.post(detail_url, details_params.merge('btnDefensor' => 'SAC y Defensor'))
  # TODO: This one is tricky! onclick="windowOpen('C0001','ASEGURADORES+AGRUPADOS%2c+SOCIEDAD+ANONIMA+DE+SEGUROS+')"
  datum[:client_defensor] = {}
  datum[:customer_attention] = {}
  #     function windowOpen(valor,denom)
  #     {
  #       window.open('../defensor/frmDatosDefensor.aspx?op=&codigo=' + valor + '&nombre=' + denom + '','_blank','toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=no,resizable=no,width=550,height=320,top=200,left=200,alwaysraised=yes,z-lock=yes');
  #     }
=end    
  datum[:source_url] = SOURCE_URL # mandatory field
  datum[:sample_date] = Time.now # mandatory field
  puts JSON.dump(datum)
end
