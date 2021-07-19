/**
 * API References:
 * Vaccine Data [GET]: https://booking.covidvaccine.gov.hk/forms/vaccine_details
 * Center Data [GET] (for center list): https://booking.covidvaccine.gov.hk/forms/centre_data
 * Center Data [GET] (for center_id): https://booking.covidvaccine.gov.hk/forms/ct_center
 * Timeslot Data [POST]: https://bookingform.covidvaccine.gov.hk/forms/api_center
 */

document.addEventListener("DOMContentLoaded", onLoad);

/** @type {string} */
var cv_name = "";
/** @type {string} */
var cv_ctc_type = "";
/** @type {string} */
var center_id = "";

/** @type {Array} */
var district_list = [];
/** @type {Array} */
var center_list = [];

/** @type {HTMLSelectElement} */
var vaccineSelect = null;
/** @type {HTMLSelectElement} */
var districtSelect = null;
/** @type {HTMLSelectElement} */
var centerSelect = null;

/** @type {EventListener} */
function onSelectVaccineType() {
  districtSelect.disabled = true;
  centerSelect.disabled = true;
  districtSelect.selectedIndex = 0;
  centerSelect.selectedIndex = 0;
  if (!(vaccineSelect?.value?.length > 0)) return;
  districtSelect.disabled = false;
}

/** @type {EventListener} */
function onSelectDistrict() {
  centerSelect.disabled = true;
  centerSelect.selectedIndex = 0;
  if (!(districtSelect?.value?.length > 0)) return;
  centerSelect.disabled = false;
}

/** @type {EventListener} */
function onSelectCenter() {
  vaccineSelect.disabled = true;
  districtSelect.disabled = true;
  centerSelect.disabled = true;

  // TODO: fetch timeslot data

  vaccineSelect.disabled = false;
  districtSelect.disabled = false;
  centerSelect.disabled = false;
}

/** @type {EventListener} */
async function onLoad() {
  vaccineSelect = document.getElementById("cv_name");
  districtSelect = document.getElementById("district_id");
  centerSelect = document.getElementById("center_id");
  vaccineSelect.addEventListener("change", onSelectVaccineType);
  districtSelect.addEventListener("change", onSelectDistrict);
  centerSelect.addEventListener("change", onSelectCenter);

  try {
    let res = await fetch("https://booking.covidvaccine.gov.hk/forms/ct_center");
    if (!res.ok) throw new Error(`Http Error with status {${res.status}: ${res.statusText}}`);
    const data = res.json();

    res = await fetch("https://booking.covidvaccine.gov.hk/forms/centre_data");
    if (!res.ok) throw new Error(`Http Error with status {${res.status}: ${res.statusText}}`);
    const result = await res.json();

    for (let i = result.vaccines.length - 1; i >= 0; --i) {
      const vaccine = result.vaccines[i];
      vaccine.districts = [];
      for (let j = vaccine.regions.length - 1; j >= 0; --j) {
        const region = vaccine.regions[j];
        for (let k = region.districts.length - 1; k >= 0; --k) {
          const district = region.districts[k];
          for (let l = district.centers.length - 1; l >= 0; --l) {
            // rename type to cv_cvc_type
            district.centers[l].cv_cvc_type = district.centers[l].type;
            delete district.centers[l].type;

            // remove unnecessary data
            delete district.centers[l].code;
            delete district.centers[l].quota;

            // TODO: find center_id from data (id)

          }

          // TODO: find name_eng, name_tc, name_sc from data

          vaccine.districts.push(district);
        }
      }
      delete vaccine.regions;
      result.vaccines[i] = vaccine;
    }

    center_list = result;
  } catch (err) {
    console.error("Error fetching center data:\n", err);
  }
}
