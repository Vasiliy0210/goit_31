## Cat Facts Fetcher
function getCatFact() {

  var url = "https://catfact.ninja/fact";


  var response = UrlFetchApp.fetch(url);
  var data = JSON.parse(response.getContentText());

  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();


  sheet.appendRow([new Date(), data.fact]);
}

## Edit Logger
function onEdit(e) {
  var range = e.range;
  var sheet = range.getSheet();

  if (sheet.getName() !== "Sheet2") return;


  var headerRow = 1;
  var headers = sheet.getRange(headerRow, 1, 1, sheet.getLastColumn()).getValues()[0];


  var statusCol = headers.indexOf("Status") + 1;
  var userIdCol = headers.indexOf("user_id") + 1;

  if (statusCol === 0 || userIdCol === 0) return; // if headers not found


  if (range.getColumn() !== statusCol || range.getRow() === headerRow) return;


  var newValue = e.value;


  var userId = sheet.getRange(range.getRow(), userIdCol).getValue();


  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var logSheet = ss.getSheetByName("EditLog");
  if (!logSheet) {
    logSheet = ss.insertSheet("EditLog");
    logSheet.appendRow(["Timestamp", "Row", "User_ID", "New Status"]);
  }


  logSheet.appendRow([
    new Date(),
    range.getRow(),
    userId,
    newValue
  ]);
}

## importrange with Headers
function pullFilteredData() {

  const sourceId = "1Plwieueml1HJzyJmIICW6DVXJhq1b_uivYrVQscjJhY";
  const source = SpreadsheetApp.openById(sourceId);
  const sourceSheet = source.getSheetByName("game_data"); // change if needed

  const target = SpreadsheetApp.getActiveSpreadsheet();
  const targetSheetName = "Sheet6"; // choose your sheet name
  let targetSheet = target.getSheetByName(targetSheetName);
  if (!targetSheet) {
    targetSheet = target.insertSheet(targetSheetName);
  } else {
    targetSheet.clearContents();
  }

  const lastRow = sourceSheet.getLastRow();
  if (lastRow < 1) return;
  const data = sourceSheet.getRange(1, 1, lastRow, 3).getValues();

  const filtered = data.filter((row, idx) => {
    if (idx === 0) return true; // header
    const val = parseFloat(row[1]);
    return !isNaN(val) && val > 0;
  });

  targetSheet.getRange(1, 1, filtered.length, filtered[0].length).setValues(filtered);
}


function createDailyTrigger() {
  ScriptApp.getProjectTriggers().forEach(tr => {
    if (tr.getHandlerFunction() === "pullFilteredData") {
      ScriptApp.deleteTrigger(tr);
    }
  });

  ScriptApp.newTrigger("pullFilteredData")
    .timeBased()
    .everyDays(1)
    .atHour(2)
    .create();
}
