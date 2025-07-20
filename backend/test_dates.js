"use strict";
import { convertirFechaChile, obtenerFechaActualChile, debugFecha, formatearFechaChile } from "./src/utils/dateChile.js";

console.log("🧪 Probando utilidades de fecha Chile (ACTUALIZADA)...\n");

// Simular una fecha ISO como la que envía el frontend
// Si el usuario selecciona 19 de julio 2025 a las 23:25 hora de Chile
const fechaISOEjemplo = "2025-07-19T23:25:00.000Z"; // El frontend envía esto

console.log("📅 Fecha ISO de ejemplo (como la envía el frontend):", fechaISOEjemplo);
console.log("🔍 Debug de la fecha:", debugFecha(fechaISOEjemplo));

const fechaChile = convertirFechaChile(fechaISOEjemplo);
console.log("📅 Fecha convertida (NUEVA FUNCIÓN):", fechaChile.toISOString());
console.log("🕐 Hora en formato HH:mm (Chile):", formatearFechaChile(fechaChile, 'HH:mm'));
console.log("📆 Fecha completa formateada (Chile):", formatearFechaChile(fechaChile, 'YYYY-MM-DD HH:mm:ss'));

const ahoraChile = obtenerFechaActualChile();
console.log("⏰ Fecha actual en Chile:", formatearFechaChile(ahoraChile, 'YYYY-MM-DD HH:mm:ss'));

// Probar con otra fecha más clara
console.log("\n🧪 Prueba con fecha clara - 20 de julio 2025 a las 15:30 Chile:");
const fechaClara = "2025-07-20T15:30:00.000Z";
const fechaChileClara = convertirFechaChile(fechaClara);
console.log("Entrada:", fechaClara);
console.log("Salida ISO:", fechaChileClara.toISOString());
console.log("Hora Chile:", formatearFechaChile(fechaChileClara, 'YYYY-MM-DD HH:mm:ss'));

console.log("\n✅ Prueba completada");
