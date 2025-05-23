// Módulo para guardar códigos con expiración temporal
const verificacionMap = new Map();

export function guardarCodigo(email, codigo, tiempoExpiracionMs = 5 * 60 * 1000) {
  verificacionMap.set(email, codigo);
  setTimeout(() => verificacionMap.delete(email), tiempoExpiracionMs);
}

export function obtenerCodigo(email) {
  return verificacionMap.get(email);
}

export function eliminarCodigo(email) {
  verificacionMap.delete(email);
}
