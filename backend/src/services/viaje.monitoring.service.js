"use strict";
import cron from 'node-cron';
import { procesarCambiosEstadoAutomaticos } from './viaje.validation.service.js';

/**
 * Servicio de monitoreo automático de viajes
 * Procesa cambios de estado automáticos cada 5 minutos
 */
class ViajeMonitoringService {
  static isRunning = false;
  static cronJob = null;

  /**
   * Iniciar el monitoreo automático de viajes
   */
  static start() {
    if (this.isRunning) {
      console.log('🔄 El monitoreo de viajes ya está ejecutándose');
      return;
    }

    console.log('🚀 Iniciando monitoreo automático de viajes...');

    // Ejecutar cada 5 minutos: '*/5 * * * *'
    // Para testing más frecuente, puedes usar: '*/1 * * * *' (cada minuto)
    this.cronJob = cron.schedule('*/5 * * * *', async () => {
      try {
        console.log('⏰ Ejecutando monitoreo automático de viajes...');
        await procesarCambiosEstadoAutomaticos();
      } catch (error) {
        console.error('❌ Error en monitoreo automático:', error);
      }
    }, {
      scheduled: true,
      timezone: "America/Santiago" // Zona horaria de Chile
    });

    this.isRunning = true;
    console.log('✅ Monitoreo automático iniciado - ejecutándose cada 5 minutos');

    // Ejecutar una vez al inicio para procesar viajes pendientes
    setTimeout(async () => {
      try {
        console.log('🔍 Procesamiento inicial de viajes pendientes...');
        await procesarCambiosEstadoAutomaticos();
      } catch (error) {
        console.error('❌ Error en procesamiento inicial:', error);
      }
    }, 10000); // Esperar 10 segundos después del inicio
  }

  /**
   * Detener el monitoreo automático
   */
  static stop() {
    if (!this.isRunning) {
      console.log('⚠️ El monitoreo de viajes no está ejecutándose');
      return;
    }

    if (this.cronJob) {
      this.cronJob.destroy();
      this.cronJob = null;
    }

    this.isRunning = false;
    console.log('🛑 Monitoreo automático de viajes detenido');
  }

  /**
   * Obtener estado del monitoreo
   */
  static getStatus() {
    return {
      isRunning: this.isRunning,
      message: this.isRunning ? 'Monitoreo activo' : 'Monitoreo inactivo'
    };
  }

  /**
   * Ejecutar procesamiento manual (para testing)
   */
  static async executeNow() {
    try {
      console.log('🔄 Ejecutando procesamiento manual de viajes...');
      const resultado = await procesarCambiosEstadoAutomaticos();
      console.log('✅ Procesamiento manual completado:', resultado);
      return resultado;
    } catch (error) {
      console.error('❌ Error en procesamiento manual:', error);
      throw error;
    }
  }
}

export default ViajeMonitoringService;
