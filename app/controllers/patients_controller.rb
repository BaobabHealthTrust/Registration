class PatientsController < GenericPatientsController
  def search_all
    search_str = params[:search_str]
    side = params[:side]

    if params[:search_by_identifier] == "true"
      patients = PatientIdentifier.find(:all, :conditions => ["voided = 0 AND (identifier LIKE ?)",
          "%#{search_str}%"],:limit => 10).map{| p |p.patient}
    else
      given_name = search_str.split(' ')[0] rescue ''
      family_name = search_str.split(' ')[1] rescue ''
      patients = PersonName.find(:all ,:joins => [:person => [:patient]], :conditions => ["person.voided = 0 AND family_name LIKE ? AND given_name LIKE ?",
          "#{family_name}%","%#{given_name}%"],:limit => 10).collect{|pn|pn.person.patient}
    end
    @html = <<EOF
<html>
<head>
<style>
  .color_blue{
    border-style:solid;
  }
  .color_white{
    border-style:solid;
  }

  th{
    border-style:solid;
  }
</style>
</head>
<body>
<br/>
<table class="data_table" width="100%">
EOF

    color = 'blue'
    patients.each do |patient|
      next if patient.person.blank?
      next if patient.person.addresses.blank?
      if color == 'blue'
        color = 'white'
      else
        color='blue'
      end
      bean = PatientService.get_patient(patient.person)
      total_encounters = patient.encounters.count rescue nil
      latest_visit = patient.encounters.last.encounter_datetime.strftime("%a, %d-%b-%y") rescue nil
      @html+= <<EOF
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Name:&nbsp;#{bean.name || '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Age:&nbsp;#{bean.age || '&nbsp;'}</td>
</tr>
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Guardian:&nbsp;#{bean.guardian rescue '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">ARV number:&nbsp;#{bean.arv_number rescue '&nbsp;'}</td>
</tr>
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">National ID:&nbsp;#{bean.national_id rescue '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">TA:&nbsp;#{bean.home_district rescue '&nbsp;'}</td>
</tr>
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Total Encounters:&nbsp;#{total_encounters rescue '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Latest Visit:&nbsp;#{latest_visit rescue '&nbsp;'}</td>
</tr>
EOF
    end

    @html+="</table></body></html>"
    render :text => @html ; return
  end

  def merge_similar_patients
    if request.method == :post
      params[:patient_ids].split(":").each do | ids |
        master = ids.split(',')[0].to_i
        slaves = ids.split(',')[1..-1]
        ( slaves || [] ).each do | patient_id  |
          next if master == patient_id.to_i
          Patient.merge(master,patient_id.to_i)
        end
      end
      #render :text => "showMessage('Successfully merged patients')" and return
    end
    redirect_to("/clinic/merge_people_menu") and return
  end
  
end
