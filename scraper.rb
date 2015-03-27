# -*- coding: utf-8 -*-

require 'json'
require 'turbotlib'
require 'mechanize'
require 'date'

def scrap_table(response, table_columns)
  doc = Nokogiri::HTML(response.content.gsub(/&nbsp;/i, ''))
  doc.encoding = 'iso-8859-1'
  list = doc.xpath('//table[@id="DataGrid1"]//tr[@class="ItemStilo"]')
  list.map do |list_item|
    item = {}
    table_columns.each do |columns|
      name, xpath, filter = columns
      item[name] = list_item.at_xpath(xpath).to_s.strip
      item[name] = filter.call(item[name]) if filter
    end
    item
  end
end

def scrap_detail_attr(doc, name)
  doc.xpath("//span[@id=\"#{name}\"]//b/text()").to_s.strip
end

def scrap_defender_attr(doc, name)
  doc.xpath("//span[@id=\"#{name}\"]//font/text()").to_s.strip
end

parse_date = ->(date) do
  begin
    Date.parse(date).to_s
  rescue ArgumentError => ex
    nil
  end
end

FORM_URL = 'http://www.dgsfp.mineco.es/RegistrosPublicos/AseguradorasReaseguradoras/AseguradorasReaseguradoras.aspx'
SOURCE_URL = 'http://www.dgsfp.mineco.es/RegistrosPublicos/DetalleGrid/Detalle_Grid.aspx?C1=AsegReaseg'
CUSTOMER_URL = 'http://www.dgsfp.mineco.es/RegistrosPublicos/defensor/frmDatosDefensor.aspx?op=&codigo='

#Mechanize::Util::CODE_DIC[:SJIS] = "utf-8"
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
params['cboSituacion'] = 'Todos/as'
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
doc.encoding = 'iso-8859-1'
rows = doc.xpath('//table[@id="DataGrid1"]//tr[@bgcolor="WhiteSmoke"]')
Turbotlib.log("Got #{rows.count} rows")

company_id_list = []
# For each company get data from the export list
rows.collect do |row|
  datum = {}
  [
    [:company_id, 'td[1]/font/text()'],
    [:name, 'td[2]/font/text()'],
    [:cif, 'td[3]/font/text()'],
    [:telephone, 'td[4]/font/text()'],
    [:status, 'td[5]/font/text()'],
    [:cancelation_date, 'td[6]/font/text()', parse_date]
  ].each do |columns|
    name, xpath, filter = columns
    datum[name] = row.at_xpath(xpath).to_s.strip || nil
    datum[name] = filter.call(datum[name]) if filter
  end
  
  # Check for duplicated records by company_id value (crazy but they exist)
  if company_id_list.include? datum[:company_id]
    next
  else
    company_id_list << datum[:company_id]
  end
  
  detail_url = "http://www.dgsfp.mineco.es/RegistrosPublicos/AseguradorasReaseguradoras/DetalleAsegReaseg.aspx?C1=#{datum[:company_id]}&C2=False&C3=False&C4=False&C5=False"

  # GET request to capture new viewstate and viewstategenerator values, and basic data
  doc = agent.get(detail_url).parser
  doc.encoding = 'iso-8859-1'

  # Scrap basic company data
  datum[:management_id] = scrap_detail_attr(doc, 'lblClaveGes')
  datum[:cancelation_reason] = scrap_detail_attr(doc, 'lblMotivoCancelacion')
  datum[:address] = scrap_detail_attr(doc, 'lblDir')
  datum[:postal_code] = scrap_detail_attr(doc, 'lblcodPos')
  datum[:province] = scrap_detail_attr(doc, 'lblPro')
  datum[:region] = scrap_detail_attr(doc, 'lblCom')
  datum[:country] = scrap_detail_attr(doc, 'lblPaisOrg')
  datum[:fax] = scrap_detail_attr(doc, 'lblFax')
  datum[:ambit] = scrap_detail_attr(doc, 'lblAmb')
  datum[:website] = scrap_detail_attr(doc, 'lblWeb')
  datum[:email] = scrap_detail_attr(doc, 'lblMail')
  datum[:authorization_date] = parse_date.call(scrap_detail_attr(doc, 'lblFecAut'))
  datum[:subscribed_capital] = scrap_detail_attr(doc, 'lblCapSus')
  datum[:disbursed] = scrap_detail_attr(doc, 'lblCapDes')
  # default params for details page requests, again capture viewstate and viewstategenerator
  details_params = {
    '__EVENTTARGET' => '',
    '__EVENTARGUMENT' => '',
    '__VIEWSTATE' => doc.css('input[name="__VIEWSTATE"]').first['value'],
    '__VIEWSTATEGENERATOR' => doc.css('input[name="__VIEWSTATEGENERATOR"]').first['value']
  }

  # Ask for Executives list
  datum[:executives] = scrap_table(
    agent.post(detail_url, details_params.merge('btnCar' => 'Altos Cargos')),
    [
      [:accreditation, 'td[1]/text()'],
      [:name, 'td[2]/text()'],
      [:position, 'td[3]/text()']
    ]
  )

  #   # Ask for DE list.. EMPTY ALWAYS?
  #   # doc = agent.post(detail_url, details_params.merge('btnDE' => 'DE'))
  #   # TODO: Parse list from doc.content
  #   # datum[:branch_offices] = {}
  #   # puts JSON.dump(datum)

  # Ask for Branch & Modality list
  datum[:departments_and_modalities] = scrap_table(
    agent.post(detail_url, details_params.merge('btnRamMod' => 'Ramos y Modalidades')),
    [
      [:branch, 'td[2]/text()'],
      [:modality, 'td[3]/text()'],
      [:creation_date, 'td[4]/text()', parse_date],
      [:status, 'td[5]/text()']
    ]
  )

  #   # Ask for Partners list
  datum[:partners] = scrap_table(
    agent.post(detail_url, details_params.merge('btnSoc' => 'Socios')),
    [
      [:accreditation, 'td[1]/text()'],
      [:name, 'td[2]/text()']
    ]
  )

  # Ask for Representatives list
  datum[:representatives] = scrap_table(
    agent.post(detail_url, details_params.merge('btnRep' => 'Representantes')),
    [
      [:accreditation, 'td[1]/text()'],
      [:name, 'td[2]/text()']
    ]
  )

  # Ask for SAC & Defender popup
  doc = agent.get(CUSTOMER_URL + datum[:company_id]).parser
  doc.encoding = 'iso-8859-1'

  customer_attention = {}
  customer_attention[:name] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblnombre')
  customer_attention[:address] = scrap_defender_attr(doc, 'Wucdatosdefensor2_Lbldireccion')
  customer_attention[:post_office_box] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblapto')
  customer_attention[:country] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblPais')
  customer_attention[:postal_code] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblCodigoPostal')
  customer_attention[:province] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblProvincia')
  customer_attention[:municipality] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblMunicipio')
  customer_attention[:town] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblPoblacion')
  customer_attention[:telephone] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblTelefono')
  customer_attention[:fax] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblFax')
  customer_attention[:mobile_phone] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblMovil')
  customer_attention[:email] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblMail')
  customer_attention[:web] = scrap_defender_attr(doc, 'Wucdatosdefensor2_lblweb')
  datum[:customer_attention] = customer_attention

  agent.post(detail_url, params.merge('btnDefensor' => 'SAC y Defensor'))

  # Post to get the second tab of the popup
  response = agent.post(
    CUSTOMER_URL + datum[:company_id],
    '__tstPestanas_State__' => '1',
    '__EVENTTARGET' => 'tstPestanas',
    '__EVENTARGUMENT' => '1',
    '__VIEWSTATE' => doc.css('input[name="__VIEWSTATE"]').first['value'],
    '__VIEWSTATEGENERATOR' => doc.css('input[name="__VIEWSTATEGENERATOR"]').first['value']
  )

  # Parse Client Defensor values from second tab
  content = response.content.encode('UTF-8', :invalid => :replace, :undef => :replace)
  doc = Nokogiri::HTML(content)
  doc.encoding = 'iso-8859-1'

  client_defensor = {}
  client_defensor[:name] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblnombre')
  client_defensor[:address] = scrap_defender_attr(doc, 'WUCDatosDefensor1_Lbldireccion')
  client_defensor[:post_office_box] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblapto')
  client_defensor[:country] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblPais')
  client_defensor[:postal_code] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblCodigoPostal')
  client_defensor[:province] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblProvincia')
  client_defensor[:municipality] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblMunicipio')
  client_defensor[:town] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblPoblacion')
  client_defensor[:telephone] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblTelefono')
  client_defensor[:fax] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblFax')
  client_defensor[:mobile_phone] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblMovil')
  client_defensor[:email] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblMail')
  client_defensor[:web] = scrap_defender_attr(doc, 'WUCDatosDefensor1_lblweb')
  datum[:client_defensor] = client_defensor

  datum[:source_url] = SOURCE_URL # mandatory field
  datum[:sample_date] = Time.now # mandatory field
  puts JSON.dump(datum)
end
