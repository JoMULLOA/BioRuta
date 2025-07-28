"use strict";
import moment from "moment-timezone";

// Zona horaria de Chile
const CHILE_TIMEZONE = "America/Santiago";

/**
 * Convierte una fecha ISO string a Date interpretándola como hora de Chile
 * @param {string} isoString - Fecha en formato ISO string (interpretada como hora de Chile)
 * @returns {Date} - Fecha ajustada para almacenamiento correcto
 */
export function convertirFechaChile(isoString) {
  console.log("🔥🔥🔥 EJECUTANDO convertirFechaChile CON:", isoString);
  
  // El frontend envía la fecha en ISO pero representa la hora LOCAL de Chile
  // Ahora vamos a restar 8 horas como solicitado
  
  const fechaUTC = new Date(isoString);
  
  // Restar 4 horas en invierno

  const fechaCorregida = new Date(fechaUTC.getTime() - (4 * 60 * 60 * 1000));
  
  console.log("🔥🔥🔥 RESULTADO convertirFechaChile (restando 84):", fechaCorregida.toISOString());
  
  return fechaCorregida;
}
/**
 * Obtiene la fecha y hora actual en zona horaria de Chile
 * @returns {Date} - Fecha actual en zona horaria de Chile
 */
export function obtenerFechaActualChile() {
  return moment.tz(CHILE_TIMEZONE).toDate();
}

/**
 * Convierte una fecha a string formateado en zona horaria de Chile
 * @param {Date} fecha - Fecha a formatear
 * @param {string} formato - Formato momento.js (por defecto: 'YYYY-MM-DD HH:mm:ss')
 * @returns {string} - Fecha formateada en zona horaria de Chile
 */
export function formatearFechaChile(fecha, formato = 'YYYY-MM-DD HH:mm:ss') {
  return moment.tz(fecha, CHILE_TIMEZONE).format(formato);
}

/**
 * Valida si una fecha está en el futuro (zona horaria de Chile)
 * @param {Date|string} fecha - Fecha a validar
 * @returns {boolean} - True si está en el futuro
 */
export function esFechaFutura(fecha) {
  const fechaAValidar = typeof fecha === 'string' ? convertirFechaChile(fecha) : fecha;
  const ahora = obtenerFechaActualChile();
  
  return fechaAValidar > ahora;
}

/**
 * Obtiene información de debug sobre una fecha
 * @param {string} isoString - Fecha ISO string
 * @returns {object} - Información de debug
 */
export function debugFecha(isoString) {
  const momentUTC = moment.utc(isoString);
  const momentChile = momentUTC.tz(CHILE_TIMEZONE);
  
  return {
    original: isoString,
    utc: momentUTC.format('YYYY-MM-DD HH:mm:ss [UTC]'),
    chile: momentChile.format('YYYY-MM-DD HH:mm:ss [America/Santiago]'),
    offsetChile: momentChile.format('Z'),
    esVerano: momentChile.isDST(), // Horario de verano en Chile
  };
}
