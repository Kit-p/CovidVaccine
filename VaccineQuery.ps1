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
        [string]$cv_name,
        [string]$first_dose_date = $null
    );
    $header = @{
        "Content-Type" = "application/x-www-form-urlencoded; charset=UTF-8";
        "Host"         = "bookingform.covidvaccine.gov.hk";
        "Origin"       = "https://booking.covidvaccine.gov.hk";
        "Referer"      = "https://booking.covidvaccine.gov.hk";
    };
    $body = @{
        "center_id"       = $center_id;
        "cv_ctc_type"     = $cv_ctc_type;
        "cv_name"         = $cv_name;
        "first_dose_date" = $first_dose_date;
    };
    if ($null -eq $first_dose_date -or $first_dose_date -notmatch "^[0-9]{4}-[0-9]{2}-[0-9]{2}$") {
        $body.Remove("first_dose_date");
    }
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
        [string]$cv_name,
        [string]$first_dose_date = $null
    );
    $response = Get-VaccineTimeslotData -center_id $center_id -cv_ctc_type $cv_ctc_type -cv_name $cv_name -first_dose_date $first_dose_date;
    $result = @();
    foreach ($item in $response.avalible_timeslots) {
        $item.timeslots = ($item.timeslots | Where-Object value -gt 0 | ForEach-Object { $_.display_label }) -join " ";
        if ($item.timeslots.Length -gt 0) {
            $result += $item;
        }
    }
    if ($result.Count -le 0) {
        return "No available timeslots available for the specified center!";
    }
    else {
        return $result;
    }
}

function Get-VaccineCenters {
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
    $reference = (Invoke-WebRequest -UseBasicParsing -Uri "https://booking.covidvaccine.gov.hk/forms/ct_center" -Method "Get" -Headers $header | ConvertFrom-Json);
    $result = (Invoke-WebRequest -UseBasicParsing -Uri "https://booking.covidvaccine.gov.hk/forms/centre_data" -Method "Get" -Headers $header | ConvertFrom-Json);

    $result = $result.vaccines;
    for ($i = 0; $i -lt $result.Count; $i++) {
        $vaccine = $result[$i];
        $districts = $vaccine.regions.districts;
        for ($j = 0; $j -lt $districts.Count; $j++) {
            $district = $districts[$j];
            $districtRef = ($reference.children | Where-Object name_eng -ceq $district.name);
            $centers = $district.centers;
            for ($k = 0; $k -lt $centers.Count; $k++) {
                $center = $centers[$k];
                $center.psobject.properties.remove("code");
                $center | Add-Member -MemberType NoteProperty -Name "cv_ctc_type" -Value $center.type;
                $center.psobject.properties.remove("type");
                $center.psobject.properties.remove("quota");
                $center.psobject.properties.remove("cname");
                $center.psobject.properties.remove("sname");
                $center | Add-Member -MemberType NoteProperty -Name "center_id" -Value ($districtRef.children | Where-Object name_eng -ceq $center.name).id;
            }
        }
        $vaccine | Add-Member -MemberType NoteProperty -Name districts -Value ($vaccine.regions | ForEach-Object { $_.districts });
        $vaccine.psobject.properties.remove("regions");
    }

    if ($cv_name.Length -gt 0) {
        return ($result | Where-Object name -like $cv_name);
    }
    else {
        return $result;
    }
}

function Get-VaccineQuery {
    $ProgressPreference = "SilentlyContinue";
    Clear-Host;
    $title = "========================Covid Vaccine Query========================";
    Write-Host $title;
    Write-Host "`nChoose a vaccine type:";
    Write-Host "`t1: Sinovac";
    Write-Host "`t2: BioNTech/Fosun";
    do {
        $cv_name = Read-Host "`nEnter a number (1-2)";
        switch ($cv_name) {
            '1' {
                $cv_name = "Sinovac";
            }
            '2' {
                $cv_name = "BioNTech/Fosun";
            }
        }
    } while (($cv_name -ne "Sinovac" -and $cv_name -ne "BioNTech/Fosun" ));

    Clear-Host;
    Write-Host $title;
    Write-Host "Vaccine type:`t$($cv_name)";
    Write-Host "`nChoose a district:";
    $center_list = Get-VaccineCenters -cv_name $cv_name;
    $districts = $center_list.districts;
    for ($i = 0; $i -lt $districts.Count; $i++) {
        Write-Host "`t$($i + 1): $($districts[$i].name)";
    }
    do {
        $option = Read-Host "`nEnter a number (1-$($districts.Count))";
        $district = 0;
        $success = [int]::TryParse($option, [ref]$district);
    } while (($success -ne $true -or $district -lt 1 -or $district -gt $districts.Count));
    $district = $districts[$district - 1].name;

    Clear-Host;
    Write-Host $title;
    Write-Host "Vaccine type:`t$($cv_name)";
    Write-Host "    District:`t$($district)";
    Write-Host "`nChoose a center:";
    $centers = ($center_list.districts | Where-Object name -ceq $district).centers;
    for ($i = 0; $i -lt $centers.Count; $i++) {
        Write-Host "`t$($i + 1): $($centers[$i].name)";
    }
    do {
        $option = Read-Host "`nEnter a number (1-$($centers.Count))";
        $center_id = 0;
        $success = [int]::TryParse($option, [ref]$center_id);
    } while (($success -ne $true -or $center_id -lt 1 -or $center_id -gt $centers.Count));
    $center = $centers[$center_id - 1].name;
    $cv_ctc_type = $centers[$center_id - 1].cv_ctc_type;
    $center_id = $centers[$center_id - 1].center_id;

    Clear-Host;
    Write-Host $title;
    Write-Host "Vaccine type:`t$($cv_name)";
    Write-Host "    District:`t$($district)";
    Write-Host "      Center:`t$($center)";
    do {
        $first_dose_date = Read-Host "`nEnter the first dose date in YYYY-MM-DD format:`n`t(Note: leave empty if not applicable)";
        if ($first_dose_date.Length -le 0) {
            $first_dose_date = $null;
        }
        else {
            $date = Get-Date;
            $success = [System.Datetime]::TryParseExact($first_dose_date, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$date);
            if ($true -eq $success) {
                if ($cv_name -eq "Sinovac") {
                    $first_dose_date = $date.AddDays(27).toString("yyyy-MM-dd");
                }
                elseif ($cv_name -eq "BioNTech/Fosun") {
                    $first_dose_date = $date.AddDays(20).toString("yyyy-MM-dd");
                }
            }
        }
    } while (($null -ne $first_dose_date) -and ($true -ne $success));

    Clear-Host;
    Write-Host $title;
    Write-Host "Vaccine type:`t$($cv_name)";
    Write-Host "    District:`t$($district)";
    Write-Host "      Center:`t$($center)";
    if ($null -eq $first_dose_date) {
        Write-Host "        Dose:`t1st";
    }
    else {
        Write-Host "        Dose:`t2nd";
    }

    Get-VaccineTimeSlots -dateLimit "9999-99-99" -center_id $center_id -cv_ctc_type $cv_ctc_type -cv_name $cv_name  -first_dose_date $first_dose_date | Format-Table -AutoSize -Wrap -RepeatHeader;
    $ProgressPreference = "Continue";
}

Get-VaccineQuery;
cmd /c pause;
