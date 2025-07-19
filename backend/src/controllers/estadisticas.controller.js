"use strict";
import { AppDataSource } from "../config/configDb.js";
import User from "../entity/user.entity.js";
import Vehiculo from "../entity/vehiculo.entity.js";
import Pago from "../entity/pago.entity.js";
import Amistad from "../entity/amistad.entity.js";
import Notificacion from "../entity/notificacion.entity.js";
import Mensaje from "../entity/mensaje.entity.js";
import Viaje from "../entity/viaje.entity.js"; // MongoDB
import { handleErrorClient, handleErrorServer, handleSuccess } from "../handlers/responseHandlers.js";

export async function obtenerEstadisticasGenerales(req, res) {
  try {
    console.log("📊 Obteniendo estadísticas generales...");

    // Repositorios SQL
    const userRepository = AppDataSource.getRepository(User);
    const vehiculoRepository = AppDataSource.getRepository(Vehiculo);
    const pagoRepository = AppDataSource.getRepository(Pago);
    const amistadRepository = AppDataSource.getRepository(Amistad);
    const notificacionRepository = AppDataSource.getRepository(Notificacion);
    const mensajeRepository = AppDataSource.getRepository(Mensaje);

    // Estadísticas básicas
    const [
      totalUsuarios,
      totalVehiculos,
      totalPagos,
      totalAmistades,
      totalNotificaciones,
      totalMensajes,
      totalViajes,
      viajesActivos,
      viajesCompletados,
      viajesCancelados
    ] = await Promise.all([
      userRepository.count(),
      vehiculoRepository.count(),
      pagoRepository.count(),
      amistadRepository.count(),
      notificacionRepository.count(),
      mensajeRepository.count(),
      Viaje.countDocuments(),
      Viaje.countDocuments({ estado: 'activo' }),
      Viaje.countDocuments({ estado: 'completado' }),
      Viaje.countDocuments({ estado: 'cancelado' })
    ]);

    const viajesEnCurso = await Viaje.countDocuments({ estado: 'en_curso' });

    const estadisticas = {
      usuarios: {
        total: totalUsuarios,
        activos: totalUsuarios // Asumiendo que todos los usuarios registrados están activos
      },
      vehiculos: {
        total: totalVehiculos
      },
      viajes: {
        total: totalViajes,
        activos: viajesActivos,
        enCurso: viajesEnCurso,
        completados: viajesCompletados,
        cancelados: viajesCancelados
      },
      pagos: {
        total: totalPagos
      },
      social: {
        amistades: totalAmistades,
        mensajes: totalMensajes,
        notificaciones: totalNotificaciones
      }
    };

    console.log("✅ Estadísticas generales obtenidas:", estadisticas);
    handleSuccess(res, 200, "Estadísticas obtenidas correctamente", estadisticas);
  } catch (error) {
    console.error("❌ Error obteniendo estadísticas generales:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function obtenerDistribucionPuntuaciones(req, res) {
  try {
    console.log("📊 Obteniendo distribución de puntuaciones...");

    const userRepository = AppDataSource.getRepository(User);

    // Obtener usuarios con puntuación
    const usuarios = await userRepository
      .createQueryBuilder("user")
      .select("user.puntuacion")
      .where("user.puntuacion IS NOT NULL")
      .getMany();

    // Agrupar por rangos de puntuación
    const rangos = {
      '1-2': { cantidad: 0, color: '#f44336' },
      '3-4': { cantidad: 0, color: '#ff9800' },
      '5-6': { cantidad: 0, color: '#ffc107' },
      '7-8': { cantidad: 0, color: '#8bc34a' },
      '9-10': { cantidad: 0, color: '#4caf50' }
    };

    usuarios.forEach(usuario => {
      const puntuacion = usuario.puntuacion;
      if (puntuacion >= 1 && puntuacion <= 2) rangos['1-2'].cantidad++;
      else if (puntuacion >= 3 && puntuacion <= 4) rangos['3-4'].cantidad++;
      else if (puntuacion >= 5 && puntuacion <= 6) rangos['5-6'].cantidad++;
      else if (puntuacion >= 7 && puntuacion <= 8) rangos['7-8'].cantidad++;
      else if (puntuacion >= 9 && puntuacion <= 10) rangos['9-10'].cantidad++;
    });

    const distribucion = Object.entries(rangos).map(([puntuacion, data]) => ({
      puntuacion,
      cantidad: data.cantidad,
      color: data.color
    }));

    console.log("✅ Distribución de puntuaciones obtenida:", distribucion);
    handleSuccess(res, 200, "Distribución de puntuaciones obtenida", distribucion);
  } catch (error) {
    console.error("❌ Error obteniendo distribución de puntuaciones:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function obtenerViajesPorMes(req, res) {
  try {
    console.log("📊 Obteniendo viajes por mes...");

    // Obtener viajes de los últimos 6 meses
    const fechaInicio = new Date();
    fechaInicio.setMonth(fechaInicio.getMonth() - 6);

    const viajesPorMes = await Viaje.aggregate([
      {
        $match: {
          fecha_creacion: { $gte: fechaInicio }
        }
      },
      {
        $group: {
          _id: {
            año: { $year: "$fecha_creacion" },
            mes: { $month: "$fecha_creacion" }
          },
          viajes: { $sum: 1 }
        }
      },
      {
        $sort: { "_id.año": 1, "_id.mes": 1 }
      }
    ]);

    // Formatear datos para el frontend
    const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    const datosFormateados = viajesPorMes.map(item => ({
      mes: meses[item._id.mes - 1],
      viajes: item.viajes,
      año: item._id.año
    }));

    console.log("✅ Viajes por mes obtenidos:", datosFormateados);
    handleSuccess(res, 200, "Viajes por mes obtenidos", datosFormateados);
  } catch (error) {
    console.error("❌ Error obteniendo viajes por mes:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function obtenerClasificacionUsuarios(req, res) {
  try {
    console.log("📊 Obteniendo clasificación de usuarios...");

    const userRepository = AppDataSource.getRepository(User);

    // Obtener usuarios con clasificación
    const usuarios = await userRepository
      .createQueryBuilder("user")
      .select("user.clasificacion")
      .where("user.clasificacion IS NOT NULL")
      .getMany();

    // Agrupar por rangos de clasificación
    const rangos = {
      '4.5-5.0': { cantidad: 0, porcentaje: 0 },
      '4.0-4.4': { cantidad: 0, porcentaje: 0 },
      '3.5-3.9': { cantidad: 0, porcentaje: 0 },
      '3.0-3.4': { cantidad: 0, porcentaje: 0 },
      '2.5-2.9': { cantidad: 0, porcentaje: 0 },
      '0-2.4': { cantidad: 0, porcentaje: 0 }
    };

    const totalUsuarios = usuarios.length;

    usuarios.forEach(usuario => {
      const clasificacion = usuario.clasificacion;
      if (clasificacion >= 4.5 && clasificacion <= 5.0) rangos['4.5-5.0'].cantidad++;
      else if (clasificacion >= 4.0 && clasificacion < 4.5) rangos['4.0-4.4'].cantidad++;
      else if (clasificacion >= 3.5 && clasificacion < 4.0) rangos['3.5-3.9'].cantidad++;
      else if (clasificacion >= 3.0 && clasificacion < 3.5) rangos['3.0-3.4'].cantidad++;
      else if (clasificacion >= 2.5 && clasificacion < 3.0) rangos['2.5-2.9'].cantidad++;
      else if (clasificacion >= 0 && clasificacion < 2.5) rangos['0-2.4'].cantidad++;
    });

    // Calcular porcentajes
    const clasificacion = Object.entries(rangos).map(([rango, data]) => ({
      rango,
      cantidad: data.cantidad,
      porcentaje: totalUsuarios > 0 ? ((data.cantidad / totalUsuarios) * 100).toFixed(1) : 0
    }));

    console.log("✅ Clasificación de usuarios obtenida:", clasificacion);
    handleSuccess(res, 200, "Clasificación de usuarios obtenida", clasificacion);
  } catch (error) {
    console.error("❌ Error obteniendo clasificación de usuarios:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function obtenerDestinosPopulares(req, res) {
  try {
    console.log("📊 Obteniendo destinos populares...");

    const destinosPopulares = await Viaje.aggregate([
      {
        $group: {
          _id: "$destino.direccion",
          viajes: { $sum: 1 },
          coordenadas: { $first: "$destino.ubicacion" }
        }
      },
      {
        $sort: { viajes: -1 }
      },
      {
        $limit: 10
      }
    ]);

    const datosFormateados = destinosPopulares.map(item => ({
      destino: item._id || "Destino sin especificar",
      viajes: item.viajes,
      coordenadas: item.coordenadas
    }));

    console.log("✅ Destinos populares obtenidos:", datosFormateados);
    handleSuccess(res, 200, "Destinos populares obtenidos", datosFormateados);
  } catch (error) {
    console.error("❌ Error obteniendo destinos populares:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function obtenerEstadisticasPagos(req, res) {
  try {
    console.log("📊 Obteniendo estadísticas de pagos...");

    const pagoRepository = AppDataSource.getRepository(Pago);

    // Estadísticas de pagos por estado
    const pagosPorEstado = await pagoRepository
      .createQueryBuilder("pago")
      .select("pago.estado, COUNT(*) as cantidad")
      .groupBy("pago.estado")
      .getRawMany();

    // Monto total de pagos
    const montoTotal = await pagoRepository
      .createQueryBuilder("pago")
      .select("SUM(pago.montoTotal)", "total")
      .where("pago.estado = :estado", { estado: "aprobado" })
      .getRawOne();

    // Pagos por mes
    const pagosPorMes = await pagoRepository
      .createQueryBuilder("pago")
      .select([
        "EXTRACT(YEAR FROM pago.fechaCreacion) as año",
        "EXTRACT(MONTH FROM pago.fechaCreacion) as mes",
        "COUNT(*) as cantidad",
        "SUM(pago.montoTotal) as monto"
      ])
      .where("pago.fechaCreacion >= :fecha", { 
        fecha: new Date(Date.now() - 6 * 30 * 24 * 60 * 60 * 1000) 
      })
      .groupBy("EXTRACT(YEAR FROM pago.fechaCreacion), EXTRACT(MONTH FROM pago.fechaCreacion)")
      .orderBy("año, mes")
      .getRawMany();

    const estadisticasPagos = {
      pagosPorEstado,
      montoTotal: montoTotal?.total || 0,
      pagosPorMes
    };

    console.log("✅ Estadísticas de pagos obtenidas:", estadisticasPagos);
    handleSuccess(res, 200, "Estadísticas de pagos obtenidas", estadisticasPagos);
  } catch (error) {
    console.error("❌ Error obteniendo estadísticas de pagos:", error);
    handleErrorServer(res, 500, error.message);
  }
}

export async function obtenerAnalisisAvanzado(req, res) {
  try {
    console.log("📊 Obteniendo análisis avanzado...");

    const userRepository = AppDataSource.getRepository(User);
    const vehiculoRepository = AppDataSource.getRepository(Vehiculo);

    // Obtener datos para análisis
    const [
      totalUsuarios,
      totalVehiculos,
      totalViajes,
      viajesCompletados,
      usuariosConClasificacion
    ] = await Promise.all([
      userRepository.count(),
      vehiculoRepository.count(),
      Viaje.countDocuments(),
      Viaje.countDocuments({ estado: 'completado' }),
      userRepository.count({ where: { clasificacion: { $ne: null } } })
    ]);

    // Calcular métricas
    const promedioViajesPorUsuario = totalUsuarios > 0 ? (totalViajes / totalUsuarios).toFixed(1) : 0;
    const tasaCompletacion = totalViajes > 0 ? ((viajesCompletados / totalViajes) * 100).toFixed(1) : 0;
    const vehiculosPorUsuario = totalUsuarios > 0 ? (totalVehiculos / totalUsuarios).toFixed(2) : 0;
    
    // Obtener promedio de clasificación
    const promedioClasificacion = await userRepository
      .createQueryBuilder("user")
      .select("AVG(user.clasificacion)", "promedio")
      .where("user.clasificacion IS NOT NULL")
      .getRawOne();

    const analisis = {
      promedioViajesPorUsuario: parseFloat(promedioViajesPorUsuario),
      tasaCompletacion: parseFloat(tasaCompletacion),
      vehiculosPorUsuario: parseFloat(vehiculosPorUsuario),
      promedioClasificacion: promedioClasificacion?.promedio ? parseFloat(promedioClasificacion.promedio).toFixed(2) : 0,
      usuariosConClasificacion,
      totalUsuarios,
      totalViajes,
      viajesCompletados
    };

    console.log("✅ Análisis avanzado obtenido:", analisis);
    handleSuccess(res, 200, "Análisis avanzado obtenido", analisis);
  } catch (error) {
    console.error("❌ Error obteniendo análisis avanzado:", error);
    handleErrorServer(res, 500, error.message);
  }
}