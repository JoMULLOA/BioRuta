// src/services/chatCleanup.service.js
import { AppDataSource } from "../config/configDb.js";
import Mensaje from "../entity/mensaje.entity.js";
import { procesarMensajeTemporal } from "./chatDistribuidor.service.js";

const mensajeRepository = AppDataSource.getRepository(Mensaje);

/**
 * Limpia mensajes temporales que no han sido procesados
 * @param {number} horasLimite - Mensajes más antiguos que X horas
 * @returns {Promise<Object>} Estadísticas de limpieza
 */
export async function limpiarMensajesTemporales(horasLimite = 1) {
  try {
    console.log(`🧹 Iniciando limpieza de mensajes temporales (>${horasLimite}h)...`);
    
    const fechaLimite = new Date();
    fechaLimite.setHours(fechaLimite.getHours() - horasLimite);

    // Buscar mensajes antiguos no procesados
    const mensajesAntiguos = await mensajeRepository.find({
      where: {
        fecha: { $lt: fechaLimite }
      },
      relations: ["emisor", "receptor"],
      order: { fecha: "ASC" }
    });

    const estadisticas = {
      encontrados: mensajesAntiguos.length,
      reprocesados: 0,
      eliminados: 0,
      errores: 0
    };

    for (const mensaje of mensajesAntiguos) {
      try {
        // Intentar reprocesar
        console.log(`🔄 Reprocesando mensaje ${mensaje.id}...`);
        await procesarMensajeTemporal(mensaje);
        estadisticas.reprocesados++;
        
      } catch (error) {
        console.error(`❌ Error al reprocesar mensaje ${mensaje.id}:`, error.message);
        
        // Si falla el reprocesamiento, eliminar mensaje temporal
        try {
          await mensajeRepository.delete(mensaje.id);
          estadisticas.eliminados++;
          console.log(`🗑️ Mensaje ${mensaje.id} eliminado por error persistente`);
        } catch (deleteError) {
          console.error(`❌ Error al eliminar mensaje ${mensaje.id}:`, deleteError.message);
          estadisticas.errores++;
        }
      }
    }

    console.log(`✅ Limpieza completada:`, estadisticas);
    return estadisticas;

  } catch (error) {
    console.error("❌ Error en limpieza de mensajes temporales:", error.message);
    throw error;
  }
}

/**
 * Obtiene estadísticas de la tabla temporal
 * @returns {Promise<Object>} Estadísticas
 */
export async function obtenerEstadisticasTemporales() {
  try {
    const totalMensajes = await mensajeRepository.count();
    
    const mensajesUltimaHora = await mensajeRepository.count({
      where: {
        fecha: { $gte: new Date(Date.now() - 60 * 60 * 1000) }
      }
    });

    const mensajesAntiguos = await mensajeRepository.count({
      where: {
        fecha: { $lt: new Date(Date.now() - 60 * 60 * 1000) }
      }
    });

    return {
      totalMensajes,
      mensajesUltimaHora,
      mensajesAntiguos,
      fecha: new Date()
    };

  } catch (error) {
    console.error("Error al obtener estadísticas temporales:", error.message);
    throw error;
  }
}

/**
 * Job automático de limpieza (para ejecutar cada X tiempo)
 */
export async function jobLimpiezaAutomatica() {
  try {
    console.log("🕐 Ejecutando job de limpieza automática...");
    
    const estadisticas = await limpiarMensajesTemporales(2); // 2 horas
    
    // Solo logear si hay actividad
    if (estadisticas.encontrados > 0) {
      console.log("🧹 Job de limpieza completado:", estadisticas);
    }
    
    return estadisticas;
    
  } catch (error) {
    console.error("❌ Error en job de limpieza automática:", error.message);
    return { error: error.message };
  }
}

/**
 * Inicializar job de limpieza periódico
 * @param {number} intervaloMinutos - Cada cuántos minutos ejecutar
 */
export function iniciarJobLimpieza(intervaloMinutos = 60) {
  console.log(`🕐 Iniciando job de limpieza cada ${intervaloMinutos} minutos`);
  
  setInterval(async () => {
    await jobLimpiezaAutomatica();
  }, intervaloMinutos * 60 * 1000);
  
  // Ejecutar una vez al inicio
  setTimeout(() => jobLimpiezaAutomatica(), 5000); // 5 segundos después del inicio
}
