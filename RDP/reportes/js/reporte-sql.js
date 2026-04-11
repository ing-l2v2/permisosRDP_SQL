document.addEventListener("DOMContentLoaded", () => {
  const tabla = document.getElementById("tablaDatos");
  const tbody = tabla.querySelector("tbody");
  const ths = tabla.querySelectorAll("thead th");
  const totalVisible = document.getElementById("totalVisible");

  // ===========================
  // ORDENAMIENTO
  // ===========================
  ths.forEach((th, index) => {
    th.addEventListener("click", () => ordenarTabla(index, th));
  });

  function actualizarTotal() {
    const visibles = Array.from(tbody.querySelectorAll("tr")).filter(
      (r) => r.style.display !== "none",
    ).length;

    totalVisible.textContent = visibles;
  }

  function ordenarTabla(colIndex, th) {
    let filas = Array.from(tbody.querySelectorAll("tr"));
    let asc = !th.classList.contains("sort-asc");

    ths.forEach((h) => h.classList.remove("sort-asc", "sort-desc"));
    th.classList.add(asc ? "sort-asc" : "sort-desc");

    filas.sort((a, b) => {
      let x = a.children[colIndex].innerText.toLowerCase();
      let y = b.children[colIndex].innerText.toLowerCase();
      return asc ? x.localeCompare(y) : y.localeCompare(x);
    });

    filas.forEach((f) => tbody.appendChild(f));
    actualizarTotal();
  }

  // ===========================
  // BUSQUEDA GENERAL
  // ===========================
  document.getElementById("searchBox").addEventListener("keyup", () => {
    filtrarTodo();
  });

  // ===========================
  // FILTROS POR COLUMNA
  // ===========================
  const filtros = document.querySelectorAll(".filtro-columna");

  filtros.forEach((f) => {
    f.addEventListener("change", () => filtrarTodo());
  });

  function filtrarTodo() {
    let texto = document.getElementById("searchBox").value.toLowerCase();

    const fServidor = document.getElementById("fServ").value;
    const fUsuario = document.getElementById("fUsr").value;
    const fBD = document.getElementById("fBD").value;
    const fRol = document.getElementById("fRol").value;
    const fLogin = document.getElementById("fLogin").value;

    tbody.querySelectorAll("tr").forEach((row) => {
      let tServ = row.children[0].innerText;
      let tBD = row.children[1].innerText;
      let tUsr = row.children[2].innerText;
      let tRol = row.children[3].innerText;
      let tLogin = row.children[4].innerText;

      let visible = true;

      if (texto && !row.innerText.toLowerCase().includes(texto))
        visible = false;
      if (fServidor && tServ !== fServidor) visible = false;
      if (fUsuario && tUsr !== fUsuario) visible = false;
      if (fBD && tBD !== fBD) visible = false;
      if (fRol && tRol !== fRol) visible = false;
      if (fLogin && tLogin !== fLogin) visible = false;

      row.style.display = visible ? "" : "none";
    });
    actualizarTotal();
  }
  actualizarTotal();
});
