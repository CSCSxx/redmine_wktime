module ReportAsset
  include WkreportHelper

  def calcReportData(user_id, group_id, projId, from, to)
    sqlStr = " select ii.id, ii.currency, dp.depreciation_date, ap.name as asset_name, p.name as product_name, s.shipment_date, dp.id depreciation_id, ap.id asset_id, ap.current_value, dp.actual_amount, dp.depreciation_amount, dp.depreciation_date, ii.cost_price, ii.over_head_price, projects.name as project_name from wk_inventory_items ii INNER JOIN wk_product_items pt ON (pt.id = ii.product_item_id AND ii.product_type = 'A') LEFT OUTER JOIN (select max(depreciation_date) as depreciation_date, inventory_item_id from wk_asset_depreciations d where d.depreciation_date <= '#{to}' group by inventory_item_id) md on (md.inventory_item_id = ii.id) LEFT OUTER JOIN wk_asset_depreciations dp on (md.inventory_item_id = dp.inventory_item_id and  md.depreciation_date = dp.depreciation_date) LEFT OUTER JOIN wk_shipments s ON (s.id = ii.shipment_id) LEFT OUTER JOIN wk_asset_properties ap ON (ap.inventory_item_id = ii.id) LEFT OUTER JOIN wk_products p ON (p.id = pt.product_id) LEFT OUTER JOIN projects ON (projects.id = ii.project_id) WHERE ap.id is not null and (ap.is_disposed != #{booleanFormat(true)} OR ap.is_disposed is NUll)"
    unless to.blank?
      sqlStr = sqlStr + " and s.shipment_date <= '#{to}' "
    end
    if projId.to_i > 0
      sqlStr = sqlStr + "and ii.project_id = #{projId} "
    end
    sqlStr = sqlStr + " order by dp.depreciation_date, s.shipment_date, p.name"
    entries = WkInventoryItem.find_by_sql(sqlStr)
    data = getAssetEntries(entries, to)
  end

  def getAssetEntries(entries, to)
    count = 1
    purchase_total = 0
    depreciation_total = 0
    current_total = 0
    currency = ""
    asset = {}
    entries.each_with_index do |entry, index|
      asset[index] = {}
      purchaseCost = (entry.over_head_price.to_f + entry.cost_price.to_f).round(2)
      initialValue = (entry.current_value.blank? ? purchaseCost : entry.current_value.to_f).round(2)
      depreciatedValue = (entry.actual_amount.to_f - entry.depreciation_amount.to_f).round(2)
      currentValue = (entry.depreciation_id.blank? ? initialValue : depreciatedValue).round(2)
      unless currentValue == 0
        asset[index]['s_no'] = count
        asset[index]['project_name'] = entry.project_name
        asset[index]['asset_name'] = entry.asset_name
        asset[index]['product_name'] = entry.product_name
        asset[index]['shipment_date'] = entry.shipment_date
        asset[index]['purchase_value'] = entry.currency+' '+purchaseCost.to_s
        asset[index]['depreciation'] = entry.currency+' '+(purchaseCost - currentValue).to_s
        asset[index]['current_value'] = entry.currency+' '+currentValue.to_s
        asset[index]['last_depreciation'] = entry.depreciation_date
        # asset[index]['currency'] = entry.currency

        purchase_total += purchaseCost
        depreciation_total += (purchaseCost - currentValue).round(2)
        current_total += currentValue
				currency = entry.currency
      end
      count = count + 1
    end
    purchase_total = purchase_total
    depreciation_total = depreciation_total
    current_total = current_total
    currency = currency
    data = {asset: asset, purchase_total: currency+' '+purchase_total.to_s, depreciation_total: currency+' '+depreciation_total.to_s, current_total: currency+' '+current_total.to_s, currency: currency, to: to.to_formatted_s(:long)}
  end

  def getExportData(user_id, group_id, projId, from, to)
    data = {headers: {}, data: []}
    reportData = calcReportData(user_id, group_id, projId, from, to)
    data[:headers] = {s_no: '#', project_name: l(:label_project), asset_name: l(:label_asset) + " " + l(:field_name), product_name: l(:field_inventory_item_id), shipment_date: l(:label_purchase_date), purchase_value: l(:label_purchase_value), depreciation: l(:label_depreciation), current_value: l(:label_current_value), last_depreciation: l(:label_last_depreciation_on)}
    reportData[:asset].each do |key, val|
      data[:data] << val
    end
    data[:data] << {s_no: '', project_name: '', asset_name: '', product_name: '', shipment_date: '',  purchase_total: reportData[:currency]+' '+reportData[:purchase_total].to_s, depreciation_total: reportData[:currency]+' '+reportData[:depreciation_total].to_s, current_total: reportData[:currency]+' '+reportData[:current_total].to_s, last_depreciation: ''}
    data
  end
end

