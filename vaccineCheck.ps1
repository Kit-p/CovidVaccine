function Get-VaccineTimeslotData {
    param (
        [Parameter(Mandatory)]
        [ValidatePattern("^[0-9]{1,3}$")]
        [string]$center_id,
        [Parameter(Mandatory)]
        [ValidateSet("CVC", "HA")]
        [string]$cv_ctc_type,
        [Parameter(Mandatory)]
        [ValidateSet("Sinovac", "BioNTech/Fosun")]
        [string]$cv_name
    );
    $header = @{
        "Content-Type" = "application/x-www-form-urlencoded; charset=UTF-8";
        "Host"         = "bookingform.covidvaccine.gov.hk";
        "Origin"       = "https://booking.covidvaccine.gov.hk";
        "Referer"      = "https://booking.covidvaccine.gov.hk";
    };
    $body = @{
        "center_id"   = $center_id;
        "cv_ctc_type" = $cv_ctc_type;
        "cv_name"     = $cv_name;
    };
    return (Invoke-WebRequest -UseBasicParsing -Uri "https://bookingform.covidvaccine.gov.hk/forms/api_center" -Method "Post" -Headers $header -Body $body | ConvertFrom-Json);
}

function Get-VaccineTimeSlots {
    param (
        [ValidatePattern("^[0-9]{4}-[0-9]{2}-[0-9]{2}$")]
        [string]$dateLimit = "2021-08-03",
        [Parameter(Mandatory)]
        [ValidatePattern("^[0-9]{1,3}$")]
        [string]$center_id,
        [Parameter(Mandatory)]
        [ValidateSet("CVC", "HA")]
        [string]$cv_ctc_type,
        [Parameter(Mandatory)]
        [ValidateSet("Sinovac", "BioNTech/Fosun")]
        [string]$cv_name
    );
    $response = Get-VaccineTimeslotData -center_id $center_id -cv_ctc_type $cv_ctc_type -cv_name $cv_name;
    $result = ($response.avalible_timeslots | Where-Object date -le $dateLimit | ForEach-Object { ($_.timeslots | Where-Object value -eq 1 | ForEach-Object { $_.datetime }) } | Where-Object { $_.Count -gt 0 });
    if ($result.Count -le 0) {
        return "No available timeslots for the selected center before the date limit!";
    }
    else {
        return $result;
    }
}

function Get-VaccineCenter {
    param (
        [ValidateSet("Sinovac", "BioNTech/Fosun")]
        [string]$cv_name
    )

    $header = @{
        "Content-Type" = "application/x-www-form-urlencoded; charset=UTF-8";
        "Host"         = "booking.covidvaccine.gov.hk";
        "Origin"       = "https://booking.covidvaccine.gov.hk";
        "Referer"      = "https://booking.covidvaccine.gov.hk";
    };
    $response = (Invoke-WebRequest -UseBasicParsing -Uri "https://booking.covidvaccine.gov.hk/forms/ct_center" -Method "Get" -Headers $header | ConvertFrom-Json);
    $result = (Invoke-WebRequest -UseBasicParsing -Uri "https://booking.covidvaccine.gov.hk/forms/centre_data" -Method "Get" -Headers $header | ConvertFrom-Json);

    $result = $result.vaccines;
    ForEach-Object -InputObject $result {
        ForEach-Object -InputObject $_.regions.districts {
            ForEach-Object -InputObject $_.centers {
                $_.Remove("code");
                $_.Add("cv_ctc_type", $_.type);
                $_.Remove("type");
                $_.Remove("quotas");
                $_.Add("center_id", ($response.children | Where-Object name_eng -eq $_.name).id);
            }
        }
        $_.districts = $_.regions | ForEach-Object { $_.districts } ;
        $_.remove("regions");
    }

    if ($cv_name.Length -gt 0) {
        return ($result | Where-Object name -eq $cv_name);
    }
    else {
        return $result;
    }
}
