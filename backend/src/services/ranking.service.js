"use strict";
import { AppDataSource } from "../config/configDb.js";
import user from "../entity/user.entity.js";
import { obtenerPromedioGlobalService } from "./user.service.js";

export async function getRankingService() {
  try {
    const userRepository = AppDataSource.getRepository(user);

    const ranking = await userRepository.find({
      where: {
        rol: "estudiante", // Solo incluir estudiantes, excluir administradores
      },
      order: {
        puntuacion: "DESC",
      },
      take: 10,
    });
    console.log("Ranking obtenido:", ranking);
    if (!ranking || ranking.length === 0) return [null, "No hay usuarios en el ranking"];

    const rankingData = ranking.map(({ password, puntuacion, ...user }) => ({
      ...user,
      puntuacion: puntuacion ?? 0, // Si puntuacion es null, asignar 0
    }));

    return [rankingData, null];
  } catch (error) {
    console.error("Error al obtener el ranking:", error);
    return [null, "Error interno del servidor"];
  }
}

export async function getRankingClasificacionesService() {
  try {
    const userRepository = AppDataSource.getRepository(user);

    // Obtener usuarios estudiantes con clasificación - solo los campos que existen
    const usuarios = await userRepository.find({
      where: {
        rol: "estudiante", // Solo incluir estudiantes, excluir administradores
      },
      select: [
        'rut', 'nombreCompleto', 'email', 'clasificacion'
      ]
    });

    console.log("Usuarios obtenidos para ranking de clasificaciones:", usuarios.length);
    
    if (!usuarios || usuarios.length === 0) {
      return [null, "No hay usuarios en el ranking de clasificaciones"];
    }

    // Usar directamente la clasificación de la BD (ya es bayesiana)
    const usuariosConClasificacion = usuarios.map(usuario => {
      return {
        rut: usuario.rut,
        nombreCompleto: usuario.nombreCompleto,
        email: usuario.email,
        clasificacion: usuario.clasificacion || 0, // Usar directamente el valor de la BD
        clasificacionOriginal: usuario.clasificacion || 0
      };
    });

    // Ordenar por clasificación descendente
    usuariosConClasificacion.sort((a, b) => {
      if (a.clasificacion === 0) return 1;
      if (b.clasificacion === 0) return -1;
      return b.clasificacion - a.clasificacion;
    });

    // Tomar solo los primeros 10
    const ranking = usuariosConClasificacion.slice(0, 10);

    console.log("Ranking de clasificaciones obtenido (valores reales de BD):", ranking.length);
    
    return [ranking, null];
  } catch (error) {
    console.error("Error al obtener el ranking de clasificaciones:", error);
    return [null, "Error interno del servidor"];
  }
}