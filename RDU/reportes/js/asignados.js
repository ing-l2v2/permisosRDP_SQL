let sortDirection = {};

function sortTable(n, tableId) {
  let table = document.getElementById(tableId);
  let tbody = table.tBodies[0];
  let rows = [...tbody.rows];

  let dir = sortDirection[tableId + "_" + n] ? "desc" : "asc";

  rows.sort((a, b) => {
    let A = a.cells[n].innerText.toLowerCase();
    let B = b.cells[n].innerText.toLowerCase();

    return dir === "asc" ? A.localeCompare(B) : B.localeCompare(A);
  });

  rows.forEach((r) => tbody.appendChild(r));

  sortDirection[tableId + "_" + n] = !sortDirection[tableId + "_" + n];

  updateArrows(table, n, dir);
}

function updateArrows(table, col, dir) {
  table.querySelectorAll("th .arrow").forEach((a) => (a.innerText = ""));

  let arrow = table.rows[0].cells[col].querySelector(".arrow");

  arrow.innerText = dir === "asc" ? "▲" : "▼";
}

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

document.querySelectorAll(".colFilter").forEach((input) => {
  input.addEventListener("keyup", function () {
    let table = document.getElementById(this.dataset.table);
    let col = this.dataset.col;
    let value = this.value.toLowerCase();

    table.querySelectorAll("tbody tr").forEach((row) => {
      let cell = row.cells[col].innerText.toLowerCase();

      row.style.display = cell.includes(value) ? "" : "none";
    });
  });
});

function marcarExpirados() {
  let hoy = new Date();
  let limite = new Date(hoy.getTime() + 12 * 60 * 60 * 1000); // +12 horas

  document.querySelectorAll("#tablaSql tbody tr").forEach((row) => {
    let fecha = row.cells[7].innerText; // Columna de Expira (Fin)
    let estado = row.cells[10].innerText; // Columna de Estado (ASIGNADO, REVOCADO)
    let f = new Date(fecha.replace("'", ""));

    if (f <= hoy && estado == "REVOCADO") {
      row.classList.add("expired");
    } else if (f >= hoy && f <= limite && estado != "REVOCADO") {
      row.classList.add("warning"); // por vencer en 4h
    }
  });

  document.querySelectorAll("#tablaRdp tbody tr").forEach((row) => {
    let fecha = row.cells[6].innerText; // Columna de Expira (Fin)
    let estado = row.cells[9].innerText; // Columna de Estado (ASIGNADO, REVOCADO)
    let f = new Date(fecha);

    if (f <= hoy && estado == "REVOCADO") {
      row.classList.add("expired");
    } else if (f >= hoy && f <= limite && estado != "REVOCADO") {
      row.classList.add("warning"); // por vencer en 4h
    }
  });
}

// document.addEventListener("DOMContentLoaded", marcarExpirados);
document.addEventListener("DOMContentLoaded", () => {
  marcarExpirados(); // ejecuta al cargar
  setInterval(marcarExpirados, 60000); // ejecuta cada 60 segundos
});

function irSql() {
  document.getElementById("accesosSql").scrollIntoView({ behavior: "smooth" });
}

function limpiarNullTablas() {
  const celdas = document.querySelectorAll("table td, table th");

  celdas.forEach((celda) => {
    if (celda.textContent.trim().toUpperCase() === "NULL") {
      celda.textContent = "";
    }
  });
}

window.onload = function () {
  limpiarNullTablas();
};
