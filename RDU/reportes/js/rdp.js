document.addEventListener("DOMContentLoaded", () => {
  const modal = document.getElementById("cmdModal");
  const modalText = document.getElementById("cmdContent");
  const closeBtn = document.getElementById("closeModal");
  const copyBtn = document.getElementById("copyBtn");
  // Filtro global
  const filtro = document.getElementById("txtFiltro");
  const tabla = document.getElementById("tabla");

  closeBtn.addEventListener("click", () => (modal.style.display = "none"));

  filtro.addEventListener("keyup", () => {
    const valor = filtro.value.toLowerCase();
    const filas = tabla.querySelectorAll("tbody tr");

    filas.forEach((fila) => {
      const texto = fila.innerText.toLowerCase();
      fila.style.display = texto.includes(valor) ? "" : "none";
    });
  });

  copyBtn.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(modalText.value);
      alert("Copiado al portapapeles");
    } catch (e) {
      alert("No se pudo copiar automáticamente.");
    }
  });
});

function generarFila(btn) {
  const tr = btn.closest("tr");
  const td = tr.querySelectorAll("td");

  // Extraer datos usando los índices verificados
  const numreg = td[0].innerText.trim();
  const servidor = td[1].innerText.trim();
  const bd = td[2].innerText.trim();
  const usr = td[3].innerText.trim();
  const expira = td[4].innerText.trim();
  const coduser = td[5].innerText.trim();

  const dom = td[8].innerText.trim();
  const rdp = td[9].querySelector("input").checked;
  const sql = td[10].querySelector("input").checked;
  const adm = td[11].querySelector("input").checked ? "ADM" : "RDU";

  const r = td[12].querySelector("input").checked;
  const w = td[13].querySelector("input").checked;
  const rw = td[14].querySelector("input").checked;
  const sp = td[15].querySelector("input").checked;
  const rwsp = td[16].querySelector("input").checked;

  const sm = td[17].querySelector("input").checked;
  const rwsm = td[18].querySelector("input").checked;
  const job = td[19].querySelector("input").checked;
  const sysad = td[20].querySelector("input").checked;
  const prf = td[21].querySelector("input").checked;
  const own = td[22].querySelector("input").checked;

  let comandos = [];

  // ----------------------------------------
  //             RDP
  // ----------------------------------------
  if (rdp) {
    if (dom == "FIDENSLAT\\" && usr == "mlizama") {
      usr = "marcelo.lizama";
    }
    const cmd = `.\\rdpAdd.ps1 ${servidor} ${dom}${usr} ${adm} 48 $null ${numreg}`;
    comandos.push(cmd);
  }

  // ----------------------------------------
  //             SQL
  // ----------------------------------------
  if (sql) {
    const octeto = servidor.split(".")[3];

    // Permisos base
    let tipo = "";
    if (rwsp) tipo = "RWSP";
    else if (rw) tipo = "RW";
    else if (r) tipo = "R";
    else if (w) tipo = "W";
    else if (sp) tipo = "SP";

    if (tipo !== "") {
      if (/^10\s*-/.test(servidor)) {
        //if (servidor.includes("10 -")) {
        comandos.push(
          `.\\sqlAzAdd.ps1 "sql-ginger.database.windows.net" "autenticacion,autenticacion-sura-cont,FlujoVenta,pagos,pagos-sura-cont" "${usr}" "${tipo}" ${numreg} "${coduser}" "${expira}" `,
        );
      } else {
        comandos.push(
          `.\\sqlAdd.ps1 ${octeto} ${usr} "${tipo}" "${bd}" 48 $null`,
        );
      }
    }

    if (sm) comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} SM ${bd} 48 $null`);
    if (rwsm)
      comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} RWSM ${bd} 48 $null`);
    if (job) comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} JOB ${bd} 48 $null`);
    if (prf) comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} PRF ${bd} 48 $null`);
    if (sysad)
      comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} ALL ${bd} 48 $null`);
    if (own) comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} OWN ${bd} 48 $null`);
  }

  // ----------------------------------------
  // MOSTRAR MODAL
  // ----------------------------------------
  document.getElementById("cmdContent").value = comandos.join("\n");
  document.getElementById("cmdModal").style.display = "block";
  ocultarFila(btn);
}

function generarTodo(btn) {
  const filas = document.querySelectorAll("#tabla tbody tr");
  let comandos = [];

  filas.forEach((tr) => {
    const td = tr.querySelectorAll("td");
    console.log(td.length);
    if (td.length < 24) return; // evitar filas vacías o incompletas

    // Extraer datos
    const numreg = td[0].innerText.trim();
    const servidor = td[1].innerText.trim();
    const bd = td[2].innerText.trim();
    const usr = td[3].innerText.trim();
    const expira = td[4].innerText.trim();
    const coduser = td[5].innerText.trim();

    let dom = td[8].innerText.trim();
    const rdp = td[9].querySelector("input").checked;
    const sql = td[10].querySelector("input").checked;
    const adm = td[11].querySelector("input").checked ? "ADM" : "RDU";

    const r = td[12].querySelector("input").checked;
    const w = td[13].querySelector("input").checked;
    const rw = td[14].querySelector("input").checked;
    const sp = td[15].querySelector("input").checked;
    const rwsp = td[16].querySelector("input").checked;

    const sm = td[17].querySelector("input").checked;
    const rwsm = td[18].querySelector("input").checked;
    const job = td[19].querySelector("input").checked;
    const sysad = td[20].querySelector("input").checked;
    const prf = td[21].querySelector("input").checked;
    const own = td[22].querySelector("input").checked;

    //if (!dom) dom = ".\\";
    //else dom = dom.replace("\\", "\\\\");

    // -------------------------------
    // RDP
    // -------------------------------
    if (rdp) {
      if (dom == "FIDENSLAT\\" && usr == "mlizama") {
        usr = "marcelo.lizama";
      }
      const cmd = `.\\rdpAdd.ps1 ${servidor} ${dom}${usr} ${adm} 48 $null ${numreg}`;
      comandos.push(cmd);
    }

    // -------------------------------
    // SQL
    // -------------------------------
    if (sql) {
      const octeto = servidor.split(".")[3];

      let tipo = "";
      if (rwsp) tipo = "RWSP";
      else if (rw) tipo = "RW";
      else if (r) tipo = "R";
      else if (w) tipo = "W";
      else if (sp) tipo = "SP";

      if (tipo !== "") {
        if (/^10\s*-/.test(servidor)) {
          //if (servidor.includes("10 -")) {
          comandos.push(
            `.\\sqlAzAdd.ps1 "sql-ginger.database.windows.net" "autenticacion,autenticacion-sura-cont,FlujoVenta,pagos,pagos-sura-cont" "${usr}" "${tipo}" ${numreg} "${coduser}" "${expira}" `,
          );
        } else {
          comandos.push(
            `.\\sqlAdd.ps1 ${octeto} ${usr} "${tipo}" "${bd}" 48 $null`,
          );
        }
      }

      if (sm) comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} SM ${bd} 48 $null`);
      if (rwsm)
        comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} RWSM ${bd} 48 $null`);
      if (job)
        comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} JOB ${bd} 48 $null`);
      if (prf)
        comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} PRF ${bd} 48 $null`);
      if (sysad)
        comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} ALL ${bd} 48 $null`);
      if (own)
        comandos.push(`.\\sqlAdd.ps1 ${octeto} ${usr} OWN ${bd} 48 $null`);
    }
  });

  // -------------------------------
  // MOSTRAR EN EL MODAL
  // -------------------------------
  document.getElementById("cmdContent").value = comandos.join("\n");
  document.getElementById("cmdModal").style.display = "block";
  ocultarFila(btn);
}

function ocultarFila(btn) {
  const tr = btn.closest("tr");
  tr.style.display = "none";
}
