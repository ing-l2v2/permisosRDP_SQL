document.addEventListener("DOMContentLoaded", () => {
  const tables = ["tablaAccesos", "tablaDiag"];
  const searchGlobal = document.getElementById("searchGlobal");

  function filtrar() {
    const texto = searchGlobal.value.toLowerCase();

    tables.forEach((id) => {
      const tabla = document.getElementById(id);
      if (!tabla) return;

      const filas = tabla.querySelectorAll("tbody tr");

      filas.forEach((fila) => {
        const contenido = fila.textContent.toLowerCase();
        fila.style.display = contenido.includes(texto) ? "" : "none";
      });
    });
  }

  // Búsqueda global
  if (searchGlobal) {
    searchGlobal.addEventListener("keyup", filtrar);
  }
});
