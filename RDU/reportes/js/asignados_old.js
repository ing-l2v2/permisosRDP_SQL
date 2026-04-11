document.getElementById("globalSearch").addEventListener("keyup", function () {
  let value = this.value.toLowerCase();

  document.querySelectorAll("tbody tr").forEach((row) => {
    row.style.display = row.innerText.toLowerCase().includes(value)
      ? ""
      : "none";
  });
});

document.querySelectorAll(".groupSearch").forEach((box) => {
  box.addEventListener("keyup", function () {
    let value = this.value.toLowerCase();

    let table = document.getElementById(this.dataset.table);

    table.querySelectorAll("tbody tr").forEach((row) => {
      row.style.display = row.innerText.toLowerCase().includes(value)
        ? ""
        : "none";
    });
  });
});

function sortTable(n, tableId) {
  let table = document.getElementById(tableId);

  let rows = Array.from(table.rows).slice(1);

  let asc = table.classList.contains("asc");

  rows.sort((a, b) => {
    let A = a.cells[n].innerText;

    let B = b.cells[n].innerText;

    return asc ? A.localeCompare(B) : B.localeCompare(A);
  });

  rows.forEach((r) => table.tBodies[0].appendChild(r));

  table.classList.toggle("asc");
}
